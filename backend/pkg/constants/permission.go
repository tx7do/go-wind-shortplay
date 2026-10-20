package constants

const (
	// SystemPermissionCodePrefix 系统权限代码前缀
	SystemPermissionCodePrefix = "sys:"

	// SystemAccessBackendPermissionCode 系统访问后台权限代码
	SystemAccessBackendPermissionCode = SystemPermissionCodePrefix + "access_backend"

	// SystemAccessAppPermissionCode 系统访问应用端(C 端)权限代码
	SystemAccessAppPermissionCode = SystemPermissionCodePrefix + "access_app"

	// SystemManageTenantsPermissionCode 系统管理租户权限代码
	SystemManageTenantsPermissionCode = SystemPermissionCodePrefix + "manage_tenants"

	// SystemAuditLogsPermissionCode 系统审计日志权限代码
	SystemAuditLogsPermissionCode = SystemPermissionCodePrefix + "audit_logs"

	// SystemPlatformAdminPermissionCode 系统平台管理员权限代码
	SystemPlatformAdminPermissionCode = SystemPermissionCodePrefix + "platform_admin"
	// SystemTenantManagerPermissionCode 系统租户管理员权限代码
	SystemTenantManagerPermissionCode = SystemPermissionCodePrefix + "tenant_manager"

	// SystemPermissionModule 系统权限模块标识
	SystemPermissionModule = "sys"

	// ── shortplay 业务权限点代码（Phase 2）──

	// BizVideoManagePermissionCode 视频管理权限代码
	BizVideoManagePermissionCode = DefaultBizPermissionModule + ":video_manage"
	// BizCommentManagePermissionCode 评论管理权限代码
	BizCommentManagePermissionCode = DefaultBizPermissionModule + ":comment_manage"
	// BizReportManagePermissionCode 举报管理权限代码
	BizReportManagePermissionCode = DefaultBizPermissionModule + ":report_manage"
	// BizUserManagePermissionCode 用户管理权限代码
	BizUserManagePermissionCode = DefaultBizPermissionModule + ":user_manage"
	// BizSysConfManagePermissionCode 系统配置权限代码
	BizSysConfManagePermissionCode = DefaultBizPermissionModule + ":sysconf_manage"
	// BizSeriesManagePermissionCode 剧集管理权限代码
	BizSeriesManagePermissionCode = DefaultBizPermissionModule + ":series_manage"

	// DefaultBizPermissionModule 业务权限模块标识
	DefaultBizPermissionModule = "biz"

	// UncategorizedPermissionGroup 未分类权限组标识
	UncategorizedPermissionGroup = "uncategorized"
)

// ProtectedPermissionCodes 受保护的权限代码列表，禁止删除
var ProtectedPermissionCodes = []string{
	SystemAccessBackendPermissionCode,
	SystemAccessAppPermissionCode,
	SystemManageTenantsPermissionCode,
	SystemAuditLogsPermissionCode,
	SystemPlatformAdminPermissionCode,
	SystemTenantManagerPermissionCode,
}
