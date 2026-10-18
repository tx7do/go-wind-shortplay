package data

import (
	"context"
	"sync"

	"github.com/go-kratos/kratos/v2/log"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/tenant"

	"go-wind-shortplay/pkg/constants"
	appViewer "go-wind-shortplay/pkg/entgo/viewer"
)

// 业务行租户归属：视频/互动/评论/关注/举报/埋点/上传任务等业务数据必须挂在
// 具名租户（缺省 shortplay）下，否则 C 端租户用户经 TenantPrivacy 按
// tenant_id 过滤后"看得到点不了"。tenant viewer（C 端用户）由基座 mixin 的
// 租户注入机制兜底；这里补齐平台/系统上下文（无租户语义）的缺省归属。

var (
	defaultTenantMu      sync.Mutex
	defaultTenantIDCache uint32
)

// defaultBusinessTenantID 解析缺省业务租户（constants.DefaultTenantCode）的 ID，
// 进程内缓存；查询失败不缓存，下次调用重试。系统 viewer 直查，不受租户隔离影响。
func defaultBusinessTenantID(ctx context.Context, client *ent.Client) uint32 {
	defaultTenantMu.Lock()
	defer defaultTenantMu.Unlock()
	if defaultTenantIDCache > 0 {
		return defaultTenantIDCache
	}
	id, err := client.Tenant.Query().
		Where(tenant.CodeEQ(constants.DefaultTenantCode)).
		OnlyID(appViewer.NewSystemViewerContext(ctx))
	if err != nil {
		log.Warnf("resolve default business tenant [%s] failed: %s", constants.DefaultTenantCode, err.Error())
		return 0
	}
	defaultTenantIDCache = id
	return id
}

// businessTenantID 返回业务行的归属租户：优先取 viewer 携带的租户（C 端租户用户，
// 基座 TenantPrivacy 亦会强制覆盖）；平台/系统上下文缺省归 shortplay 租户，
// 避免业务行落 tenant_id=0 成为租户用户的孤儿数据。
func businessTenantID(ctx context.Context, client *ent.Client) (tenantID uint32, hasTenant bool) {
	if tid, ok := maybeTenantFromViewer(ctx); ok {
		return tid, true
	}
	if tid := defaultBusinessTenantID(ctx, client); tid > 0 {
		return tid, true
	}
	return 0, false
}
