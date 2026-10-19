package constants

import (
	"time"

	"github.com/tx7do/go-utils/timeutil"
	"github.com/tx7do/go-utils/trans"

	authenticationV1 "go-wind-shortplay/api/gen/go/authentication/service/v1"
	dictV1 "go-wind-shortplay/api/gen/go/dict/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	notifyV1 "go-wind-shortplay/api/gen/go/notify/service/v1"
	permissionV1 "go-wind-shortplay/api/gen/go/permission/service/v1"
)

const (
	// DefaultAdminUserName 系统初始化默认管理员用户名
	DefaultAdminUserName = "admin"
	// DefaultAdminPassword 系统初始化默认管理员用户密码
	DefaultAdminPassword = "admin"

	// DefaultUserPassword 系统初始化默认普通用户密码
	DefaultUserPassword = "12345678"

	// PlatformTenantID 平台管理员租户ID
	PlatformTenantID = uint32(0)
)

// DefaultPermissionGroups 系统初始化默认权限组数据
var DefaultPermissionGroups = []*permissionV1.PermissionGroup{
	{
		//Id:        trans.Ptr(uint32(1)),
		Name:      trans.Ptr("系统管理"),
		Path:      trans.Ptr("/"),
		Module:    trans.Ptr(SystemPermissionModule),
		SortOrder: trans.Ptr(uint32(1)),
		Status:    trans.Ptr(permissionV1.PermissionGroup_ON),
	},
	{
		//Id:        trans.Ptr(uint32(2)),
		ParentId:  trans.Ptr(uint32(1)),
		Name:      trans.Ptr("系统权限"),
		Path:      trans.Ptr("/1/2/"),
		Module:    trans.Ptr(SystemPermissionModule),
		SortOrder: trans.Ptr(uint32(1)),
		Status:    trans.Ptr(permissionV1.PermissionGroup_ON),
	},
	{
		//Id:        trans.Ptr(uint32(3)),
		ParentId:  trans.Ptr(uint32(1)),
		Name:      trans.Ptr("租户管理"),
		Path:      trans.Ptr("/1/3/"),
		Module:    trans.Ptr(SystemPermissionModule),
		SortOrder: trans.Ptr(uint32(2)),
		Status:    trans.Ptr(permissionV1.PermissionGroup_ON),
	},
	{
		//Id:        trans.Ptr(uint32(4)),
		ParentId:  trans.Ptr(uint32(1)),
		Name:      trans.Ptr("审计管理"),
		Path:      trans.Ptr("/1/4/"),
		Module:    trans.Ptr(SystemPermissionModule),
		SortOrder: trans.Ptr(uint32(3)),
		Status:    trans.Ptr(permissionV1.PermissionGroup_ON),
	},
	{
		//Id:        trans.Ptr(uint32(5)),
		ParentId:  trans.Ptr(uint32(1)),
		Name:      trans.Ptr("安全策略"),
		Path:      trans.Ptr("/1/5/"),
		Module:    trans.Ptr(SystemPermissionModule),
		SortOrder: trans.Ptr(uint32(4)),
		Status:    trans.Ptr(permissionV1.PermissionGroup_ON),
	},
}

// DefaultPermissions 系统初始化默认权限数据。
// 注意：全部条目显式声明 Id——种子里的 GroupId / MenuIds / 角色 Permissions 都按
// 这些 Id 引用，显式化后与插入顺序解耦（既有库与全新库落库结果一致）。
var DefaultPermissions = []*permissionV1.Permission{
	{
		Id:          trans.Ptr(uint32(1)),
		GroupId:     trans.Ptr(uint32(2)),
		Name:        trans.Ptr("访问后台"),
		Description: trans.Ptr("允许用户访问系统后台管理界面"),
		Code:        trans.Ptr(SystemAccessBackendPermissionCode),
		Status:      trans.Ptr(permissionV1.Permission_ON),
	},
	{
		Id:          trans.Ptr(uint32(6)),
		GroupId:     trans.Ptr(uint32(2)),
		Name:        trans.Ptr("访问应用端"),
		Description: trans.Ptr("允许用户访问 C 端应用（Flutter App 登录必备）"),
		Code:        trans.Ptr(SystemAccessAppPermissionCode),
		Status:      trans.Ptr(permissionV1.Permission_ON),
	},
	{
		Id:          trans.Ptr(uint32(2)),
		GroupId:     trans.Ptr(uint32(2)),
		Name:        trans.Ptr("平台管理员权限"),
		Description: trans.Ptr("拥有系统所有功能的操作权限，可管理租户、用户、角色及所有资源"),
		Code:        trans.Ptr(SystemPlatformAdminPermissionCode),
		Status:      trans.Ptr(permissionV1.Permission_ON),
		MenuIds: []uint32{
			1, 2, 3, 4, 5, 6,
			10, 11,
			20, 21, 22, 23, 24,
			30, 31, 32, 33, 34, 35,
			40, 41, 42,
			50, 51, 52, 53, 54, 55,
			60, 62, 63, 64, 65, 66, 67,
			// shortplay 业务菜单（75=短剧管理目录；73 已删除，用户管理复用基座 id23）
			75, 70, 71, 72, 74,
		},
		ApiIds: []uint32{
			1, 2, 3, 4, 5, 6, 7, 8, 9,
			10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
			20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
			30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
			40, 41, 42, 43, 44, 45, 46, 47, 48, 49,
			50, 51, 52, 53, 54, 55, 56, 57, 58, 59,
			60, 61, 62, 63, 64, 65, 66, 67, 68,
			70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
			80, 81, 82, 83, 84, 85, 86, 87, 88, 89,
			90, 91, 92, 93, 94, 95, 96, 97, 98, 99,
			100, 101, 102, 103, 104, 105, 106, 107, 108, 109,
			110, 111, 112, 113, 114, 115, 116, 117, 118, 119,
			120, 121, 122, 123, 124, 125, 126, 127, 128, 129,
			130, 131, 132, 133, 134, 135, 136,
		},
	},
	{
		Id:          trans.Ptr(uint32(3)),
		GroupId:     trans.Ptr(uint32(3)),
		Name:        trans.Ptr("租户管理员权限"),
		Description: trans.Ptr("拥有租户内所有功能的操作权限，可管理用户、角色及租户内所有资源"),
		Code:        trans.Ptr(SystemTenantManagerPermissionCode),
		Status:      trans.Ptr(permissionV1.Permission_ON),
		MenuIds: []uint32{
			1, 2,
			20, 21, 22, 23, 24,
			30, 32,
			40, 41,
			50, 51,
			60, 62, 63, 64,
			// shortplay 业务菜单（不含平台专属的系统配置）
			75, 70, 71, 72,
		},
		ApiIds: []uint32{
			1, 2, 3, 4, 5, 6, 7, 8, 9,
			10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
			20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
			30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
			40, 41, 42, 43, 44, 45, 46, 47, 48, 49,
			50, 51, 52, 53, 54, 55, 56, 57, 58, 59,
			60, 61, 62, 63, 64, 65, 66, 67, 68,
			70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
			80, 81, 82, 83, 84, 85, 86, 87, 88, 89,
			90, 91, 92, 93, 94, 95, 96, 97, 98, 99,
			100, 101, 102, 103, 104, 105, 106, 107, 108, 109,
			110, 111, 112, 113, 114, 115, 116, 117, 118, 119,
			120, 121, 122, 123, 124, 125, 126, 127, 128,
		},
	},

	{
		Id:          trans.Ptr(uint32(4)),
		GroupId:     trans.Ptr(uint32(3)),
		Name:        trans.Ptr("管理租户"),
		Description: trans.Ptr("允许创建/修改/删除租户"),
		Code:        trans.Ptr(SystemManageTenantsPermissionCode),
		Status:      trans.Ptr(permissionV1.Permission_ON),
	},
	{
		Id:          trans.Ptr(uint32(5)),
		GroupId:     trans.Ptr(uint32(4)),
		Name:        trans.Ptr("查看审计日志"),
		Description: trans.Ptr("允许查看系统操作日志"),
		Code:        trans.Ptr(SystemAuditLogsPermissionCode),
		Status:      trans.Ptr(permissionV1.Permission_ON),
	},

	// ── shortplay 业务权限点（BFF 管理端点按域归口）──
	{
		Id:          trans.Ptr(uint32(7)),
		GroupId:     trans.Ptr(uint32(1)),
		Name:        trans.Ptr("视频管理"),
		Description: trans.Ptr("短视频审核/下架/删除/编辑（/admin/v1/videos*，含 UPDATE /admin/v1/videos/{id}）"),
		Code:        trans.Ptr(BizVideoManagePermissionCode),
		Status:      trans.Ptr(permissionV1.Permission_ON),
		MenuIds:     []uint32{70},
	},
	{
		Id:          trans.Ptr(uint32(8)),
		GroupId:     trans.Ptr(uint32(1)),
		Name:        trans.Ptr("评论管理"),
		Description: trans.Ptr("短视频评论查看/删除（/admin/v1/comments*）"),
		Code:        trans.Ptr(BizCommentManagePermissionCode),
		Status:      trans.Ptr(permissionV1.Permission_ON),
		MenuIds:     []uint32{71},
	},
	{
		Id:          trans.Ptr(uint32(9)),
		GroupId:     trans.Ptr(uint32(1)),
		Name:        trans.Ptr("举报管理"),
		Description: trans.Ptr("举报工单查看/处理（/admin/v1/reports*）"),
		Code:        trans.Ptr(BizReportManagePermissionCode),
		Status:      trans.Ptr(permissionV1.Permission_ON),
		MenuIds:     []uint32{72},
	},
	{
		// 用户管理复用基座菜单 id23（OPM/UserManagement），重复的 id73 已删除
		Id:          trans.Ptr(uint32(10)),
		GroupId:     trans.Ptr(uint32(1)),
		Name:        trans.Ptr("用户管理"),
		Description: trans.Ptr("App 用户管理（/admin/v1/users*）"),
		Code:        trans.Ptr(BizUserManagePermissionCode),
		Status:      trans.Ptr(permissionV1.Permission_ON),
		MenuIds:     []uint32{23},
	},
	{
		Id:          trans.Ptr(uint32(11)),
		GroupId:     trans.Ptr(uint32(1)),
		Name:        trans.Ptr("系统配置"),
		Description: trans.Ptr("shortplay 运维开关（/admin/v1/sysconf、/admin/v1/dashboard*）"),
		Code:        trans.Ptr(BizSysConfManagePermissionCode),
		Status:      trans.Ptr(permissionV1.Permission_ON),
		MenuIds:     []uint32{74},
	},
}

// DefaultRoles 系统初始化默认角色数据。
// Id 显式声明：DefaultRoleMetadata / DefaultUserRoles 按 Id 引用，
// Permissions 引用 DefaultPermissions 的显式 Id，与插入顺序解耦。
var DefaultRoles = []*permissionV1.Role{
	{
		Id:          trans.Ptr(uint32(1)),
		Name:        trans.Ptr(DefaultPlatformAdminRoleName),
		Code:        trans.Ptr(PlatformAdminRoleCode),
		Status:      trans.Ptr(permissionV1.Role_ON),
		Description: trans.Ptr("拥有系统所有功能的操作权限，可管理租户、用户、角色及所有资源"),
		IsProtected: trans.Ptr(true),
		Type:        trans.Ptr(permissionV1.Role_SYSTEM),
		SortOrder:   trans.Ptr(uint32(1)),
		Permissions: []uint32{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11},
	},
	{
		Id:          trans.Ptr(uint32(2)),
		Name:        trans.Ptr(DefaultTenantManagerRoleName + "模板"),
		Code:        trans.Ptr(TenantAdminTemplateRoleCode),
		Status:      trans.Ptr(permissionV1.Role_ON),
		Description: trans.Ptr("租户管理员角色，拥有租户内所有功能的操作权限，可管理用户、角色及所有资源"),
		IsProtected: trans.Ptr(true),
		Type:        trans.Ptr(permissionV1.Role_TEMPLATE),
		SortOrder:   trans.Ptr(uint32(2)),
		Permissions: []uint32{1, 3},
	},
	{
		Id:          trans.Ptr(uint32(3)),
		Name:        trans.Ptr("C端用户"),
		Code:        trans.Ptr(AppUserRoleCode),
		Status:      trans.Ptr(permissionV1.Role_ON),
		Description: trans.Ptr("短剧 C 端普通用户（Flutter App 登录/互动）"),
		IsProtected: trans.Ptr(true),
		Type:        trans.Ptr(permissionV1.Role_SYSTEM),
		SortOrder:   trans.Ptr(uint32(10)),
		Permissions: []uint32{6},
	},
}

// DefaultRoleMetadata 系统初始化默认角色元数据
var DefaultRoleMetadata = []*permissionV1.RoleMetadata{
	{
		//Id:              trans.Ptr(uint32(1)),
		RoleId:          trans.Ptr(uint32(1)),
		IsTemplate:      trans.Ptr(false),
		TemplateVersion: trans.Ptr(int32(1)),
		Scope:           permissionV1.RoleMetadata_PLATFORM.Enum(),
		SyncPolicy:      permissionV1.RoleMetadata_AUTO.Enum(),
	},
	{
		//Id:              trans.Ptr(uint32(2)),
		RoleId:          trans.Ptr(uint32(2)),
		IsTemplate:      trans.Ptr(true),
		TemplateFor:     trans.Ptr(TenantAdminRoleCode),
		TemplateVersion: trans.Ptr(int32(1)),
		Scope:           permissionV1.RoleMetadata_TENANT.Enum(),
		SyncPolicy:      permissionV1.RoleMetadata_AUTO.Enum(),
	},
}

// DefaultTenants 系统初始化默认租户数据。
// shortplay App 开放注册按 tenantCode 定位租户（RegisterUser），租户表为空
// 会导致注册 503；此处保证默认租户存在，由 TenantService 启动种子幂等落库。
// 租户的 tenant:user 普通用户角色由 RoleService 启动种子补齐（绑定 sys:access_app）。
var DefaultTenants = []*identityV1.Tenant{
	{
		Code:   trans.Ptr(DefaultTenantCode),
		Name:   trans.Ptr("ShortPlay"),
		Type:   trans.Ptr(identityV1.Tenant_INTERNAL),
		Status: trans.Ptr(identityV1.Tenant_ON),
		Remark: trans.Ptr("App 开放注册默认租户（种子自动创建）"),
	},
}

// DefaultUsers 系统初始化默认用户数据
var DefaultUsers = []*identityV1.User{
	{
		//Id:       trans.Ptr(uint32(1)),
		TenantId: trans.Ptr(uint32(0)),
		Username: trans.Ptr(DefaultAdminUserName),
		Realname: trans.Ptr("喵个咪"),
		Nickname: trans.Ptr("鹳狸猿"),
		Region:   trans.Ptr("中国"),
		Email:    trans.Ptr("admin@gmail.com"),
	},
}

// DefaultUserCredentials 系统初始化默认用户凭证数据
var DefaultUserCredentials = []*authenticationV1.UserCredential{
	{
		UserId:         trans.Ptr(uint32(1)),
		TenantId:       trans.Ptr(uint32(0)),
		IdentityType:   authenticationV1.UserCredential_USERNAME.Enum(),
		Identifier:     trans.Ptr(DefaultAdminUserName),
		CredentialType: authenticationV1.UserCredential_PASSWORD_HASH.Enum(),
		Credential:     trans.Ptr(DefaultAdminPassword),
		IsPrimary:      trans.Ptr(true),
		Status:         authenticationV1.UserCredential_ENABLED.Enum(),
	},
}

// DefaultUserRoles 系统初始化默认用户角色关系数据
var DefaultUserRoles = []*permissionV1.UserRole{
	{
		UserId:    trans.Ptr(uint32(1)),
		TenantId:  trans.Ptr(uint32(0)),
		RoleId:    trans.Ptr(uint32(1)),
		IsPrimary: trans.Ptr(true),
		Status:    permissionV1.UserRole_ACTIVE.Enum(),
	},
}

// DefaultMemberships 系统初始化默认用户成员关系数据
var DefaultMemberships = []*identityV1.Membership{
	{
		UserId:    trans.Ptr(uint32(1)),
		TenantId:  trans.Ptr(uint32(0)),
		Status:    identityV1.Membership_ACTIVE.Enum(),
		IsPrimary: trans.Ptr(true),
		RoleIds:   []uint32{1},
	},
}

// DefaultLanguages 系统初始化默认语言数据
var DefaultLanguages = []*dictV1.Language{
	{LanguageCode: trans.Ptr("zh-CN"), LanguageName: trans.Ptr("中文（简体）"), NativeName: trans.Ptr("简体中文"), IsDefault: trans.Ptr(true), IsEnabled: trans.Ptr(true), SortOrder: trans.Uint32(0)},
	{LanguageCode: trans.Ptr("zh-TW"), LanguageName: trans.Ptr("中文（繁体）"), NativeName: trans.Ptr("繁體中文"), IsDefault: trans.Ptr(false), IsEnabled: trans.Ptr(true), SortOrder: trans.Uint32(100)},
	{LanguageCode: trans.Ptr("en-US"), LanguageName: trans.Ptr("英语"), NativeName: trans.Ptr("English"), IsDefault: trans.Ptr(false), IsEnabled: trans.Ptr(true), SortOrder: trans.Uint32(1)},
	{LanguageCode: trans.Ptr("ja-JP"), LanguageName: trans.Ptr("日语"), NativeName: trans.Ptr("日本語"), IsDefault: trans.Ptr(false), IsEnabled: trans.Ptr(true), SortOrder: trans.Uint32(100)},
	{LanguageCode: trans.Ptr("ko-KR"), LanguageName: trans.Ptr("韩语"), NativeName: trans.Ptr("한국어"), IsDefault: trans.Ptr(false), IsEnabled: trans.Ptr(true), SortOrder: trans.Uint32(100)},
	{LanguageCode: trans.Ptr("es-ES"), LanguageName: trans.Ptr("西班牙语"), NativeName: trans.Ptr("Español"), IsDefault: trans.Ptr(false), IsEnabled: trans.Ptr(true), SortOrder: trans.Uint32(100)},
	{LanguageCode: trans.Ptr("fr-FR"), LanguageName: trans.Ptr("法语"), NativeName: trans.Ptr("Français"), IsDefault: trans.Ptr(false), IsEnabled: trans.Ptr(true), SortOrder: trans.Uint32(100)},
}

// DefaultMenus 系统初始化默认菜单数据
var DefaultMenus = []*permissionV1.Menu{
	{
		Id:        trans.Ptr(uint32(1)),
		ParentId:  nil,
		Type:      permissionV1.Menu_CATALOG.Enum(),
		Name:      trans.Ptr("Dashboard"),
		Path:      trans.Ptr("/dashboard"),
		Component: trans.Ptr("BasicLayout"),
		Status:    permissionV1.Menu_ON.Enum(),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(-1)),
			Title:     trans.Ptr("page.dashboard.title"),
			Icon:      trans.Ptr("lucide:layout-dashboard"),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		// Phase 2：业务看板页（React admin pageMap 组件标识 "dashboard"）。
		// 基座种子的 /analytics(Vue 组件路径) 在本前端无对应页面，按业务口径指向 /dashboard。
		Id:        trans.Ptr(uint32(2)),
		ParentId:  trans.Ptr(uint32(1)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("Dashboard"),
		Path:      trans.Ptr("/dashboard"),
		Component: trans.Ptr("dashboard"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(-1)),
			Title:     trans.Ptr("page.dashboard.analytics"),
			Icon:      trans.Ptr("lucide:area-chart"),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
			AffixTab:  trans.Ptr(true),
		},
	},

	{
		Id:        trans.Ptr(uint32(3)),
		ParentId:  nil,
		Type:      permissionV1.Menu_CATALOG.Enum(),
		Name:      trans.Ptr("Profile"),
		Path:      trans.Ptr("/profile"),
		Component: trans.Ptr("BasicLayout"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:      trans.Ptr("menu.profile.settings"),
			HideInMenu: trans.Ptr(true),
		},
	},
	{
		Id:        trans.Ptr(uint32(4)),
		ParentId:  trans.Ptr(uint32(3)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("ProfilePage"),
		Path:      trans.Ptr("/profile"),
		Component: trans.Ptr("profile/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:      trans.Ptr("menu.profile.settings"),
			Icon:       trans.Ptr("lucide:user-pen"),
			HideInMenu: trans.Ptr(true),
		},
	},

	{
		Id:        trans.Ptr(uint32(5)),
		ParentId:  nil,
		Type:      permissionV1.Menu_CATALOG.Enum(),
		Name:      trans.Ptr("Inbox"),
		Path:      trans.Ptr("/inbox"),
		Component: trans.Ptr("BasicLayout"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:      trans.Ptr("menu.profile.internalMessage"),
			HideInMenu: trans.Ptr(true),
		},
	},
	{
		Id:        trans.Ptr(uint32(6)),
		ParentId:  trans.Ptr(uint32(5)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("InboxPage"),
		Path:      trans.Ptr("/inbox"),
		Component: trans.Ptr("message/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:      trans.Ptr("menu.profile.internalMessage"),
			Icon:       trans.Ptr("lucide:message-circle-more"),
			HideInMenu: trans.Ptr(true),
		},
	},

	{
		Id:        trans.Ptr(uint32(10)),
		ParentId:  nil,
		Type:      permissionV1.Menu_CATALOG.Enum(),
		Name:      trans.Ptr("TenantManagement"),
		Path:      trans.Ptr("/tenant"),
		Redirect:  trans.Ptr("/tenant/members"),
		Component: trans.Ptr("BasicLayout"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(2000)),
			Title:     trans.Ptr("menu.tenant.moduleName"),
			Icon:      trans.Ptr("lucide:building-2"),
			Authority: []string{"sys:platform_admin"},
		},
	},
	{
		Id:        trans.Ptr(uint32(11)),
		ParentId:  trans.Ptr(uint32(10)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("TenantMemberManagement"),
		Path:      trans.Ptr("members"),
		Component: trans.Ptr("app/tenant/tenant/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(1)),
			Title:     trans.Ptr("menu.tenant.member"),
			Icon:      trans.Ptr("lucide:users"),
			Authority: []string{"sys:platform_admin"},
			AffixTab:  trans.Ptr(true),
		},
	},

	{
		Id:        trans.Ptr(uint32(20)),
		ParentId:  nil,
		Type:      permissionV1.Menu_CATALOG.Enum(),
		Name:      trans.Ptr("OrganizationalPersonnelManagement"),
		Path:      trans.Ptr("/opm"),
		Redirect:  trans.Ptr("/opm/users"),
		Component: trans.Ptr("BasicLayout"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(2001)),
			Title:     trans.Ptr("menu.opm.moduleName"),
			Icon:      trans.Ptr("lucide:users"),
			KeepAlive: trans.Ptr(true),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		Id:        trans.Ptr(uint32(21)),
		ParentId:  trans.Ptr(uint32(20)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("OrgUnitManagement"),
		Path:      trans.Ptr("org-units"),
		Component: trans.Ptr("app/opm/org_unit/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(1)),
			Title:     trans.Ptr("menu.opm.orgUnit"),
			Icon:      trans.Ptr("lucide:layers"),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		Id:        trans.Ptr(uint32(22)),
		ParentId:  trans.Ptr(uint32(20)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("PositionManagement"),
		Path:      trans.Ptr("positions"),
		Component: trans.Ptr("app/opm/position/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(2)),
			Title:     trans.Ptr("menu.opm.position"),
			Icon:      trans.Ptr("lucide:briefcase"),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		// 用户管理：component 指向本仓 React 用户页（pageMap "users"→pages/app/user）。
		// shortplay 无组织/职位页，基座 Vue 组件菜单（21/22）导航下发时按白名单裁剪；
		// 旧业务菜单 id73（/users）与本菜单路径冲突，已删除。
		Id:        trans.Ptr(uint32(23)),
		ParentId:  trans.Ptr(uint32(20)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("UserManagement"),
		Path:      trans.Ptr("users"),
		Component: trans.Ptr("users"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(3)),
			Title:     trans.Ptr("menu.opm.user"),
			Icon:      trans.Ptr("lucide:user"),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		Id:        trans.Ptr(uint32(24)),
		ParentId:  trans.Ptr(uint32(20)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("UserDetail"),
		Path:      trans.Ptr("users/detail/:id"),
		Component: trans.Ptr("app/opm/user/detail/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:      trans.Ptr("menu.opm.userDetail"),
			Authority:  []string{"sys:platform_admin", "sys:tenant_manager"},
			HideInMenu: trans.Ptr(true),
		},
	},

	{
		Id:        trans.Ptr(uint32(30)),
		ParentId:  nil,
		Type:      permissionV1.Menu_CATALOG.Enum(),
		Name:      trans.Ptr("PermissionManagement"),
		Path:      trans.Ptr("/permission"),
		Redirect:  trans.Ptr("/permission/codes"),
		Component: trans.Ptr("BasicLayout"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(2002)),
			Title:     trans.Ptr("menu.permission.moduleName"),
			Icon:      trans.Ptr("lucide:shield-check"),
			KeepAlive: trans.Ptr(true),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		// Phase 2：component 标识对齐 React admin pageMap（/permission/apis 等）
		Id:        trans.Ptr(uint32(31)),
		ParentId:  trans.Ptr(uint32(30)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("PermissionPointManagement"),
		Path:      trans.Ptr("apis"),
		Component: trans.Ptr("permission/apis"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.permission.permission"),
			Icon:      trans.Ptr("lucide:shield-ellipsis"),
			Order:     trans.Ptr(int32(1)),
			Authority: []string{"sys:platform_admin"},
		},
	},
	{
		Id:        trans.Ptr(uint32(32)),
		ParentId:  trans.Ptr(uint32(30)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("RoleManagement"),
		Path:      trans.Ptr("roles"),
		Component: trans.Ptr("permission/roles"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.permission.role"),
			Icon:      trans.Ptr("lucide:shield-user"),
			Order:     trans.Ptr(int32(2)),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		// Phase 2 新增：菜单管理页（React admin pageMap）
		Id:        trans.Ptr(uint32(33)),
		ParentId:  trans.Ptr(uint32(30)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("MenuManagement"),
		Path:      trans.Ptr("menus"),
		Component: trans.Ptr("permission/menus"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.permission.menu"),
			Icon:      trans.Ptr("lucide:menu"),
			Order:     trans.Ptr(int32(3)),
			Authority: []string{"sys:platform_admin"},
		},
	},
	{
		// Phase 2 新增：部门管理页（React admin pageMap）
		Id:        trans.Ptr(uint32(34)),
		ParentId:  trans.Ptr(uint32(30)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("DepartmentManagement"),
		Path:      trans.Ptr("departments"),
		Component: trans.Ptr("permission/departments"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.permission.department"),
			Icon:      trans.Ptr("lucide:network"),
			Order:     trans.Ptr(int32(4)),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		// 增量种子：权限组管理页（React admin pageMap permission/groups）。
		// 菜单种子为空表播种（MenuService.init count==0 门控），既有库升级
		// 不会自动补此行，需按同 Id（35）手工补种或重建库；id 顺延 30 段。
		Id:        trans.Ptr(uint32(35)),
		ParentId:  trans.Ptr(uint32(30)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("PermissionGroupManagement"),
		Path:      trans.Ptr("groups"),
		Component: trans.Ptr("permission/groups"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.permission.groups"),
			Icon:      trans.Ptr("lucide:key-round"),
			Order:     trans.Ptr(int32(5)),
			Authority: []string{"sys:platform_admin"},
		},
	},

	{
		Id:        trans.Ptr(uint32(40)),
		ParentId:  nil,
		Type:      permissionV1.Menu_CATALOG.Enum(),
		Name:      trans.Ptr("InternalMessageManagement"),
		Path:      trans.Ptr("/internal-message"),
		Redirect:  trans.Ptr("/internal-message/messages"),
		Component: trans.Ptr("BasicLayout"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(2003)),
			Title:     trans.Ptr("menu.internalMessage.moduleName"),
			Icon:      trans.Ptr("lucide:mail"),
			KeepAlive: trans.Ptr(true),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		Id:        trans.Ptr(uint32(41)),
		ParentId:  trans.Ptr(uint32(40)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("InternalMessageList"),
		Path:      trans.Ptr("messages"),
		Component: trans.Ptr("app/internal_message/message/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.internalMessage.internalMessage"),
			Icon:      trans.Ptr("lucide:message-circle-more"),
			Order:     trans.Ptr(int32(1)),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		Id:        trans.Ptr(uint32(42)),
		ParentId:  trans.Ptr(uint32(40)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("InternalMessageCategoryManagement"),
		Path:      trans.Ptr("categories"),
		Component: trans.Ptr("app/internal_message/category/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.internalMessage.internalMessageCategory"),
			Icon:      trans.Ptr("lucide:calendar-check"),
			Order:     trans.Ptr(int32(2)),
			Authority: []string{"sys:platform_admin"},
		},
	},

	{
		Id:        trans.Ptr(uint32(50)),
		ParentId:  nil,
		Type:      permissionV1.Menu_CATALOG.Enum(),
		Name:      trans.Ptr("LogAuditManagement"),
		Path:      trans.Ptr("/log"),
		Redirect:  trans.Ptr("/log/login-audit-logs"),
		Component: trans.Ptr("BasicLayout"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(2004)),
			Title:     trans.Ptr("menu.log.moduleName"),
			Icon:      trans.Ptr("lucide:logs"),
			KeepAlive: trans.Ptr(true),
			Authority: []string{"sys:platform_admin"},
		},
	},
	{
		Id:        trans.Ptr(uint32(51)),
		ParentId:  trans.Ptr(uint32(50)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("LoginAuditLog"),
		Path:      trans.Ptr("login-audit-logs"),
		Component: trans.Ptr("app/log/login_audit_log/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.log.loginAuditLog"),
			Icon:      trans.Ptr("lucide:user-lock"),
			Order:     trans.Ptr(int32(1)),
			Authority: []string{"sys:platform_admin"},
		},
	},
	{
		Id:        trans.Ptr(uint32(52)),
		ParentId:  trans.Ptr(uint32(50)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("ApiAuditLog"),
		Path:      trans.Ptr("api-audit-logs"),
		Component: trans.Ptr("app/log/api_audit_log/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.log.apiAuditLog"),
			Icon:      trans.Ptr("lucide:file-clock"),
			Order:     trans.Ptr(int32(2)),
			Authority: []string{"sys:platform_admin"},
		},
	},
	{
		Id:        trans.Ptr(uint32(53)),
		ParentId:  trans.Ptr(uint32(50)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("OperationAuditLog"),
		Path:      trans.Ptr("operation-audit-logs"),
		Component: trans.Ptr("app/log/operation_audit_log/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.log.operationAuditLog"),
			Icon:      trans.Ptr("lucide:shield-ellipsis"),
			Order:     trans.Ptr(int32(3)),
			Authority: []string{"sys:platform_admin"},
		},
	},
	{
		Id:        trans.Ptr(uint32(54)),
		ParentId:  trans.Ptr(uint32(50)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("DataAccessAuditLog"),
		Path:      trans.Ptr("data-access-audit-logs"),
		Component: trans.Ptr("app/log/data_access_audit_log/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.log.dataAccessAuditLog"),
			Icon:      trans.Ptr("lucide:shield-check"),
			Order:     trans.Ptr(int32(4)),
			Authority: []string{"sys:platform_admin"},
		},
	},
	{
		Id:        trans.Ptr(uint32(55)),
		ParentId:  trans.Ptr(uint32(50)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("PermissionAuditLog"),
		Path:      trans.Ptr("permission-audit-logs"),
		Component: trans.Ptr("app/log/permission_audit_log/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.log.permissionAuditLog"),
			Icon:      trans.Ptr("lucide:shield-alert"),
			Order:     trans.Ptr(int32(5)),
			Authority: []string{"sys:platform_admin"},
		},
	},

	{
		Id:        trans.Ptr(uint32(60)),
		ParentId:  nil,
		Type:      permissionV1.Menu_CATALOG.Enum(),
		Name:      trans.Ptr("System"),
		Path:      trans.Ptr("/system"),
		Redirect:  trans.Ptr("/system/menus"),
		Component: trans.Ptr("BasicLayout"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(2005)),
			Title:     trans.Ptr("menu.system.moduleName"),
			Icon:      trans.Ptr("lucide:settings"),
			KeepAlive: trans.Ptr(true),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		// 61 MenuManagement 已删除：与 33（PermissionManagement/MenuManagement，
		// component=permission/menus，React pageMap 可解析）重复，且其 Vue 组件
		// app/system/menu/index.vue 在本前端无页面；菜单管理统一走 33。
		Id:        trans.Ptr(uint32(62)),
		ParentId:  trans.Ptr(uint32(60)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("APIManagement"),
		Path:      trans.Ptr("apis"),
		Component: trans.Ptr("app/system/api/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.system.api"),
			Icon:      trans.Ptr("lucide:route"),
			Order:     trans.Ptr(int32(2)),
			Authority: []string{"sys:platform_admin"},
		},
	},
	{
		Id:        trans.Ptr(uint32(63)),
		ParentId:  trans.Ptr(uint32(60)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("DictManagement"),
		Path:      trans.Ptr("dict"),
		Component: trans.Ptr("app/system/dict/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.system.dict"),
			Icon:      trans.Ptr("lucide:library-big"),
			Order:     trans.Ptr(int32(3)),
			Authority: []string{"sys:platform_admin"},
		},
	},
	{
		Id:        trans.Ptr(uint32(64)),
		ParentId:  trans.Ptr(uint32(60)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("FileManagement"),
		Path:      trans.Ptr("files"),
		Component: trans.Ptr("app/system/file/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.system.file"),
			Icon:      trans.Ptr("lucide:file-search"),
			Order:     trans.Ptr(int32(4)),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		Id:        trans.Ptr(uint32(65)),
		ParentId:  trans.Ptr(uint32(60)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("TaskManagement"),
		Path:      trans.Ptr("tasks"),
		Component: trans.Ptr("app/system/task/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.system.task"),
			Icon:      trans.Ptr("lucide:list-todo"),
			Order:     trans.Ptr(int32(5)),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		Id:        trans.Ptr(uint32(66)),
		ParentId:  trans.Ptr(uint32(60)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("LoginPolicyManagement"),
		Path:      trans.Ptr("login-policies"),
		Component: trans.Ptr("app/system/login_policy/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.system.loginPolicy"),
			Icon:      trans.Ptr("lucide:shield-x"),
			Order:     trans.Ptr(int32(6)),
			Authority: []string{"sys:platform_admin"},
		},
	},
	{
		Id:        trans.Ptr(uint32(67)),
		ParentId:  trans.Ptr(uint32(60)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("LanguageManagement"),
		Path:      trans.Ptr("languages"),
		Component: trans.Ptr("app/system/language/index.vue"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Title:     trans.Ptr("menu.system.language"),
			Icon:      trans.Ptr("lucide:globe"),
			Order:     trans.Ptr(int32(7)),
			Authority: []string{"sys:platform_admin"},
		},
	},
	// ── shortplay 业务菜单（归组到「短剧管理」目录 75 下；i18n 键对齐基座惯例）──
	// 去重：旧 id73 用户管理与基座 id23（OPM/UserManagement）路径同为 /users，
	// 删除 73 复用 23（component 已指向本仓用户页）；73 不再出现。
	{
		// 短剧管理目录（React pageMap 无需页面：目录节点 component=BasicLayout）
		Id:        trans.Ptr(uint32(75)),
		ParentId:  nil,
		Type:      permissionV1.Menu_CATALOG.Enum(),
		Name:      trans.Ptr("ShortPlayManagement"),
		Path:      trans.Ptr("/shortplay"),
		Redirect:  trans.Ptr("/shortplay/videos"),
		Component: trans.Ptr("BasicLayout"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(1000)),
			Title:     trans.Ptr("menu.shortPlay.moduleName"),
			Icon:      trans.Ptr("lucide:clapperboard"),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		Id:        trans.Ptr(uint32(70)),
		ParentId:  trans.Ptr(uint32(75)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("VideoManagement"),
		Path:      trans.Ptr("videos"),
		Component: trans.Ptr("videos"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(1)),
			Title:     trans.Ptr("menu.shortPlay.video"),
			Icon:      trans.Ptr("lucide:monitor-play"),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		Id:        trans.Ptr(uint32(71)),
		ParentId:  trans.Ptr(uint32(75)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("CommentManagement"),
		Path:      trans.Ptr("comments"),
		Component: trans.Ptr("comments"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(2)),
			Title:     trans.Ptr("menu.shortPlay.comment"),
			Icon:      trans.Ptr("lucide:message-square-text"),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		Id:        trans.Ptr(uint32(72)),
		ParentId:  trans.Ptr(uint32(75)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("ReportManagement"),
		Path:      trans.Ptr("reports"),
		Component: trans.Ptr("reports"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(3)),
			Title:     trans.Ptr("menu.shortPlay.report"),
			Icon:      trans.Ptr("lucide:flag"),
			Authority: []string{"sys:platform_admin", "sys:tenant_manager"},
		},
	},
	{
		Id:        trans.Ptr(uint32(74)),
		ParentId:  trans.Ptr(uint32(75)),
		Type:      permissionV1.Menu_MENU.Enum(),
		Name:      trans.Ptr("SysConfManagement"),
		Path:      trans.Ptr("sysconf"),
		Component: trans.Ptr("sysconf"),
		CreatedAt: timeutil.TimeToTimestamppb(trans.Ptr(time.Now())),
		Meta: &permissionV1.MenuMeta{
			Order:     trans.Ptr(int32(4)),
			Title:     trans.Ptr("menu.shortPlay.sysconf"),
			Icon:      trans.Ptr("lucide:settings-2"),
			Authority: []string{"sys:platform_admin"},
		},
	},
}

// DefaultNotificationRules 通知路由规则默认行（通知域）：事件 → 渠道。
// 只在空表播种（NotificationRuleService 构造期守卫，与 DefaultMenus 同一模式）：
// 管理员删掉一行是"该事件不再通知"的决定，重启不复活；
// 新增事件类型时已部署实例不会自动多出行，需在通知规则页手工新增。
var DefaultNotificationRules = []*notifyV1.NotificationRule{
	{
		EventType: notifyV1.EventType_INTERNAL_MESSAGE.Enum(),
		Channel:   notifyV1.Channel_INTERNAL.Enum(),
		IsAsync:   trans.Ptr(false),
		IsEnabled: trans.Ptr(true),
		Remark:    trans.Ptr("站内信投递（系统通知）：落收件箱 + 投递台账"),
	},
	{
		// 渠道页「测试邮件」的兜底路由：SendTestEmail 显式点名渠道配置，
		// 但路由表仍须有这行才放行（缺行/停用时显式 Channel 枚举才构成完整决定，
		// channel_id 不算）——与上游通知域同一条种子口径。
		EventType: notifyV1.EventType_CHANNEL_TEST_EMAIL.Enum(),
		Channel:   notifyV1.Channel_EMAIL.Enum(),
		IsAsync:   trans.Ptr(false),
		IsEnabled: trans.Ptr(true),
		Remark:    trans.Ptr("渠道配置测试邮件（渠道页「测试发送」）"),
	},
	{
		// 系统通知邮件（NotifyUser 附加触达）的路由：HTML 壳由 EmailSender 统一包裹。
		// 管理员停用此行 = 整体关闭系统通知邮件出站（worker 记 SKIPPED 不重试）。
		EventType: notifyV1.EventType_SYSTEM_NOTIFY.Enum(),
		Channel:   notifyV1.Channel_EMAIL.Enum(),
		IsAsync:   trans.Ptr(false),
		IsEnabled: trans.Ptr(true),
		Remark:    trans.Ptr("系统通知邮件（NotifyUser 附加触达）"),
	},
}
