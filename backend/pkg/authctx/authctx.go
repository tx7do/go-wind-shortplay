// Package authctx 鉴权上下文取值助手。
//
// JWT claims 由网关 BFF 中间件解析后，经 gRPC metadata 透传到 core，
// 两侧统一通过本包读取操作者身份，业务代码不直接触碰 claims map。
package authctx

import (
	"context"

	"github.com/go-kratos/kratos/v2/transport"

	authnEngine "github.com/tx7do/kratos-authn/engine"
)

// claims 中约定的键名（签发与解析两侧必须一致）
const (
	ClaimUserID    = "userId"
	ClaimNickname  = "nickname"
	ClaimTokenType = "tokenType" // admin / app，区分令牌发行面
)

// ClaimsFromContext 从上下文取 claims（BFF 侧由 authn 中间件注入）
func ClaimsFromContext(ctx context.Context) *authnEngine.AuthClaims {
	if c, ok := authnEngine.AuthClaimsFromContext(ctx); ok {
		return c
	}
	return nil
}

// UserIDFromContext 取当前登录用户ID；未登录返回 0（游客）。
func UserIDFromContext(ctx context.Context) uint32 {
	claims := ClaimsFromContext(ctx)
	if claims == nil {
		return 0
	}
	id, _ := claims.GetUint32(ClaimUserID)
	return id
}

// IsAuthenticated 是否为登录用户
func IsAuthenticated(ctx context.Context) bool {
	return UserIDFromContext(ctx) > 0
}

// MetadataClientType 区分调用面（admin / app）的 metadata 键
const MetadataClientType = "x-client-type"

// ClientTypeFromContext 取调用面类型（BFF 侧或 core 侧均可）；
// 管理端操作（强制下架 / 删评论等）据此放行属主校验。
func ClientTypeFromContext(ctx context.Context) string {
	// core 侧：从 gRPC 入站 metadata 读（kratos transport header）
	if op, ok := transport.FromServerContext(ctx); ok {
		if v := op.RequestHeader().Get(MetadataClientType); v != "" {
			return v
		}
	}
	if cl, ok := transport.FromClientContext(ctx); ok {
		if v := cl.RequestHeader().Get(MetadataClientType); v != "" {
			return v
		}
	}
	return ""
}

// IsAdminCaller 是否来自管理端调用面
func IsAdminCaller(ctx context.Context) bool {
	return ClientTypeFromContext(ctx) == "admin"
}
