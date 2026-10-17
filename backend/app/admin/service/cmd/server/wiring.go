package main

import (
	"os"

	"github.com/go-kratos/kratos/v2"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	"go-wind-shortplay/app/admin/service/internal/data"
	"go-wind-shortplay/app/admin/service/internal/server"
	"go-wind-shortplay/app/admin/service/internal/service"
	"go-wind-shortplay/pkg/middleware/auth"
)

// initApp 手写装配后台网关（瘦 BFF：参数校验 + gRPC 转发到 core，不碰数据库）
func initApp(ctx *bootstrap.Context) (*kratos.App, func(), error) {
	var cleanups []func()
	rollback := func() {
		for i := len(cleanups) - 1; i >= 0; i-- {
			cleanups[i]()
		}
	}

	// ═══════════════════════ 一、基础设施 ═══════════════════════

	authSigningKey := os.Getenv("JWT_SIGNING_KEY")
	if authSigningKey == "" {
		authSigningKey = "dev_only_change_me_in_prod"
	}
	authenticator, err := auth.NewAuthenticator(authSigningKey)
	if err != nil {
		return nil, nil, err
	}

	coreConn, cleanupConn, err := data.NewCoreConn(ctx)
	if err != nil {
		return nil, nil, err
	}
	cleanups = append(cleanups, cleanupConn)

	// ═══════════════════════ 二、gRPC 客户端 ═══════════════════════

	authenticationServiceClient := data.NewAuthenticationServiceClient(coreConn)
	userServiceClient := data.NewUserServiceClient(coreConn)
	videoServiceClient := data.NewVideoServiceClient(coreConn)
	commentServiceClient := data.NewCommentServiceClient(coreConn)
	reportServiceClient := data.NewReportServiceClient(coreConn)
	dashboardServiceClient := data.NewDashboardServiceClient(coreConn)
	sysConfServiceClient := data.NewSysConfServiceClient(coreConn)

	// ═══════════════════════ 三、服务层(internal/service) ═══════════════════════

	authenticationService := service.NewAuthenticationService(ctx, authenticationServiceClient)
	userService := service.NewUserService(ctx, userServiceClient)
	videoService := service.NewVideoService(ctx, videoServiceClient)
	commentService := service.NewCommentService(ctx, commentServiceClient)
	reportService := service.NewReportService(ctx, reportServiceClient)
	dashboardService := service.NewDashboardService(ctx, dashboardServiceClient)
	sysConfService := service.NewSysConfService(ctx, sysConfServiceClient)

	// ═══════════════════════ 四、传输层(internal/server) ═══════════════════════

	restMiddlewares := server.NewRestMiddleware(ctx, authenticator)

	httpServer, err := server.NewRestServer(ctx, restMiddlewares,
		authenticationService,
		userService,
		videoService,
		commentService,
		reportService,
		dashboardService,
		sysConfService,
	)
	if err != nil {
		rollback()
		return nil, nil, err
	}

	return newApp(ctx, httpServer), rollback, nil
}
