package oss

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/minio/minio-go/v7"

	storageV1 "go-wind-shortplay/api/gen/go/storage/service/v1"
)

// defaultBucketName 统一媒体桶缺省名：与双端前端 MEDIA_BASE（<host>/<bucket>）
// 的拼址约定对齐——后端返回的对象键（如 sp/xxx.mp4、images/xxx.jpg）一律
// 相对该桶根解析。
const defaultBucketName = "shortplay"

// DefaultBucketName 统一媒体桶名（可经环境变量 OSS_BUCKET 覆盖，缺省 shortplay）。
// 双端上传的视频/封面/图片全部落在同一桶，不再按 Content-Type 分桶。
func DefaultBucketName() string {
	if b := strings.TrimSpace(os.Getenv("OSS_BUCKET")); b != "" {
		return b
	}
	return defaultBucketName
}

// publicReadPolicy 匿名只读桶策略：任何人可 GET 对象（公网播放/封面直取），
// 不可列举、不可写。
func publicReadPolicy(bucket string) string {
	return fmt.Sprintf(`{
 "Version": "2012-10-17",
 "Statement": [
  {
   "Effect": "Allow",
   "Principal": {"AWS": ["*"]},
   "Action": ["s3:GetObject"],
   "Resource": ["arn:aws:s3:::%s/*"]
  }
 ]
}`, bucket)
}

// EnsurePublicBucketExists 确保统一桶存在且带匿名只读策略（幂等，可反复调用）：
// 桶缺失则懒建；策略每次重设——幂等且自愈（桶被外部预建而无策略、或策略被
// 误删的场景下，下一个对象上传前即恢复公网可读）。
func (c *MinIOClient) EnsurePublicBucketExists(ctx context.Context, bucketName string) error {
	exists, err := c.mc.BucketExists(ctx, bucketName)
	if err != nil {
		c.log.Errorf("Failed to check bucket existence: %v", err)
		return storageV1.ErrorInternalServerError("failed to check bucket existence: %s", bucketName)
	}

	if !exists {
		if err = c.mc.MakeBucket(ctx, bucketName, minio.MakeBucketOptions{}); err != nil {
			c.log.Errorf("Failed to create bucket: %v", err)
			return storageV1.ErrorInternalServerError("failed to create bucket: %s", bucketName)
		}
		c.log.Infof("Created bucket: %s", bucketName)
	}

	if err = c.mc.SetBucketPolicy(ctx, bucketName, publicReadPolicy(bucketName)); err != nil {
		c.log.Errorf("Failed to set public read policy: %v", err)
		return storageV1.ErrorInternalServerError("failed to set public read policy: %s", bucketName)
	}

	return nil
}

// PutObject 上传对象到统一媒体桶（DefaultBucketName），懒建桶并确保匿名只读策略。
// 返回（存储路径「桶/键」, 公网下载地址, 错误）。
// 与 UploadFile 的区别：不做按 Content-Type 分桶，桶恒为统一桶，对象键完全由
// 调用方指定（保留 images/ 、sp/ 等业务前缀语义）。
func (c *MinIOClient) PutObject(
	ctx context.Context,
	objectName string,
	mimeType string,
	reader io.Reader, objectSize int64,
) (string, string, error) {
	if objectName == "" {
		return "", "", storageV1.ErrorBadRequest("object name is required")
	}
	if objectSize <= 0 {
		c.log.Errorf("empty fileContent data")
		return "", "", storageV1.ErrorUploadFailed("empty fileContent data")
	}

	// 大小硬限制：与 UploadFile 同规（minio-go 按 objectSize 读取，声明值即硬顶）。
	if objectSize > MaxUploadObjectSize {
		c.log.Errorf("upload object too large: %d bytes (max %d)", objectSize, MaxUploadObjectSize)
		return "", "", storageV1.ErrorUploadFailed("upload object exceeds max size limit")
	}

	bucketName := DefaultBucketName()
	if err := c.EnsurePublicBucketExists(ctx, bucketName); err != nil {
		return "", "", err
	}

	if mimeType == "" {
		mimeType = DefaultContentType
	}

	// 以流式 reader 喂给 PutObject，minio-go 内部按 size 自动分片（multipart）。
	if _, err := c.mc.PutObject(
		ctx,
		bucketName, objectName,
		reader, objectSize,
		minio.PutObjectOptions{
			ContentType: mimeType,
		},
	); err != nil {
		c.log.Errorf("failed to upload object: %v", err)
		return "", "", storageV1.ErrorUploadFailed("failed to upload object")
	}

	downloadUrl := JoinObjectUrl(c.conf.Minio.DownloadHost, bucketName, objectName)
	storagePath := JoinObjectUrl("", bucketName, objectName)

	return storagePath, downloadUrl, nil
}
