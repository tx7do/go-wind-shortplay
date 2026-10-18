package server

import (
	"context"
	"strconv"

	"github.com/go-kratos/kratos/v2/middleware"
	"github.com/go-kratos/kratos/v2/middleware/logging"
	"github.com/go-kratos/kratos/v2/middleware/selector"
	"github.com/go-kratos/kratos/v2/transport/http"

	authzEngine "github.com/tx7do/kratos-authz/engine"
	authz "github.com/tx7do/kratos-authz/middleware"

	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/tx7do/kratos-bootstrap/rpc"

	swaggerUI "github.com/tx7do/kratos-swagger-ui"

	"go-wind-shortplay/app/app/service/cmd/server/assets"
	"go-wind-shortplay/app/app/service/internal/service"

	appV1 "go-wind-shortplay/api/gen/go/app/service/v1"
	auditV1 "go-wind-shortplay/api/gen/go/audit/service/v1"
	authenticationV1 "go-wind-shortplay/api/gen/go/authentication/service/v1"
	mediaV1 "go-wind-shortplay/api/gen/go/media/service/v1"

	"go-wind-shortplay/pkg/middleware/auth"
	entmiddleware "go-wind-shortplay/pkg/middleware/ent"
	applogging "go-wind-shortplay/pkg/middleware/logging"
	"go-wind-shortplay/pkg/oss"
)

// OperationAuthenticationServiceRegister 手工挂载的 C 端注册路由操作名。
// core 的 RegisterUser RPC 已实现,但 app proto 尚未声明该接口,为规避 proto
// 再生成,路由按生成代码的等价方式手工挂载;须与 AddWhiteList 保持一致。
const OperationAuthenticationServiceRegister = "/app.v1.AuthenticationService/Register"

// MediaAsset 域手工挂载端点的操作名（即时图片变换，非 proto 路由）。
const OperationMediaAssetServiceGetContent = "MediaAssetService_GetContent"

// NewRestMiddleware 创建中间件
func NewRestMiddleware(
	ctx *bootstrap.Context,
	accessTokenChecker auth.AccessTokenChecker,
	authorizer authzEngine.Engine,
	tenantResolver entmiddleware.TenantResolver,
) []middleware.Middleware {
	var ms []middleware.Middleware
	ms = append(ms, logging.Server(ctx.GetLogger()))

	// add white list for authentication.
	rpc.AddWhiteList(
		appV1.OperationAuthenticationServiceLogin,

		// AuthenticationService.GetOidcAuthorizeUrl：OIDC 登录的前置步骤（登录页
		// 尚无 token），与 Login 同列免鉴权；state 防 CSRF 由 core 生成校验。
		appV1.OperationAuthenticationServiceGetOidcAuthorizeUrl,

		// AuthenticationService.RefreshToken：access token 过期后凭 refresh_token 换新，
		// 调用时 bearer 往往已过期，若要求有效 token 刷新将永远 401。
		appV1.OperationAuthenticationServiceRefreshToken,

		// C 端注册（手工挂载路由，见 NewRestServer；app proto 暂未声明该接口）。
		OperationAuthenticationServiceRegister,

		// MediaAssetService.Get：公开资源读取，租户隔离由 core viewer 保证。
		appV1.OperationMediaAssetServiceGet,

		// MediaAssetService.GetContent（手工挂载非 proto 路由）：即时图片变换
		// ?w=&h=&q=&fit= 输出图片字节；可见性复用 core Get（租户隔离/软删 404），
		// 图片公开，匿名可访问。
		OperationMediaAssetServiceGetContent,

		// ── shortplay 业务白名单（游客边界：Feed/详情/搜索/主页/评论列表/埋点）──
		appV1.OperationFeedServiceGetFeed,
		appV1.OperationFeedServiceGetVideoDetail,
		appV1.OperationFeedServiceSearchVideos,
		appV1.OperationFeedServiceListVideosByTag,
		appV1.OperationUserServiceGetUser,
		appV1.OperationUserServiceGetUserStats,
		appV1.OperationUserServiceListUserVideos,
		appV1.OperationCommentServiceListComment,
		appV1.OperationCommentServiceListReply,
		appV1.OperationInteractionServiceGetInteractionStatus,
		appV1.OperationVideoServiceListTag,
		appV1.OperationUbaServiceReportEvents,

		// shortplay 旧契约认证面（/auth/*）：登录/注册/刷新在认证前到达
		appV1.OperationAuthenticationServiceAuthLogin,
		appV1.OperationAuthenticationServiceAuthRegister,
		appV1.OperationAuthenticationServiceAuthRefresh,
	)

	ms = append(ms, applogging.Server(
		applogging.WithWriteApiLogFunc(func(ctx context.Context, data *auditV1.ApiAuditLog) error {
			return nil
		}),
		applogging.WithWriteLoginLogFunc(func(ctx context.Context, data *auditV1.LoginAuditLog) error {
			return nil
		}),
	))

	// 鉴权必须在 ent.Server() 之前执行：auth.Server 对非白名单请求注入
	// OperatorMetadata，随后 ent.Server() 才能据此构建带租户作用域的 UserViewer。
	// 若顺序颠倒，ent.Server() 总以 md==nil 兜底为 SystemViewer，导致租户隔离失效。
	ms = append(ms, selector.Server(
		auth.Server(
			auth.WithAccessTokenChecker(accessTokenChecker),
			auth.WithInjectMetadata(true),
			auth.WithInjectEnt(true),
		),
		authz.Server(authorizer),
	).Match(rpc.NewRestWhiteListMatcher()).Build())

	// ent.Server() 必须在 auth.Server 之后：此时非白名单请求已注入 OperatorMetadata，
	// 可构建 UserViewer；白名单请求（公开内容）md==nil，由注入的 TenantResolver 按
	// Host 解析 tenant_id 并注入只读 AnonymousTenantViewer（按 tenant 隔离）；解析失败
	// fail-closed 注入 noopContext（拒绝），不再回退 SystemViewer 避免跨租户泄漏。
	ms = append(ms, entmiddleware.Server(entmiddleware.WithTenantResolver(tenantResolver)))

	return ms
}

// NewRestServer new an REST server.
func NewRestServer(
	ctx *bootstrap.Context,

	middlewares []middleware.Middleware,

	minIOClient *oss.MinIOClient,

	authenticationService *service.AuthenticationService,
	fileTransferService *service.FileTransferService,
	userProfileService *service.UserProfileService,

	mediaAssetService *service.MediaAssetService,
	commentService *service.CommentService,

	spFeedService *service.FeedService,
	spVideoService *service.VideoService,
	spInteractionService *service.InteractionService,
	spReportService *service.ReportService,
	spUbaService *service.UbaService,
	spUserService *service.UserService,
	notificationService *service.NotificationService,

	// register:param ── 新模块服务形参在此行后注册(make register 工具锚点,勿删)
) *http.Server {
	cfg := ctx.GetConfig()

	if cfg == nil || cfg.Server == nil || cfg.Server.Rest == nil {
		return nil
	}

	srv, err := rpc.CreateRestServer(cfg, middlewares...)
	if err != nil {
		panic(err)
	}

	appV1.RegisterAuthenticationServiceHTTPServer(srv, authenticationService)

	// ── 手工挂载:C 端注册 POST /app/v1/register ──
	// 与生成代码等价的注册方式;操作名须与 AddWhiteList 一致。
	{
		registerRoute := srv.Route("/")
		registerRoute.POST("/app/v1/register", func(ctx http.Context) error {
			http.SetOperation(ctx, OperationAuthenticationServiceRegister)
			var in authenticationV1.RegisterUserRequest
			if err := ctx.Bind(&in); err != nil {
				return err
			}
			out, err := authenticationService.Register(ctx, &in)
			if err != nil {
				return err
			}
			return ctx.Result(200, out)
		})
	}

	// ── 手工挂载:媒体域即时图片变换 ──
	// GET /app/v1/media-assets/{id}/content?w=&h=&q=&fit=：非 proto 定义的
	// 二进制端点（输出图片字节流），手工挂载；参数解析/钳位/
	// 派生对象缓存在 mediaAssetService.ServeContent，可见性经其内部调用
	// core Get 校验（租户/软删）。
	{
		mediaContentRoute := srv.Route("/")
		mediaContentRoute.GET("/app/v1/media-assets/{id}/content", func(ctx http.Context) error {
			http.SetOperation(ctx, OperationMediaAssetServiceGetContent)
			id64, err := strconv.ParseUint(ctx.Vars().Get("id"), 10, 32)
			if err != nil || id64 == 0 {
				return mediaV1.ErrorBadRequest("invalid media asset id")
			}
			return mediaAssetService.ServeContent(ctx, ctx.Response(), ctx.Request(), uint32(id64))
		})
	}

	appV1.RegisterFileTransferServiceHTTPServer(srv, fileTransferService)
	appV1.RegisterUserProfileServiceHTTPServer(srv, userProfileService)

	// 图片直传（头像等；二进制 body，手工路由；MinIO 上传，返回 {url}；
	// 不入游客白名单——必须登录，与 admin 端 /admin/v1/uploads/image 同规）
	registerImageUploadHandler(srv, minIOClient)

	appV1.RegisterMediaAssetServiceHTTPServer(srv, mediaAssetService)

	appV1.RegisterCommentServiceHTTPServer(srv, commentService)

	// ── shortplay 业务路由 ──
	appV1.RegisterFeedServiceHTTPServer(srv, spFeedService)
	appV1.RegisterReportServiceHTTPServer(srv, spReportService)
	appV1.RegisterUbaServiceHTTPServer(srv, spUbaService)
	appV1.RegisterUserServiceHTTPServer(srv, spUserService)
	appV1.RegisterInteractionServiceHTTPServer(srv, spInteractionService)

	// 消息通知（基座 internal_message 域收件箱薄转发；需登录，不入游客白名单）
	appV1.RegisterNotificationServiceHTTPServer(srv, notificationService)

	// 视频创作服务：分片字节路由必须先于生成路由注册（kratos mux 同 pattern
	// 先注册者优先；body=application/octet-stream 原始字节，生成层只能按
	// protojson 解 base64，与客户端契约不符）。
	registerSpVideoServiceHandler(srv, spVideoService)
	appV1.RegisterVideoServiceHTTPServer(srv, spVideoService)

	// register:route ── 新模块路由在此行后注册(make register 工具锚点,勿删)

	if cfg.GetServer().GetRest().GetEnableSwagger() {
		swaggerUI.RegisterSwaggerUIServerWithOption(
			srv,
			swaggerUI.WithTitle("GoWind ShortPlay App API"),
			swaggerUI.WithMemoryData(assets.OpenApiData, "yaml"),
		)
	}

	return srv
}
