package main

import (
	"os"

	"github.com/go-kratos/kratos/v2"
	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/client"
	"go-wind-shortplay/app/core/service/internal/server"
	"go-wind-shortplay/app/core/service/internal/service"
	"go-wind-shortplay/pkg/middleware/auth"
)

// initApp 手写装配整个应用，是本服务的依赖注入点（对齐 go-wind-cms 惯例）。
//
// 装配严格单向分层，自上而下的阅读顺序即依赖方向：
//
//	基础设施 → 仓储层(data) → 服务层(service) → 传输层(server)
//
// 约定：
//   - 新增仓储/服务：在对应分层小节追加一行构造，并传给下游消费者；
//     漏接由编译器在调用处报错。
//   - 持有 cleanup 的资源创建成功后立即注册进 cleanups；任何一步失败，
//     rollback 逆序执行已注册的清理。
//   - 本文件只做构造与传参，不写业务逻辑。
func initApp(ctx *bootstrap.Context) (*kratos.App, func(), error) {
	var cleanups []func()
	rollback := func() {
		for i := len(cleanups) - 1; i >= 0; i-- {
			cleanups[i]()
		}
	}

	// ═══════════════════════ 一、基础设施 ═══════════════════════

	redisClient, cleanupRedis, err := client.NewRedisClient(ctx)
	if err != nil {
		return nil, nil, err
	}
	cleanups = append(cleanups, cleanupRedis)

	entClient, cleanupEnt, err := client.NewEntClient(ctx)
	if err != nil {
		rollback()
		return nil, nil, err
	}
	cleanups = append(cleanups, cleanupEnt)

	minIOClient := client.NewMinIoClient(ctx)

	// 认证器：HS256 JWT（core 签发，网关校验，同一 signing key）
	authSigningKey := os.Getenv("JWT_SIGNING_KEY")
	if authSigningKey == "" {
		authSigningKey = "dev_only_change_me_in_prod"
		log.Warn("JWT_SIGNING_KEY not set: using insecure dev key")
	}
	authenticator, err := auth.NewAuthenticator(authSigningKey)
	if err != nil {
		rollback()
		return nil, nil, err
	}

	// ═══════════════════════ 二、仓储层(internal/data) ═══════════════════════

	userRepo := data.NewUserRepo(ctx, entClient)
	if err := userRepo.EnsureSeedAdmin(ctx.Context()); err != nil {
		log.Warnf("seed admin skipped: %s", err.Error())
	}
	videoRepo := data.NewVideoRepo(ctx, entClient)
	interactionRepo := data.NewInteractionRepo(ctx, entClient)
	commentRepo := data.NewCommentRepo(ctx, entClient)
	reportRepo := data.NewReportRepo(ctx, entClient)
	notificationRepo := data.NewNotificationRepo(ctx, entClient)
	sysConfigRepo := data.NewSysConfigRepo(ctx, entClient)
	ubaRepo := data.NewUbaRepo(ctx, entClient)
	statsRepo := data.NewStatsRepo(ctx, entClient)

	// ═══════════════════════ 三、服务层(internal/service) ═══════════════════════

	userService := service.NewUserService(ctx, userRepo, interactionRepo, videoRepo)
	authenticationService := service.NewAuthenticationService(ctx, userRepo, sysConfigRepo, authenticator)
	videoService := service.NewVideoService(ctx, videoRepo, sysConfigRepo, minIOClient)
	feedService := service.NewFeedService(ctx, videoRepo, userRepo, interactionRepo, redisClient)
	interactionService := service.NewInteractionService(ctx, interactionRepo, videoRepo, userRepo, notificationRepo)
	commentService := service.NewCommentService(ctx, commentRepo, userRepo, notificationRepo, videoRepo)
	reportService := service.NewReportService(ctx, reportRepo, userRepo, videoRepo, commentRepo)
	notificationService := service.NewNotificationService(ctx, notificationRepo, userRepo)
	sysConfService := service.NewSysConfService(ctx, sysConfigRepo)
	ubaService := service.NewUbaService(ctx, ubaRepo, feedService, videoRepo)
	dashboardService := service.NewDashboardService(ctx, statsRepo, videoRepo, interactionRepo)

	// ═══════════════════════ 四、传输层(internal/server) ═══════════════════════

	grpcMiddlewares := server.NewGrpcMiddleware(ctx)

	grpcServer, err := server.NewGrpcServer(ctx, grpcMiddlewares,
		userService,
		authenticationService,
		videoService,
		feedService,
		interactionService,
		commentService,
		reportService,
		notificationService,
		sysConfService,
		ubaService,
		dashboardService,
	)
	if err != nil {
		rollback()
		return nil, nil, err
	}

	return newApp(ctx, grpcServer), rollback, nil
}
