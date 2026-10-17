package server

import (
	"github.com/go-kratos/kratos/v2/middleware"
	"github.com/go-kratos/kratos/v2/middleware/logging"
	"github.com/go-kratos/kratos/v2/transport/http"

	authnEngine "github.com/tx7do/kratos-authn/engine"

	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/tx7do/kratos-bootstrap/rpc"

	"go-wind-shortplay/app/admin/service/internal/service"

	adminV1 "go-wind-shortplay/api/gen/go/admin/service/v1"

	"go-wind-shortplay/pkg/middleware/auth"
)

// 鉴权白名单（登录接口免 token）
var adminWhiteList = map[string]struct{}{
	adminV1.OperationAuthenticationServiceLogin: {},
}

// NewRestMiddleware REST 中间件链
func NewRestMiddleware(ctx *bootstrap.Context, authenticator authnEngine.Authenticator) []middleware.Middleware {
	var ms []middleware.Middleware
	ms = append(ms, logging.Server(ctx.GetLogger()))
	ms = append(ms, auth.NewServerMiddleware(authenticator, adminWhiteList))
	// 出站（服务内转发 gRPC 时）标记调用面
	ms = append(ms, auth.NewClientMiddlewareFor("admin"))
	return ms
}

// NewRestServer 后台网关 REST Server
func NewRestServer(
	ctx *bootstrap.Context,
	middlewares []middleware.Middleware,

	authenticationService *service.AuthenticationService,
	userService *service.UserService,
	videoService *service.VideoService,
	commentService *service.CommentService,
	reportService *service.ReportService,
	dashboardService *service.DashboardService,
	sysConfService *service.SysConfService,
) (*http.Server, error) {
	srv, err := rpc.CreateRestServer(ctx.GetConfig(), middlewares...)
	if err != nil {
		return nil, err
	}

	adminV1.RegisterAuthenticationServiceHTTPServer(srv, authenticationService)
	adminV1.RegisterUserServiceHTTPServer(srv, userService)
	adminV1.RegisterVideoServiceHTTPServer(srv, videoService)
	adminV1.RegisterCommentServiceHTTPServer(srv, commentService)
	adminV1.RegisterReportServiceHTTPServer(srv, reportService)
	adminV1.RegisterDashboardServiceHTTPServer(srv, dashboardService)
	adminV1.RegisterSysConfServiceHTTPServer(srv, sysConfService)

	return srv, nil
}
