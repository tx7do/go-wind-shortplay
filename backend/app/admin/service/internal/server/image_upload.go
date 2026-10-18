package server

import (
	"bytes"
	"context"
	"io"
	"strings"

	"github.com/go-kratos/kratos/v2/transport/http"

	"go-wind-shortplay/pkg/oss"
)

// OperationUploadServiceUploadImage 手工挂载的图片直传路由操作名（非 proto 路由）。
// 不入鉴权白名单——业务图片上传必须登录（Bearer）。
const OperationUploadServiceUploadImage = "UploadService_UploadImage"

// imageUploadMaxSize 业务图片直传上限（2MB，docs/API.md「Admin 端增补」）
const imageUploadMaxSize = 2 * 1024 * 1024

// allowedImageMime 业务图片允许的 Content-Type
var allowedImageMime = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
	"image/gif":  ".gif",
}

// registerImageUploadHandler 业务图片直传（Admin 端，与 app 端同构）：
// POST /admin/v1/uploads/image（body=图片原始字节，Content-Type=图片 MIME）→ {"url": "<公网地址>"}。
// 生成层不支持二进制 body，手工挂载；MinIO 直传不落库（业务封面/头像等与文件域解耦）。
//
// 注意：kratos 手工挂载路由默认绕过全部 server 中间件（仅生成代码会经
// ctx.Middleware 包装），必须显式经 ctx.Middleware 空跑一次中间件链才能吃到
// Bearer 鉴权（操作名不在白名单 → 无令牌 401），与生成路由行为对齐。
// 又因审计日志中间件在 inner handler 返回后会读走 body 且不回填，原始字节
// 必须在过中间件链之前读完。
func registerImageUploadHandler(srv *http.Server, mc *oss.MinIOClient) {
	srv.Route("/").POST("admin/v1/uploads/image", func(ctx http.Context) error {
		http.SetOperation(ctx, OperationUploadServiceUploadImage)

		req := ctx.Request()

		// 先读完原始字节（LimitReader 多留 1 字节用于超限判定）
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

		// 鉴权门：空跑中间件链（logging/auth/ent），无令牌或令牌无效在此 401。
		gate := ctx.Middleware(func(ctx context.Context, req interface{}) (interface{}, error) {
			return nil, nil
		})
		if _, err := gate(ctx, nil); err != nil {
			return err
		}

		if mc == nil {
			return ctx.JSON(500, map[string]string{"message": "storage unavailable"})
		}
		// 统一媒体桶（OSS_BUCKET，缺省 shortplay，懒建+匿名只读），
		// 对象键保留 images/ 前缀——与前端 MEDIA_BASE（<host>/<桶>）拼址对齐。
		objectKey := oss.GenerateObjectName("images", allowedImageMime[mimeType], oss.GenerateFileNameTypeUUID)
		_, downloadURL, err := mc.PutObject(ctx, objectKey, mimeType, bytes.NewReader(data), int64(len(data)))
		if err != nil {
			return ctx.JSON(500, map[string]string{"message": "upload image failed"})
		}
		return ctx.JSON(200, map[string]string{"url": downloadURL})
	})
}
