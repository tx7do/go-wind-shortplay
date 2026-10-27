package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	appV1 "go-wind-shortplay/api/gen/go/app/service/v1"
	danmakuV1 "go-wind-shortplay/api/gen/go/danmaku/service/v1"
)

// DanmakuService 弹幕（app BFF 薄转发；列表游客白名单，发送需登录，开关与敏感词在 core 把关）。
type DanmakuService struct {
	appV1.DanmakuServiceHTTPServer

	danmakuClient danmakuV1.DanmakuServiceClient
	log           *log.Helper
}

func NewDanmakuService(ctx *bootstrap.Context, danmakuClient danmakuV1.DanmakuServiceClient) *DanmakuService {
	return &DanmakuService{
		log:           ctx.NewLoggerHelper("danmaku/service/app-service"),
		danmakuClient: danmakuClient,
	}
}

func (s *DanmakuService) SendDanmaku(ctx context.Context, req *danmakuV1.SendDanmakuRequest) (*danmakuV1.Danmaku, error) {
	return s.danmakuClient.SendDanmaku(ctx, req)
}

func (s *DanmakuService) ListVideoDanmaku(ctx context.Context, req *danmakuV1.ListVideoDanmakuRequest) (*danmakuV1.ListDanmakuResponse, error) {
	return s.danmakuClient.ListVideoDanmaku(ctx, req)
}
