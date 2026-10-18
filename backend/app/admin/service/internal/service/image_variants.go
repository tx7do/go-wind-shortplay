package service

import (
	"bytes"
	"context"
	"fmt"
	"strings"

	"github.com/disintegration/imaging"
	"github.com/minio/minio-go/v7"

	"go-wind-shortplay/pkg/oss"
)

// 上传后图片变体预生成：Directus/Sanity 同款"预生成变体"模式——
// 不做无上限的动态 resize（CPU 攻击面），按固定规格生成 thumbnail/medium/
// large 三变体落 MinIO，前端按 variant 选择。非图片 MIME 静默跳过。

// imageVariantSpec 图片变体规格（等比缩放到最大宽度）。
type imageVariantSpec struct {
	Name    string
	MaxEdge int // 最大边长（像素）
	Quality int // JPEG 质量
}

var imageVariants = []imageVariantSpec{
	{Name: "thumbnail", MaxEdge: 320, Quality: 75},
	{Name: "medium", MaxEdge: 1024, Quality: 80},
	{Name: "large", MaxEdge: 2560, Quality: 85},
}

// generateImageVariants 从原图生成全部规格变体并上传。
// 返回 变体名→对象名 映射；非图片/解码失败返回 nil（调用方静默跳过，
// 主流程不受影响——原图始终可用）。
func generateImageVariants(ctx context.Context, mc *oss.MinIOClient, bucket, baseObjectName, mimeType string, original []byte) map[string]string {
	if !strings.HasPrefix(mimeType, "image/") || strings.Contains(mimeType, "svg") {
		return nil
	}
	// GIF 动图缩放会丢帧，跳过变体
	if strings.Contains(mimeType, "gif") {
		return nil
	}

	src, err := imaging.Decode(bytes.NewReader(original))
	if err != nil {
		return nil
	}

	// 原图小于最小规格时跳过（缩放只会放大失真）
	b := src.Bounds()
	if b.Dx() < imageVariants[0].MaxEdge && b.Dy() < imageVariants[0].MaxEdge {
		return nil
	}

	// 变体对象名：在原图对象名上加变体后缀（base-thumb.jpg）
	base := baseObjectName
	if dot := strings.LastIndex(base, "."); dot > 0 {
		base = base[:dot]
	}
	ext := "jpg" // 变体统一转 JPEG（有损压缩最通用）
	outMime := "image/jpeg"

	result := make(map[string]string, len(imageVariants))
	for _, spec := range imageVariants {
		variant := imaging.Fit(src, spec.MaxEdge, spec.MaxEdge, imaging.Lanczos)
		var buf bytes.Buffer
		if err := imaging.Encode(&buf, variant, imaging.JPEG, imaging.JPEGQuality(spec.Quality)); err != nil {
			continue
		}
		objectName := fmt.Sprintf("%s-%s.%s", base, spec.Name, ext)
		if _, _, _, err := mc.UploadFile(ctx, bucket, objectName, outMime, bytes.NewReader(buf.Bytes()), int64(buf.Len())); err != nil {
			continue
		}
		result[spec.Name] = objectName
	}
	return result
}

// generateImageVariantsAsync 读回原图→生成变体→上传 MinIO（后台协程入口）。
// media_variants 落库行待 media proto 扩展后补（对象名 = 原图去扩展名 + -变体名.jpg，
// 前端/消费方可按该约定推导变体 URL）；当前只做文件层。
func generateImageVariantsAsync(
	ctx context.Context,
	mc *oss.MinIOClient,
	bucket, storagePath, mimeType string,
) {
	// storagePath 形如 "/bucket/object.png"，剥离前导 /bucket/ 得纯对象名
	trimmed := strings.TrimPrefix(storagePath, "/")
	slash := strings.Index(trimmed, "/")
	if slash <= 0 {
		fmt.Println("[img-variant] bad storagePath:", storagePath)
		return
	}
	objName := trimmed[slash+1:]
	// 读回原图（变体生成需要完整字节）。
	// 经 GetClient() 拿底层 minio.Client（变体属内部运维路径，不走存储对象权限模型）。
	obj, err := mc.GetClient().GetObject(ctx, bucket, objName, minio.GetObjectOptions{})
	if err != nil {
		fmt.Println("[img-variant] get object failed:", err)
		return
	}
	defer func() { _ = obj.Close() }()
	var buf bytes.Buffer
	if _, err := buf.ReadFrom(obj); err != nil {
		fmt.Println("[img-variant] read object failed:", err)
		return
	}

	generateImageVariants(ctx, mc, bucket, objName, mimeType, buf.Bytes())
}
