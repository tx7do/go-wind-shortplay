package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	appV1 "go-wind-shortplay/api/gen/go/app/service/v1"
	sysconfV1 "go-wind-shortplay/api/gen/go/sysconf/service/v1"
)

// SysConfService 系统配置（app BFF 薄转发；App 启动拉运营开关与公告，游客白名单）。
type SysConfService struct {
	appV1.SysConfServiceHTTPServer

	sysConfClient sysconfV1.SysConfServiceClient
	log           *log.Helper
}

func NewSysConfService(ctx *bootstrap.Context, sysConfClient sysconfV1.SysConfServiceClient) *SysConfService {
	return &SysConfService{
		log:           ctx.NewLoggerHelper("sysconf/service/app-service"),
		sysConfClient: sysConfClient,
	}
}

func (s *SysConfService) GetSysConf(ctx context.Context, req *emptypb.Empty) (*sysconfV1.SysConf, error) {
	return s.sysConfClient.GetSysConf(ctx, req)
}
