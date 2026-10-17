// Package auth 轻量鉴权中间件。
//
// Server：校验 Bearer JWT，把 claims 注入请求上下文（白名单操作跳过）。
// Client：BFF → core 转发时，把操作者身份写入 gRPC metadata（x-user-id），
// core 侧 Server 中间件再还原为 claims。开源版不做 RBAC，仅认证；
// Casbin/OPA 授权随管理后台周接入（对齐 GoWind Admin 体系）。
package auth

import (
	"context"
	"strconv"
	"strings"

	"github.com/go-kratos/kratos/v2/middleware"
	"github.com/go-kratos/kratos/v2/transport"
	kratosErrors "github.com/go-kratos/kratos/v2/errors"

	authnEngine "github.com/tx7do/kratos-authn/engine"
	authnJwt "github.com/tx7do/kratos-authn/engine/jwt"

	"go-wind-shortplay/pkg/authctx"
)

// metadata 键名（BFF → core 透传）
const (
	MetadataUserID = "x-user-id"
	bearerPrefix   = "Bearer "
)

// NewAuthenticator 构建 HS256 JWT 认证器（签发 / 校验共用同一 key）
func NewAuthenticator(signingKey string) (authnEngine.Authenticator, error) {
	return authnJwt.NewAuthenticator(
		authnJwt.WithSigningMethod("HS256"),
		authnJwt.WithSigningKey([]byte(signingKey)),
		authnJwt.WithVerificationKey([]byte(signingKey)),
	)
}

// NewServerMiddleware 入站鉴权中间件。
// whiteList 命中的操作直接放行（登录 / 注册 / 游客 Feed 等）；
// 其余操作必须携带有效 token，校验通过后把 claims 注入上下文。
func NewServerMiddleware(authenticator authnEngine.Authenticator, whiteList map[string]struct{}) middleware.Middleware {
	return func(handler middleware.Handler) middleware.Handler {
		return func(ctx context.Context, req interface{}) (interface{}, error) {
			if op, ok := transport.FromServerContext(ctx); ok {
				if _, allow := whiteList[op.Operation()]; allow {
					return handler(ctx, req)
				}
				token := op.RequestHeader().Get("Authorization")
				if token == "" {
					return nil, kratosErrors.Unauthorized("UNAUTHORIZED", "missing bearer token")
				}
				token = strings.TrimPrefix(token, bearerPrefix)
				claims, err := authenticator.AuthenticateToken(token)
				if err != nil {
					return nil, kratosErrors.Unauthorized("UNAUTHORIZED", "invalid or expired token")
				}
				ctx = authnEngine.ContextWithAuthClaims(ctx, claims)
			}
			return handler(ctx, req)
		}
	}
}

// NewClientMiddleware BFF 出站转发中间件：把登录用户ID写入 metadata 传给 core。
func NewClientMiddleware() middleware.Middleware {
	return NewClientMiddlewareFor("")
}

// NewClientMiddlewareFor 同上，并附加调用面标记（admin / app），
// core 据此放行管理端操作（强制下架 / 删评论等属主校验豁免）。
func NewClientMiddlewareFor(clientType string) middleware.Middleware {
	return func(handler middleware.Handler) middleware.Handler {
		return func(ctx context.Context, req interface{}) (interface{}, error) {
			if clientCtx, ok := transport.FromClientContext(ctx); ok {
				if uid := authctx.UserIDFromContext(ctx); uid > 0 {
					clientCtx.RequestHeader().Set(MetadataUserID, uint32ToString(uid))
				}
				if clientType != "" {
					clientCtx.RequestHeader().Set(authctx.MetadataClientType, clientType)
				}
			}
			return handler(ctx, req)
		}
	}
}

// NewCoreServerMiddleware core 入站中间件：从 metadata 还原操作者身份为 claims。
func NewCoreServerMiddleware() middleware.Middleware {
	return func(handler middleware.Handler) middleware.Handler {
		return func(ctx context.Context, req interface{}) (interface{}, error) {
			if op, ok := transport.FromServerContext(ctx); ok {
				if raw := op.RequestHeader().Get(MetadataUserID); raw != "" {
					if uid := parseUint32(raw); uid > 0 {
						claims := authnEngine.AuthClaims{
							authctx.ClaimUserID: uid,
						}
						ctx = authnEngine.ContextWithAuthClaims(ctx, &claims)
					}
				}
			}
			return handler(ctx, req)
		}
	}
}

func uint32ToString(v uint32) string {
	return strconv.FormatUint(uint64(v), 10)
}

func parseUint32(s string) uint32 {
	n, err := strconv.ParseUint(s, 10, 32)
	if err != nil {
		return 0
	}
	return uint32(n)
}
