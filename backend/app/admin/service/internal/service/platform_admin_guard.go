package service

import (
	"context"
	"slices"

	"github.com/go-kratos/kratos/v2/log"

	adminV1 "go-wind-shortplay/api/gen/go/admin/service/v1"

	"go-wind-shortplay/pkg/constants"
	"go-wind-shortplay/pkg/middleware/auth"
)

// requirePlatformAdmin 把平台专用的配置与源数据挡在平台管理员之内。
//
// 租户/菜单/API/权限/语言/登录策略/系统配置等表都是全局数据（多数没有
// tenant_id 列、无法靠数据层隔离挡跨租户篡改），而模块白名单闸门里这些
// 服务登记的模块因租户自助能力（用量查询、角色抽屉读权限树）常态在租户
// 套餐白名单内——authz 默认 noop 全放行时，租户操作者即可打到这些平台
// 专用变更端点。一道护栏不该靠漏配存在，所以判定显式放这里（移植自上游
// go-wind-admin da2b3a5f 的 notification 域 requirePlatformAdmin 同族清扫）。
//
// 平台管理员判定：IsPlatformAdmin 旗标为真，或令牌角色码含内置
// platform:admin（本仓登录链路以角色码承载身份语义）。
func requirePlatformAdmin(ctx context.Context, log *log.Helper, resource string) error {
	operator, err := auth.FromContext(ctx)
	if err != nil {
		return err
	}

	if operator.GetIsPlatformAdmin() || slices.Contains(operator.GetRoles(), constants.PlatformAdminRoleCode) {
		return nil
	}

	log.Errorf("operator [%d] (tenant %d) is not a platform administrator, %s access denied",
		operator.GetUserId(), operator.GetTenantId(), resource)

	return adminV1.ErrorForbidden("%s is platform-level configuration, only platform administrators may access it", resource)
}
