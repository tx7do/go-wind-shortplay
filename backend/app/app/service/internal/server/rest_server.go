package server

import (
	"github.com/go-kratos/kratos/v2/middleware"
	"github.com/go-kratos/kratos/v2/middleware/logging"
	"github.com/go-kratos/kratos/v2/transport/http"

	authnEngine "github.com/tx7do/kratos-authn/engine"

	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/tx7do/kratos-bootstrap/rpc"

	"go-wind-shortplay/app/app/service/internal/service"

	appV1 "go-wind-shortplay/api/gen/go/app/service/v1"
	feedV1 "go-wind-shortplay/api/gen/go/feed/service/v1"

	"go-wind-shortplay/pkg/middleware/auth"
)

// 鉴权白名单：游客可访问（浏览闭环：Feed / 详情 / 搜索 / 主页 / 评论列表）
var appWhiteList = map[string]struct{}{
	appV1.OperationAuthenticationServiceLogin:        {},
	appV1.OperationAuthenticationServiceRegister:     {},
	appV1.OperationAuthenticationServiceRefreshToken: {},
	appV1.OperationFeedServiceGetFeed:                {},
	appV1.OperationFeedServiceGetVideoDetail:         {},
	appV1.OperationFeedServiceSearchVideos:           {},
	appV1.OperationFeedServiceListVideosByTag:        {},
	appV1.OperationUserServiceGetUser:                {},
	appV1.OperationUserServiceGetUserStats:           {},
	appV1.OperationUserServiceListUserVideos:         {},
	appV1.OperationCommentServiceListComment:         {},
	appV1.OperationCommentServiceListReply:           {},
	appV1.OperationInteractionServiceGetInteractionStatus: {},
	appV1.OperationUbaServiceReportEvents:           {},
}

// NewRestMiddleware REST 中间件链
func NewRestMiddleware(ctx *bootstrap.Context, authenticator authnEngine.Authenticator) []middleware.Middleware {
	var ms []middleware.Middleware
	ms = append(ms, logging.Server(ctx.GetLogger()))
	ms = append(ms, auth.NewServerMiddleware(authenticator, appWhiteList))
	ms = append(ms, auth.NewClientMiddlewareFor("app"))
	return ms
}

// NewRestServer 前台网关 REST Server
func NewRestServer(
	ctx *bootstrap.Context,
	middlewares []middleware.Middleware,

	authenticationService *service.AuthenticationService,
	userService *service.UserService,
	feedService *service.FeedService,
	videoService *service.VideoService,
	interactionService *service.InteractionService,
	commentService *service.CommentService,
	notifyService *service.NotifyService,
	reportService *service.ReportService,
	ubaService *service.UbaService,
	feedClient feedV1.FeedServiceClient,
) (*http.Server, error) {
	srv, err := rpc.CreateRestServer(ctx.GetConfig(), middlewares...)
	if err != nil {
		return nil, err
	}

	appV1.RegisterAuthenticationServiceHTTPServer(srv, authenticationService)
	appV1.RegisterUserServiceHTTPServer(srv, userService)
	appV1.RegisterFeedServiceHTTPServer(srv, feedService)
	appV1.RegisterVideoServiceHTTPServer(srv, videoService)
	appV1.RegisterInteractionServiceHTTPServer(srv, interactionService)
	appV1.RegisterCommentServiceHTTPServer(srv, commentService)
	appV1.RegisterNotifyServiceHTTPServer(srv, notifyService)
	appV1.RegisterReportServiceHTTPServer(srv, reportService)
	appV1.RegisterUbaServiceHTTPServer(srv, ubaService)

	// 分享 H5 预览页（/s/{video_id}）
	RegisterSharePage(srv, feedClient)

	return srv, nil
}
