package client

import (
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	"go-wind-shortplay/pkg/oss"
)

// NewMinIoClient 创建 MinIO 对象存储客户端（视频 / 封面存储）
func NewMinIoClient(ctx *bootstrap.Context) *oss.MinIOClient {
	return oss.NewMinIoClient(ctx.GetConfig())
}
