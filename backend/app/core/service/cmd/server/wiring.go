package main

import (
	"os"

	"github.com/go-kratos/kratos/v2"
	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	pkgcrypto "go-wind-shortplay/pkg/crypto"

	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/channel"
	"go-wind-shortplay/app/core/service/internal/data/client"
	"go-wind-shortplay/app/core/service/internal/server"
	"go-wind-shortplay/app/core/service/internal/service"
)

// initApp 手写装配整个应用,是本服务的依赖注入点(替代原 google/wire 生成)。
// initApp assembles the whole application by hand — the dependency injection point.
//
// 装配严格单向分层,自上而下的阅读顺序即依赖方向:
// The wiring is strictly layered; reading top-down follows the dependency direction:
//
//	基础设施 → 仓储层(data) → 服务层(service) → 传输层(server)
//
// 约定 / Conventions:
//   - 新增仓储/服务:在对应分层小节追加一行构造,并传给下游消费者;漏接由编译器在调用处报错。
//     To add a repo/service: append one constructor line in its layer section, then pass it to
//     downstream consumers; a missing connection is a compile error at the call site.
//   - 持有 cleanup 的资源创建成功后立即注册进 cleanups;任何一步失败,rollback 逆序执行已注册
//     的清理(shutdown 与中途失败共用同一条 LIFO 路径)。
//     Resources owning a cleanup register it immediately; rollback runs them LIFO both on
//     mid-way failure and on shutdown.
//   - 本文件只做构造与传参,不写业务逻辑。
//     Construction and parameter passing only; no business logic in this file.
func initApp(ctx *bootstrap.Context) (*kratos.App, func(), error) {
	// cleanup 注册表:rollback 时逆序执行。
	// Cleanup registry; rollback runs entries in reverse order.
	var cleanups []func()
	rollback := func() {
		for i := len(cleanups) - 1; i >= 0; i-- {
			cleanups[i]()
		}
	}

	// ═══════════════════════ 一、基础设施 ═══════════════════════

	// 全局存储加密器(AES-256-GCM, pkg/crypto):凭据类字段落库加密的总开关。
	// key 从 ENCRYPTION_KEY 环境变量读取;未配置时降级明文并告警(生产必须配置)。
	if encKey := os.Getenv("ENCRYPTION_KEY"); encKey != "" {
		if err := pkgcrypto.InitGlobalEncryptor(encKey, true); err != nil {
			return nil, nil, err
		}
	} else {
		log.Warnf("ENCRYPTION_KEY not set: credential encryption DISABLED (secrets stored in plaintext)")
	}

	// 认证基建:令牌缓存 → 认证器
	authenticatorOption := data.NewAuthenticatorConfig(ctx)

	redisClient, cleanupRedis, err := client.NewRedisClient(ctx)
	if err != nil {
		return nil, nil, err
	}
	cleanups = append(cleanups, cleanupRedis)

	userTokenCache := data.NewUserTokenCache(ctx, redisClient)
	authenticator := data.NewAuthenticator(ctx, authenticatorOption, userTokenCache)

	entClient, cleanupEnt, err := client.NewEntClient(ctx)
	if err != nil {
		rollback()
		return nil, nil, err
	}
	cleanups = append(cleanups, cleanupEnt)

	crypto := data.NewPasswordCrypto()
	minIOClient := client.NewMinIoClient(ctx)

	// ═══════════════════════ 二、仓储层(internal/data) ═══════════════════════

	// 身份与账号
	userCredentialRepo := data.NewUserCredentialRepo(ctx, entClient, crypto)
	loginPolicyRepo := data.NewLoginPolicyRepo(ctx, entClient)
	userRoleRepo := data.NewUserRoleRepo(ctx, entClient)
	userOrgUnitRepo := data.NewUserOrgUnitRepo(ctx, entClient)
	userPositionRepo := data.NewUserPositionRepo(ctx, entClient)
	membershipRoleRepo := data.NewMembershipRoleRepo(ctx, entClient)
	membershipPositionRepo := data.NewMembershipPositionRepo(ctx, entClient)
	membershipOrgUnitRepo := data.NewMembershipOrgUnitRepo(ctx, entClient)
	membershipRepo := data.NewMembershipRepo(ctx, entClient, membershipRoleRepo, membershipPositionRepo, membershipOrgUnitRepo)
	userRepo := data.NewUserRepo(ctx, entClient, userRoleRepo, userOrgUnitRepo, userPositionRepo, membershipRepo)

	// 租户
	tenantRepo := data.NewTenantRepo(ctx, entClient)

	// RBAC:权限(聚合 Api/Menu 挂载点) → 角色(聚合权限)
	rolePermissionRepo := data.NewRolePermissionRepo(ctx, entClient)
	permissionApiRepo := data.NewPermissionApiRepo(ctx, entClient)
	permissionMenuRepo := data.NewPermissionMenuRepo(ctx, entClient)
	permissionRepo := data.NewPermissionRepo(ctx, entClient, permissionApiRepo, permissionMenuRepo, rolePermissionRepo)
	roleMetadataRepo := data.NewRoleMetadataRepo(ctx, entClient)
	roleRepo := data.NewRoleRepo(ctx, entClient, rolePermissionRepo, permissionRepo, roleMetadataRepo, userRoleRepo)

	// RBAC 挂载点:菜单 / Api / 权限组
	menuRepo := data.NewMenuRepo(ctx, entClient)
	apiRepo := data.NewApiRepo(ctx, entClient)
	permissionGroupRepo := data.NewPermissionGroupRepo(ctx, entClient)

	// 组织架构
	positionRepo := data.NewPositionRepo(ctx, entClient)
	orgUnitRepo := data.NewOrgUnitRepo(ctx, entClient)

	// 审计日志
	permissionAuditLogRepo := data.NewPermissionAuditLogRepo(ctx, entClient)
	policyEvaluationLogRepo := data.NewPolicyEvaluationLogRepo(ctx, entClient)
	loginAuditLogRepo := data.NewLoginAuditLogRepo(ctx, entClient)
	apiAuditLogRepo := data.NewApiAuditLogRepo(ctx, entClient)
	operationAuditLogRepo := data.NewOperationAuditLogRepo(ctx, entClient)
	dataAccessAuditLogRepo := data.NewDataAccessAuditLogRepo(ctx, entClient)

	// 站内信
	internalMessageRecipientRepo := data.NewInternalMessageRecipientRepo(ctx, entClient)
	internalMessageRepo := data.NewInternalMessageRepo(ctx, entClient, internalMessageRecipientRepo)
	internalMessageCategoryRepo := data.NewInternalMessageCategoryRepo(ctx, entClient)

	// 任务 / 文件
	taskRepo := data.NewTaskRepo(ctx, entClient)
	fileRepo := data.NewFileRepo(ctx, entClient)

	// 字典与多语言
	dictEntryI18nRepo := data.NewDictEntryI18nRepo(ctx, entClient)
	dictEntryRepo := data.NewDictEntryRepo(ctx, entClient, dictEntryI18nRepo)
	dictTypeRepo := data.NewDictTypeRepo(ctx, entClient, dictEntryRepo)
	languageRepo := data.NewLanguageRepo(ctx, entClient)

	// 评论
	commentRepo := data.NewCommentRepo(ctx, entClient)

	// shortplay 业务域：视频 / 剧集 / 上传 / 草稿 / 互动 / 评论 / 举报 / 埋点 / 配置 / 看板
	videoRepo := data.NewVideoRepo(ctx, entClient)
	seriesRepo := data.NewSeriesRepo(ctx, entClient)
	videoDraftRepo := data.NewVideoDraftRepo(ctx, entClient)
	uploadTaskRepo := data.NewUploadTaskRepo(ctx, entClient)
	interactionRepo := data.NewInteractionRepo(ctx, entClient)
	videoCommentRepo := data.NewVideoCommentRepo(ctx, entClient)
	reportRepo := data.NewReportRepo(ctx, entClient)
	ubaRepo := data.NewUbaRepo(ctx, entClient)
	sysConfRepo := data.NewSysConfRepo(ctx, entClient)
	statsRepo := data.NewStatsRepo(ctx, entClient)

	// 媒体
	mediaVariantRepo := data.NewMediaVariantRepo(ctx, entClient)
	mediaAssetRepo := data.NewMediaAssetRepo(ctx, entClient, mediaVariantRepo)

	// 通知域：渠道花名册 / 投递台账 / 路由规则 / 模板 / 用户偏好（全部平台级，无租户列）
	notificationChannelRepo := data.NewNotificationChannelRepo(ctx, entClient)
	notificationDeliveryRepo := data.NewNotificationDeliveryRepo(ctx, entClient)
	notificationRuleRepo := data.NewNotificationRuleRepo(ctx, entClient)
	notificationTemplateRepo := data.NewNotificationTemplateRepo(ctx, entClient)
	notificationPreferenceRepo := data.NewNotificationPreferenceRepo(ctx, entClient)

	// ── register:repo ── 新模块仓储在此行后注册(make register 工具锚点,勿删)

	// ═══════════════════════ 三、服务层(internal/service) ═══════════════════════

	// 认证与登录策略
	authenticationService := service.NewAuthenticationService(ctx, authenticator, userCredentialRepo, userRepo, roleRepo, tenantRepo, permissionRepo, redisClient)
	loginPolicyService := service.NewLoginPolicyService(ctx, loginPolicyRepo)
	userCredentialService := service.NewUserCredentialService(ctx, userCredentialRepo)

	// 任务 / 文件
	taskService := service.NewTaskService(ctx, taskRepo, userRepo)

	fileService := service.NewFileService(ctx, fileRepo, minIOClient)

	// 字典与多语言
	dictTypeService := service.NewDictTypeService(ctx, dictTypeRepo)
	dictEntryService := service.NewDictEntryService(ctx, dictEntryRepo)
	languageService := service.NewLanguageService(ctx, languageRepo)

	// 租户与身份
	tenantService := service.NewTenantService(ctx, tenantRepo, userRepo, userCredentialRepo, roleRepo)
	userService := service.NewUserService(ctx, userRepo, roleRepo, userCredentialRepo, positionRepo, orgUnitRepo, tenantRepo, membershipRepo)
	roleService := service.NewRoleService(ctx, roleRepo, tenantRepo, userRoleRepo, userRepo, permissionRepo)
	positionService := service.NewPositionService(ctx, positionRepo, orgUnitRepo)
	orgUnitService := service.NewOrgUnitService(ctx, orgUnitRepo, userRepo)

	// RBAC
	menuService := service.NewMenuService(ctx, menuRepo)
	apiService := service.NewApiService(ctx, apiRepo)
	permissionService := service.NewPermissionService(ctx, permissionRepo, permissionGroupRepo, menuRepo, apiRepo, roleRepo)
	permissionGroupService := service.NewPermissionGroupService(ctx, permissionGroupRepo, permissionRepo)

	// 审计日志
	permissionAuditLogService := service.NewPermissionAuditLogService(ctx, permissionAuditLogRepo)
	policyEvaluationLogService := service.NewPolicyEvaluationLogService(ctx, policyEvaluationLogRepo)
	loginAuditLogService := service.NewLoginAuditLogService(ctx, loginAuditLogRepo)
	apiAuditLogService := service.NewApiAuditLogService(ctx, apiAuditLogRepo, apiRepo)
	operationAuditLogService := service.NewOperationAuditLogService(ctx, operationAuditLogRepo)
	dataAccessAuditLogService := service.NewDataAccessAuditLogService(ctx, dataAccessAuditLogRepo)

	// 站内信
	internalMessageService := service.NewInternalMessageService(ctx, internalMessageRepo, internalMessageCategoryRepo, internalMessageRecipientRepo, userRepo, redisClient, taskService)
	internalMessageCategoryService := service.NewInternalMessageCategoryService(ctx, internalMessageCategoryRepo)
	internalMessageRecipientService := service.NewInternalMessageRecipientService(ctx, internalMessageRepo, internalMessageRecipientRepo)

	// 通知域（投递台账 + 渠道花名册 + 路由规则 + 模板 + 用户偏好）
	// 注册表先注册自包含的渠道 sender；INTERNAL 渠道的 sender 依赖两个 service 互相就绪，
	// 在下方"双向引用缝"处补注册（构造期互相传会成环）。
	channelRegistry := channel.NewRegistry()
	channelRegistry.Register(channel.NewEmailSender(notificationChannelRepo))
	channelRegistry.Register(channel.NewWebhookSender(notificationChannelRepo))
	notificationService := service.NewNotificationService(ctx, notificationDeliveryRepo, notificationRuleRepo, notificationTemplateRepo, channelRegistry)
	notificationChannelService := service.NewNotificationChannelService(ctx, notificationChannelRepo, notificationService)
	notificationRuleService := service.NewNotificationRuleService(ctx, notificationRuleRepo, notificationChannelRepo, notificationService)
	notificationTemplateService := service.NewNotificationTemplateService(ctx, notificationTemplateRepo)
	notificationPreferenceService := service.NewNotificationPreferenceService(ctx, notificationPreferenceRepo, internalMessageCategoryRepo)

	// 双向引用缝：站内信的系统通知经投递缝（SendDirect）走渠道路由，
	// INTERNAL 渠道的实现又反向持有站内信 service——两个 service 构造完之后再互相注册。
	channelRegistry.Register(service.NewInternalMessageSender(internalMessageService, notificationPreferenceRepo, ctx.NewLoggerHelper("internal-message-sender/channel")))
	internalMessageService.RegisterNotifier(notificationService)

	// 评论与媒体
	commentService := service.NewCommentService(ctx, commentRepo)
	mediaAssetService := service.NewMediaAssetService(ctx, mediaAssetRepo)

	// shortplay 业务域服务
	seriesService := service.NewSeriesService(ctx, seriesRepo, videoRepo)
	videoService := service.NewVideoService(ctx, videoRepo, seriesService, videoDraftRepo, uploadTaskRepo, sysConfRepo, minIOClient)
	feedService := service.NewFeedService(ctx, videoRepo, userRepo, interactionRepo, statsRepo, redisClient)
	interactionService := service.NewInteractionService(ctx, interactionRepo, videoRepo, userRepo)
	videoCommentService := service.NewVideoCommentService(ctx, videoCommentRepo, videoRepo, userRepo, sysConfRepo)
	reportService := service.NewReportService(ctx, reportRepo, userRepo, videoRepo, videoCommentRepo)
	sysConfService := service.NewSysConfService(ctx, sysConfRepo)
	ubaService := service.NewUbaService(ctx, ubaRepo, videoRepo)
	dashboardService := service.NewDashboardService(ctx, statsRepo, videoRepo, interactionRepo, userRepo)

	// shortplay 接缝：举报通知走基座站内信（超管收件）；封面抽帧走 asynq。
	reportService.RegisterNotifier(internalMessageService)
	// C 端互动通知：点赞/关注（interaction）、评论/回复（comment）、审核结果（video）
	interactionService.RegisterNotifier(internalMessageService)
	videoCommentService.RegisterNotifier(internalMessageService)
	videoService.RegisterNotifier(internalMessageService)
	reportService.RegisterSuperAdminResolver(roleService)
	reportService.RegisterVideoModerator(videoService)
	videoService.RegisterTaskEnqueuer(taskService)

	// ── register:service ── 新模块服务在此行后注册(make register 工具锚点,勿删)

	// ═══════════════════════ 四、传输层(internal/server) ═══════════════════════

	grpcMiddlewares := server.NewGrpcMiddleware(ctx)

	grpcServer, err := server.NewGrpcServer(ctx, grpcMiddlewares,
		authenticationService, loginPolicyService, userCredentialService,
		taskService,
		fileService,
		dictTypeService, dictEntryService, languageService,
		tenantService, userService, roleService, positionService, orgUnitService,
		menuService, apiService, permissionService, permissionGroupService, permissionAuditLogService, policyEvaluationLogService,
		loginAuditLogService, apiAuditLogService, operationAuditLogService, dataAccessAuditLogService,
		internalMessageService, internalMessageCategoryService, internalMessageRecipientService,
		commentService,
		mediaAssetService,
		notificationService,
		notificationChannelService,
		notificationRuleService,
		notificationTemplateService,
		notificationPreferenceService,
		videoService, seriesService, feedService, interactionService, videoCommentService,
		reportService, sysConfService, ubaService, dashboardService,
		// register:grpc-arg ── 新模块服务实参在此行后追加(make register 工具锚点,勿删)
	)
	if err != nil {
		rollback()
		return nil, nil, err
	}

	asynqServer := server.NewAsynqServer(ctx, taskService, internalMessageService, notificationService, videoService)

	return newApp(ctx, grpcServer, asynqServer), rollback, nil
}
