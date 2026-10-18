package constants

const (
	// DefaultTenantCode 默认租户代码（App 开放注册的缺省归属租户）。
	// 租户表为空时基座 RegisterUser 按代码查不到租户会拒绝注册，
	// 种子（DefaultTenants）保证该租户存在，App 端注册缺省落到此租户。
	DefaultTenantCode = "shortplay"
)

// UserTenantRelationType 用户-租户关系类型，表示 users-tenants 是一对一还是一对多。
type UserTenantRelationType int

const (
	// UserTenantRelationNone 未启用多租户（例如单租户模式）
	UserTenantRelationNone UserTenantRelationType = iota

	// UserTenantRelationOneToOne users 与 tenants 为一对一关系：每个用户只属于一个租户
	UserTenantRelationOneToOne

	// UserTenantRelationOneToMany users 与 tenants 为一对多关系：每个用户可属于多个租户
	UserTenantRelationOneToMany
)

const (
	// DefaultUserTenantRelationType 用户与租户的默认关联关系
	// 如果启用多租户，推荐使用 UserTenantRelationOneToOne；默认一对一。
	DefaultUserTenantRelationType UserTenantRelationType = UserTenantRelationOneToOne

	// IsTenantModeEnabled 是否启用租户模式
	IsTenantModeEnabled = DefaultUserTenantRelationType == UserTenantRelationOneToOne || DefaultUserTenantRelationType == UserTenantRelationOneToMany
)
