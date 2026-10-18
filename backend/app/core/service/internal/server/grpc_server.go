package server

import (
	"github.com/go-kratos/kratos/v2/middleware"
	"github.com/go-kratos/kratos/v2/middleware/logging"
	"github.com/go-kratos/kratos/v2/transport/grpc"

	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/tx7do/kratos-bootstrap/rpc"

	"go-wind-shortplay/app/core/service/internal/service"

	auditV1 "go-wind-shortplay/api/gen/go/audit/service/v1"
	authenticationV1 "go-wind-shortplay/api/gen/go/authentication/service/v1"
	commentV1 "go-wind-shortplay/api/gen/go/comment/service/v1"
	feedV1 "go-wind-shortplay/api/gen/go/feed/service/v1"
	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	reportV1 "go-wind-shortplay/api/gen/go/report/service/v1"
	statsV1 "go-wind-shortplay/api/gen/go/stats/service/v1"
	sysconfV1 "go-wind-shortplay/api/gen/go/sysconf/service/v1"
	ubaV1 "go-wind-shortplay/api/gen/go/uba/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
	dictV1 "go-wind-shortplay/api/gen/go/dict/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	internalMessageV1 "go-wind-shortplay/api/gen/go/internal_message/service/v1"
	mediaV1 "go-wind-shortplay/api/gen/go/media/service/v1"
	permissionV1 "go-wind-shortplay/api/gen/go/permission/service/v1"
	notifyV1 "go-wind-shortplay/api/gen/go/notify/service/v1"
	storageV1 "go-wind-shortplay/api/gen/go/storage/service/v1"
	taskV1 "go-wind-shortplay/api/gen/go/task/service/v1"

	"go-wind-shortplay/pkg/middleware/ent"
)

func NewGrpcMiddleware(ctx *bootstrap.Context) []middleware.Middleware {
	var ms []middleware.Middleware
	ms = append(ms, logging.Server(ctx.GetLogger()))
	ms = append(ms, ent.Server())
	return ms
}

// NewGrpcServer new a gRPC server.
func NewGrpcServer(
	ctx *bootstrap.Context,
	middlewares []middleware.Middleware,

	authenticationService *service.AuthenticationService,
	loginPolicyService *service.LoginPolicyService,
	userCredentialService *service.UserCredentialService,

	taskService *service.TaskService,

	fileService *service.FileService,

	dictTypeService *service.DictTypeService,
	dictEntryService *service.DictEntryService,
	languageService *service.LanguageService,

	tenantService *service.TenantService,
	userService *service.UserService,
	roleService *service.RoleService,
	positionService *service.PositionService,
	orgUnitService *service.OrgUnitService,

	menuService *service.MenuService,
	apiService *service.ApiService,
	permissionService *service.PermissionService,
	permissionGroupService *service.PermissionGroupService,
	permissionAuditLogService *service.PermissionAuditLogService,
	policyEvaluationLogService *service.PolicyEvaluationLogService,

	loginAuditLogService *service.LoginAuditLogService,
	apiAuditLogService *service.ApiAuditLogService,
	operationAuditLogService *service.OperationAuditLogService,
	dataAccessAuditLogService *service.DataAccessAuditLogService,

	internalMessageService *service.InternalMessageService,
	internalMessageCategoryService *service.InternalMessageCategoryService,
	internalMessageRecipientService *service.InternalMessageRecipientService,

	commentService *service.CommentService,

	mediaAssetService *service.MediaAssetService,

	notificationService *service.NotificationService,
	notificationChannelService *service.NotificationChannelService,
	notificationRuleService *service.NotificationRuleService,
	notificationTemplateService *service.NotificationTemplateService,
	notificationPreferenceService *service.NotificationPreferenceService,

	videoService *service.VideoService,
	feedService *service.FeedService,
	interactionService *service.InteractionService,
	videoCommentService *service.VideoCommentService,
	reportService *service.ReportService,
	sysConfService *service.SysConfService,
	ubaService *service.UbaService,
	dashboardService *service.DashboardService,

	// register:param ── 新模块服务形参在此行后注册(make register 工具锚点,勿删)
) (*grpc.Server, error) {
	cfg := ctx.GetConfig()

	if cfg == nil || cfg.Server == nil || cfg.Server.Grpc == nil {
		return nil, nil
	}

	srv, err := rpc.CreateGrpcServer(cfg, middlewares...)
	if err != nil {
		return nil, err
	}

	taskV1.RegisterTaskServiceServer(srv, taskService)

	authenticationV1.RegisterLoginPolicyServiceServer(srv, loginPolicyService)
	authenticationV1.RegisterAuthenticationServiceServer(srv, authenticationService)
	authenticationV1.RegisterUserCredentialServiceServer(srv, userCredentialService)

	dictV1.RegisterDictTypeServiceServer(srv, dictTypeService)
	dictV1.RegisterDictEntryServiceServer(srv, dictEntryService)
	dictV1.RegisterLanguageServiceServer(srv, languageService)

	permissionV1.RegisterApiServiceServer(srv, apiService)
	permissionV1.RegisterMenuServiceServer(srv, menuService)

	permissionV1.RegisterPermissionServiceServer(srv, permissionService)
	permissionV1.RegisterPermissionGroupServiceServer(srv, permissionGroupService)
	permissionV1.RegisterPolicyEvaluationLogServiceServer(srv, policyEvaluationLogService)
	permissionV1.RegisterRoleServiceServer(srv, roleService)

	identityV1.RegisterUserServiceServer(srv, userService)
	identityV1.RegisterOrgUnitServiceServer(srv, orgUnitService)
	identityV1.RegisterPositionServiceServer(srv, positionService)
	identityV1.RegisterTenantServiceServer(srv, tenantService)

	auditV1.RegisterLoginAuditLogServiceServer(srv, loginAuditLogService)
	auditV1.RegisterApiAuditLogServiceServer(srv, apiAuditLogService)
	auditV1.RegisterOperationAuditLogServiceServer(srv, operationAuditLogService)
	auditV1.RegisterDataAccessAuditLogServiceServer(srv, dataAccessAuditLogService)
	auditV1.RegisterPermissionAuditLogServiceServer(srv, permissionAuditLogService)

	storageV1.RegisterFileServiceServer(srv, fileService)

	internalMessageV1.RegisterInternalMessageServiceServer(srv, internalMessageService)
	internalMessageV1.RegisterInternalMessageCategoryServiceServer(srv, internalMessageCategoryService)
	internalMessageV1.RegisterInternalMessageRecipientServiceServer(srv, internalMessageRecipientService)

	commentV1.RegisterCommentServiceServer(srv, commentService)

	mediaV1.RegisterMediaAssetServiceServer(srv, mediaAssetService)

	notifyV1.RegisterNotificationServiceServer(srv, notificationService)
	notifyV1.RegisterNotificationChannelServiceServer(srv, notificationChannelService)
	notifyV1.RegisterNotificationRuleServiceServer(srv, notificationRuleService)
	notifyV1.RegisterNotificationTemplateServiceServer(srv, notificationTemplateService)
	notifyV1.RegisterNotificationPreferenceServiceServer(srv, notificationPreferenceService)

	// shortplay 业务域
	videoV1.RegisterVideoServiceServer(srv, videoService)
	feedV1.RegisterFeedServiceServer(srv, feedService)
	interactionV1.RegisterInteractionServiceServer(srv, interactionService)
	interactionV1.RegisterCommentServiceServer(srv, videoCommentService)
	reportV1.RegisterReportServiceServer(srv, reportService)
	sysconfV1.RegisterSysConfServiceServer(srv, sysConfService)
	ubaV1.RegisterUbaServiceServer(srv, ubaService)
	statsV1.RegisterDashboardServiceServer(srv, dashboardService)

	// register:route ── 新模块路由在此行后注册(make register 工具锚点,勿删)

	return srv, nil
}
