package service

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"github.com/go-kratos/kratos/v2/log"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/tx7do/go-utils/crypto"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	"github.com/redis/go-redis/v9"

	appV1 "go-wind-shortplay/api/gen/go/app/service/v1"
	authenticationV1 "go-wind-shortplay/api/gen/go/authentication/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	sysconfV1 "go-wind-shortplay/api/gen/go/sysconf/service/v1"
	entmiddleware "go-wind-shortplay/pkg/middleware/ent"

	"go-wind-shortplay/pkg/constants"
	"go-wind-shortplay/pkg/middleware/auth"
	"go-wind-shortplay/pkg/netutil"
)

type AuthenticationService struct {
	appV1.AuthenticationServiceHTTPServer

	authenticationServiceClient authenticationV1.AuthenticationServiceClient
	tenantClient                identityV1.TenantServiceClient
	tenantResolve               entmiddleware.TenantResolver

	// shortplay 旧契约兼容面依赖（/auth/* 路由）
	userServiceClient identityV1.UserServiceClient
	sysConfClient     sysconfV1.SysConfServiceClient
	redisClient       *redis.Client

	log *log.Helper
}

func NewAuthenticationService(
	ctx *bootstrap.Context,
	authenticationServiceClient authenticationV1.AuthenticationServiceClient,
	tenantClient identityV1.TenantServiceClient,
	tenantResolve entmiddleware.TenantResolver,
	userServiceClient identityV1.UserServiceClient,
	sysConfClient sysconfV1.SysConfServiceClient,
	redisClient *redis.Client,
) *AuthenticationService {
	return &AuthenticationService{
		log:                         ctx.NewLoggerHelper("authn/service/app-service"),
		authenticationServiceClient: authenticationServiceClient,
		tenantClient:                tenantClient,
		tenantResolve:               tenantResolve,
		userServiceClient:           userServiceClient,
		sysConfClient:               sysConfClient,
		redisClient:                 redisClient,
	}
}

// Login 登陆
// GetOidcAuthorizeUrl 获取 OIDC 授权跳转地址（透传 core；state 由 core 生成并落 Redis）。
// 免鉴权端点（登录前置步骤）。redirect_uri 由前端按自身回调页传入。
func (s *AuthenticationService) GetOidcAuthorizeUrl(ctx context.Context, req *authenticationV1.GetOidcAuthorizeUrlRequest) (*authenticationV1.GetOidcAuthorizeUrlResponse, error) {
	return s.authenticationServiceClient.GetOidcAuthorizeUrl(ctx, req)
}

func (s *AuthenticationService) Login(ctx context.Context, req *authenticationV1.LoginRequest) (*authenticationV1.LoginResponse, error) {
	if req == nil {
		return nil, authenticationV1.ErrorBadRequest("invalid request")
	}

	req.ClientType = trans.Ptr(authenticationV1.ClientType_app)

	if req.GetGrantType() == authenticationV1.GrantType_refresh_token {
		operator, err := auth.FromContext(ctx)
		if err != nil {
			return nil, err
		}

		req.Jti = operator.Jti
		req.UserId = trans.Ptr(operator.GetUserId())
	}

	return s.authenticationServiceClient.Login(ctx, req)
}

// Logout 登出
func (s *AuthenticationService) Logout(ctx context.Context, _ *emptypb.Empty) (*emptypb.Empty, error) {
	operator, err := auth.FromContext(ctx)
	if err != nil {
		return nil, err
	}

	return s.authenticationServiceClient.Logout(ctx, &authenticationV1.LogoutRequest{
		ClientType: authenticationV1.ClientType_app,
		UserId:     operator.GetUserId(),
	})
}

// RefreshToken 刷新认证令牌
func (s *AuthenticationService) RefreshToken(ctx context.Context, req *authenticationV1.LoginRequest) (*authenticationV1.LoginResponse, error) {
	if req == nil {
		return nil, authenticationV1.ErrorBadRequest("invalid request")
	}

	// 常规路径:access token 仍有效时,auth 中间件已注入 operator。
	// 兜底路径:access token 已过期(本操作在白名单中,operator 不会被注入)时,
	// 从过期 JWT 的 payload 自行解码 uid/jti 作为刷新令牌的绑定键——真正的
	// 凭证校验由 core 以 refresh token 值完成,过期 access token 不作为凭证。
	operator, err := auth.FromContext(ctx)
	if err == nil {
		req.UserId = trans.Ptr(operator.GetUserId())
		req.Jti = operator.Jti
	} else if uid, jti, uerr := netutil.ParseUnverifiedBearerJWTClaims(ctx); uerr == nil {
		req.UserId = trans.Ptr(uid)
		req.Jti = trans.Ptr(jti)
	}

	req.ClientType = trans.Ptr(authenticationV1.ClientType_app)

	return s.authenticationServiceClient.RefreshToken(ctx, req)
}

// Register C 端注册。租户归属按请求 Host 解析(前端注册表单没有租户输入,
// 调用方传入的 tenant_code 一律丢弃),解析不出租户则拒绝;租户编号由 id 反查
// code 后传给 core(其按 code 定位租户,并把租户管理员角色分配给新用户,
// 否则无角色用户无法登录)。
func (s *AuthenticationService) Register(ctx context.Context, req *authenticationV1.RegisterUserRequest) (*authenticationV1.RegisterUserResponse, error) {
	if req == nil || strings.TrimSpace(req.GetUsername()) == "" || strings.TrimSpace(req.GetPassword()) == "" {
		return nil, authenticationV1.ErrorBadRequest("invalid username or password")
	}
	// 服务端兜底校验,口径与前端一致:用户名 3-20 位字母/数字/下划线,密码至少 6 位
	if len(req.GetUsername()) < 3 || len(req.GetUsername()) > 20 ||
		!regexp.MustCompile(`^[a-zA-Z0-9_]+$`).MatchString(req.GetUsername()) {
		return nil, authenticationV1.ErrorBadRequest("invalid username format")
	}
	if len(req.GetPassword()) < 6 {
		return nil, authenticationV1.ErrorBadRequest("password too weak")
	}
	if s.tenantResolve == nil || s.tenantClient == nil {
		return nil, authenticationV1.ErrorServiceUnavailable("register unavailable")
	}

	var tenantID uint32
	if hr, ok := khttp.RequestFromServerContext(ctx); ok && hr != nil && hr.Host != "" {
		if tid, err := s.tenantResolve.ResolveTenantIDByDomain(ctx, hr.Host); err == nil {
			tenantID = tid
		}
	}
	if tenantID == 0 {
		return nil, authenticationV1.ErrorBadRequest("cannot resolve tenant, registration unavailable")
	}

	tenant, err := s.tenantClient.Get(ctx, &identityV1.GetTenantRequest{
		QueryBy: &identityV1.GetTenantRequest_Id{Id: tenantID},
	})
	if err != nil || tenant == nil || tenant.GetStatus() != identityV1.Tenant_ON || tenant.GetCode() == "" {
		return nil, authenticationV1.ErrorBadRequest("tenant unavailable")
	}

	// 租户归属由服务端决定,调用方不可覆盖
	req.TenantCode = tenant.GetCode()

	// 密码口径对齐:前端提交的是 AES(base64) 密文,core 凭证创建期望明文
	//(入库前 bcrypt);而登录校验会先 AES 解密再比对。若此处不解密,注册会
	// 存下 bcrypt(密文),登录时永远对不上。
	raw, err := base64.StdEncoding.DecodeString(req.GetPassword())
	if err != nil {
		return nil, authenticationV1.ErrorBadRequest("invalid password encoding")
	}
	plain, err := crypto.AesDecrypt(raw, crypto.DefaultAESKey, nil)
	if err != nil {
		return nil, authenticationV1.ErrorBadRequest("invalid password encoding")
	}
	req.Password = string(plain)

	return s.authenticationServiceClient.RegisterUser(ctx, req)
}

// ── shortplay 旧契约兼容面（/auth/*）──

// authLoginResponseOf 基座登录响应 → 旧契约包装（authenticator + user）
func (s *AuthenticationService) authLoginResponseOf(ctx context.Context, resp *authenticationV1.LoginResponse, uid uint32, username string) (*appV1.AuthLoginResponse, error) {
	out := &appV1.AuthLoginResponse{}
	if resp != nil {
		out.Authenticator = &appV1.Authenticator{
			TokenType:    resp.GetTokenType().String(),
			AccessToken:  resp.GetAccessToken(),
			RefreshToken: resp.GetRefreshToken(),
			ExpiresIn:    int32(resp.GetExpiresIn()),
		}
	}
	// uid 从访问令牌 payload 反解：令牌是刚从 core 内网调用拿到的（非客户端传入），
	// payload 解码仅用于取 uid/username 展示字段，鉴权语义仍在 core。
	// username 直查需要租户上下文，C 端匿名链路不可用，故不走 user Get(by username)。
	if uid == 0 && resp != nil && resp.GetAccessToken() != "" {
		if payload := decodeJWTPayloadSP(resp.GetAccessToken()); payload != nil {
			uid = payload.UserId
			if username == "" {
				username = payload.Username
			}
		}
	}
	if uid > 0 {
		if u, err := s.userServiceClient.Get(ctx, &identityV1.GetUserRequest{
			QueryBy: &identityV1.GetUserRequest_Id{Id: uid},
		}); err == nil {
			out.User = &appV1.AuthUserProfile{
				Id:        u.GetId(),
				Username:  u.GetUsername(),
				Nickname:  u.GetNickname(),
				AvatarUrl: u.GetAvatar(),
			}
		}
	}
	return out, nil
}

// AuthLogin 旧契约登录：/app/v1/auth/login
func (s *AuthenticationService) AuthLogin(ctx context.Context, req *authenticationV1.LoginRequest) (*appV1.AuthLoginResponse, error) {
	if req == nil {
		return nil, authenticationV1.ErrorBadRequest("invalid request")
	}
	req.ClientType = authenticationV1.ClientType_app.Enum()
	resp, err := s.authenticationServiceClient.Login(ctx, req)
	if err != nil {
		return nil, err
	}
	return s.authLoginResponseOf(ctx, resp, 0, req.GetUsername())
}

// AuthRegister 旧契约注册：开放注册开关由系统配置把关；成功即登录。
// 旧契约请求无租户概念，租户代码由服务端给缺省（constants.DefaultTenantCode，
// 由 core 租户种子保证存在）；调用方传入值不可信，一律覆盖。
func (s *AuthenticationService) AuthRegister(ctx context.Context, req *appV1.AuthRegisterRequest) (*appV1.AuthLoginResponse, error) {
	if req == nil || req.GetUsername() == "" || req.GetPassword() == "" {
		return nil, authenticationV1.ErrorBadRequest("invalid request")
	}
	if conf, err := s.sysConfClient.GetSysConf(ctx, &emptypb.Empty{}); err == nil && !conf.GetRegisterEnabled() {
		return nil, authenticationV1.ErrorBadRequest("registration is disabled")
	}
	// 密码口径对齐：前端提交的是 AES(base64) 密文，core 凭证创建对入参直接
	// bcrypt 落库（期望明文），而登录校验会先 AES 解密再比对——注册侧必须
	// 先解密，否则存下 bcrypt(密文)，注册后自动登录永远对不上（同基座
	// 契约 Register 的解密逻辑）。
	raw, err := base64.StdEncoding.DecodeString(req.GetPassword())
	if err != nil {
		return nil, authenticationV1.ErrorBadRequest("invalid password encoding")
	}
	plain, derr := crypto.AesDecrypt(raw, crypto.DefaultAESKey, nil)
	if derr != nil {
		return nil, authenticationV1.ErrorBadRequest("invalid password encoding")
	}
	if _, err := s.authenticationServiceClient.RegisterUser(ctx, &authenticationV1.RegisterUserRequest{
		Username:   req.GetUsername(),
		Password:   string(plain),
		TenantCode: constants.DefaultTenantCode,
		ClientType: authenticationV1.ClientType_app.Enum(),
	}); err != nil {
		return nil, err
	}
	return s.AuthLogin(ctx, &authenticationV1.LoginRequest{
		GrantType: authenticationV1.GrantType_password,
		Identifier: &authenticationV1.LoginRequest_Username{
			Username: req.GetUsername(),
		},
		Password: trans.Ptr(req.GetPassword()),
	})
}

// AuthRefresh 旧契约刷新：仅凭 refreshToken（无 bearer）。
// 刷新令牌在 Redis 以 gwc:rt:{ct}:{uid}:{jti} 绑定，这里按值反查绑定键后走
// core 标准刷新（绑定校验/旧对吊销仍全部在 core 原子完成）。
func (s *AuthenticationService) AuthRefresh(ctx context.Context, req *appV1.AuthRefreshRequest) (*appV1.AuthLoginResponse, error) {
	if req == nil || req.GetRefreshToken() == "" {
		return nil, authenticationV1.ErrorBadRequest("invalid request")
	}
	uid, jti, found := s.findRefreshBinding(ctx, req.GetRefreshToken())
	if !found {
		return nil, authenticationV1.ErrorIncorrectRefreshToken("invalid refresh token")
	}
	resp, err := s.authenticationServiceClient.RefreshToken(ctx, &authenticationV1.LoginRequest{
		GrantType:    authenticationV1.GrantType_refresh_token,
		ClientType:   authenticationV1.ClientType_app.Enum(),
		UserId:       trans.Ptr(uid),
		Jti:          trans.Ptr(jti),
		RefreshToken: trans.Ptr(req.GetRefreshToken()),
	})
	if err != nil {
		return nil, err
	}
	return s.authLoginResponseOf(ctx, resp, uid, "")
}

// findRefreshBinding 按刷新令牌值反查 Redis 绑定键（gwc:rt:1:{uid}:{jti}）。
// 有界扫描：刷新是低频操作，活跃会话键量有限。
func (s *AuthenticationService) findRefreshBinding(ctx context.Context, refreshToken string) (uid uint32, jti string, found bool) {
	if s.redisClient == nil {
		return 0, "", false
	}
	const appClientType = 1 // authenticationV1.ClientType_app
	var cursor uint64
	// 键空间可能很大（令牌缓存），全量扫完为止；命中即返回。低频操作可接受。
	for i := 0; i < 300; i++ {
		keys, next, err := s.redisClient.Scan(ctx, cursor, fmt.Sprintf("gwc:rt:%d:*", appClientType), 1000).Result()
		if err != nil {
			return 0, "", false
		}
		for _, key := range keys {
			val, gerr := s.redisClient.Get(ctx, key).Result()
			if gerr != nil || val != refreshToken {
				continue
			}
			// gwc:rt:1:{uid}:{jti}
			parts := strings.SplitN(key, ":", 5)
			if len(parts) != 5 {
				continue
			}
			u64, perr := strconv.ParseUint(parts[3], 10, 32)
			if perr != nil {
				continue
			}
			return uint32(u64), parts[4], true
		}
		if next == 0 {
			break
		}
		cursor = next
	}
	return 0, "", false
}

// AuthLogout 旧契约登出：/app/v1/auth/logout（需登录）。
func (s *AuthenticationService) AuthLogout(ctx context.Context, _ *emptypb.Empty) (*emptypb.Empty, error) {
	return s.Logout(ctx, &emptypb.Empty{})
}

// spTokenClaims 访问令牌 payload claims（仅取展示字段）
type spTokenClaims struct {
	UserId   uint32
	Username string
}

// decodeJWTPayloadSP 解码 JWT payload（不验签——入参为内网 core 直接返回的令牌）。
func decodeJWTPayloadSP(token string) *spTokenClaims {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil
	}
	var claims struct {
		UID interface{} `json:"uid"`
		Sub string      `json:"sub"`
	}
	if err := json.Unmarshal(raw, &claims); err != nil {
		return nil
	}
	out := &spTokenClaims{Username: claims.Sub}
	switch v := claims.UID.(type) {
	case float64:
		out.UserId = uint32(v)
	case string:
		if u64, perr := strconv.ParseUint(v, 10, 32); perr == nil {
			out.UserId = uint32(u64)
		}
	}
	return out
}
