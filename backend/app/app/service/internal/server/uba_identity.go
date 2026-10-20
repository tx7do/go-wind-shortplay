package server

import (
	"context"
	"strings"

	"github.com/go-kratos/kratos/v2/middleware"
	"github.com/go-kratos/kratos/v2/transport"

	"go-wind-shortplay/pkg/metadata"
	"go-wind-shortplay/pkg/middleware/auth"
)

// UbaIdentityInjector 白名单路径的尽力身份注入。
//
// UBA 上报对游客开放（在 AddWhiteList 内，auth.Server 整段短路），但请求带有效
// token 时必须解析出操作者并写回请求头（随 gRPC 转发带 OperateMetadata），否则
// core 侧归因 uid=0——按用户派生的数据（观看历史等）全部失效。无 token / 解析
// 失败一律静默放行（游客口径，上报仍是尽力而为）。
func UbaIdentityInjector(checker auth.AccessTokenChecker) middleware.Middleware {
	return func(handler middleware.Handler) middleware.Handler {
		return func(ctx context.Context, req interface{}) (interface{}, error) {
			if checker != nil {
				if tr, ok := transport.FromServerContext(ctx); ok {
					token := strings.TrimSpace(strings.TrimPrefix(
						tr.RequestHeader().Get("Authorization"), "Bearer"))
					if token != "" {
						if valid, payload := checker.IsValidAccessToken(ctx, token, false); valid && payload != nil {
							operator := metadata.NewUserOperator(
								uint64(payload.GetUserId()),
								uint64(payload.GetTenantId()),
								uint64(payload.GetOrgUnitId()),
								payload.GetDataScope(),
							)
							// 与 auth.Server 同款两件套：ctx 注入（x-md-global- 前缀
							// 随 gRPC 客户端调用自动传播）+ 请求头回写
							var err error
							if ctx, err = metadata.NewContext(ctx, operator); err != nil {
								_ = err
							}
							if err := metadata.SetOperatorToRequestHeader(tr.RequestHeader(), operator); err != nil {
								_ = err
							}
						}
					}
				}
			}
			return handler(ctx, req)
		}
	}
}
