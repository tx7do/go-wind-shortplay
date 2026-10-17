// Package oss 对象存储访问封装（MinIO）。
//
// 薄封装 kratos-bootstrap/oss/minio：统一 bucket、对象键规约与公网 URL 拼装，
// 业务侧只面对「对象键 ↔ 可访问 URL」。
// bucket 与对外访问端点经环境变量注入：
//
//	OSS_BUCKET           工作桶名（缺省 shortplay）
//	OSS_PUBLIC_ENDPOINT  面向客户端的访问端点（如 http://127.0.0.1:9000），缺省直接返回对象键
package oss

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"

	minioStorage "github.com/tx7do/kratos-bootstrap/oss/minio"
	minioGo "github.com/minio/minio-go/v7"

	conf "github.com/tx7do/kratos-bootstrap/api/gen/go/conf/v1"
)

type MinIOClient struct {
	st             *minioStorage.Storage
	bucket         string
	publicEndpoint string
}

func NewMinIoClient(cfg *conf.Bootstrap) *MinIOClient {
	if cfg == nil || cfg.Oss == nil {
		return nil
	}
	bucket := os.Getenv("OSS_BUCKET")
	if bucket == "" {
		bucket = "shortplay"
	}
	return &MinIOClient{
		st:             minioStorage.NewStorage(cfg.Oss),
		bucket:         bucket,
		publicEndpoint: strings.TrimRight(os.Getenv("OSS_PUBLIC_ENDPOINT"), "/"),
	}
}

// SDK 暴露底层 minio.Client（特殊操作逃生口）
func (c *MinIOClient) SDK() *minioGo.Client {
	if c == nil || c.st == nil {
		return nil
	}
	return c.st.SDK()
}

// PutObject 上传对象，返回可访问 URL
func (c *MinIOClient) PutObject(ctx context.Context, key string, body io.Reader, contentType string) (string, error) {
	if c == nil || c.st == nil {
		return "", fmt.Errorf("minio client not initialized")
	}
	if _, err := c.st.PutObject(ctx, c.bucket, key, body, contentType); err != nil {
		return "", err
	}
	return c.PublicURL(key), nil
}

// PublicURL 拼装对象访问 URL
func (c *MinIOClient) PublicURL(key string) string {
	if c.publicEndpoint != "" {
		return fmt.Sprintf("%s/%s/%s", c.publicEndpoint, c.bucket, key)
	}
	return key
}

// Bucket 返回工作桶名
func (c *MinIOClient) Bucket() string {
	if c == nil {
		return ""
	}
	return c.bucket
}
