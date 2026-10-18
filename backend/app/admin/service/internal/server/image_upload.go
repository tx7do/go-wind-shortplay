package server

import (
	"io"
	"strings"

	"github.com/go-kratos/kratos/v2/transport/http"

	"go-wind-shortplay/pkg/oss"
)

// imageUploadMaxSize 业务图片直传上限（2MB，docs/API.md「Admin 端增补」）
const imageUploadMaxSize = 2 * 1024 * 1024

// allowedImageMime 业务图片允许的 Content-Type
var allowedImageMime = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
	"image/gif":  ".gif",
}

// registerImageUploadHandler 业务图片直传：
// POST /admin/v1/uploads/image（body=图片原始字节）→ {"url": "<公网地址>"}。
// 生成层不支持二进制 body，手工挂载；MinIO 直传不落库（业务封面/头像等与文件域解耦）。
func registerImageUploadHandler(srv *http.Server, mc *oss.MinIOClient) {
	srv.Route("/").POST("admin/v1/uploads/image", func(ctx http.Context) error {
		if mc == nil {
			return ctx.JSON(500, map[string]string{"message": "storage unavailable"})
		}
		req := ctx.Request()
		mimeType := strings.ToLower(strings.TrimSpace(req.Header.Get("Content-Type")))
		if i := strings.Index(mimeType, ";"); i > 0 {
			mimeType = strings.TrimSpace(mimeType[:i])
		}
		if _, ok := allowedImageMime[mimeType]; !ok {
			return ctx.JSON(415, map[string]string{"message": "unsupported image type"})
		}

		data, err := io.ReadAll(io.LimitReader(req.Body, imageUploadMaxSize+1))
		if err != nil || len(data) == 0 {
			return ctx.JSON(400, map[string]string{"message": "empty image body"})
		}
		if int64(len(data)) > imageUploadMaxSize {
			return ctx.JSON(413, map[string]string{"message": "image exceeds 2MB limit"})
		}

		_, _, downloadURL, err := mc.UploadFile(ctx, "images", "", mimeType, strings.NewReader(string(data)), int64(len(data)))
		if err != nil {
			return ctx.JSON(500, map[string]string{"message": "upload image failed"})
		}
		return ctx.JSON(200, map[string]string{"url": downloadURL})
	})
}
