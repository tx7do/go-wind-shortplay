package server

import (
	"github.com/go-kratos/kratos/v2/middleware"
	"github.com/go-kratos/kratos/v2/middleware/logging"
	"github.com/go-kratos/kratos/v2/transport/grpc"

	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/tx7do/kratos-bootstrap/rpc"

	"go-wind-shortplay/app/core/service/internal/service"

	feedV1 "go-wind-shortplay/api/gen/go/feed/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	notifyV1 "go-wind-shortplay/api/gen/go/notify/service/v1"
	reportV1 "go-wind-shortplay/api/gen/go/report/service/v1"
	statsV1 "go-wind-shortplay/api/gen/go/stats/service/v1"
	sysconfV1 "go-wind-shortplay/api/gen/go/sysconf/service/v1"
	ubaV1 "go-wind-shortplay/api/gen/go/uba/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"

	"go-wind-shortplay/pkg/middleware/auth"
)

// NewGrpcMiddleware gRPC 中间件链（身份透传还原）
func NewGrpcMiddleware(ctx *bootstrap.Context) []middleware.Middleware {
	var ms []middleware.Middleware
	ms = append(ms, logging.Server(ctx.GetLogger()))
	ms = append(ms, auth.NewCoreServerMiddleware())
	return ms
}

// NewGrpcServer 核心服务 gRPC Server（唯一数据落点）
func NewGrpcServer(
	ctx *bootstrap.Context,
	middlewares []middleware.Middleware,

	userService *service.UserService,
	authenticationService *service.AuthenticationService,
	videoService *service.VideoService,
	feedService *service.FeedService,
	interactionService *service.InteractionService,
	commentService *service.CommentService,
	reportService *service.ReportService,
	notificationService *service.NotificationService,
	sysConfService *service.SysConfService,
	ubaService *service.UbaService,
	dashboardService *service.DashboardService,
) (*grpc.Server, error) {
	srv, err := rpc.CreateGrpcServer(ctx.GetConfig(), middlewares...)
	if err != nil {
		return nil, err
	}

	identityV1.RegisterUserServiceServer(srv, userService)
	identityV1.RegisterAuthenticationServiceServer(srv, authenticationService)
	videoV1.RegisterVideoServiceServer(srv, videoService)
	feedV1.RegisterFeedServiceServer(srv, feedService)
	interactionV1.RegisterInteractionServiceServer(srv, interactionService)
	interactionV1.RegisterCommentServiceServer(srv, commentService)
	reportV1.RegisterReportServiceServer(srv, reportService)
	notifyV1.RegisterNotifyServiceServer(srv, notificationService)
	sysconfV1.RegisterSysConfServiceServer(srv, sysConfService)
	ubaV1.RegisterUbaServiceServer(srv, ubaService)
	statsV1.RegisterDashboardServiceServer(srv, dashboardService)

	return srv, nil
}
