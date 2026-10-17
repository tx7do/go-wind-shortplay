package service

import (
	"context"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	authnEngine "github.com/tx7do/kratos-authn/engine"
	passCrypto "github.com/tx7do/go-utils/password"

	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/pkg/authctx"
)

const (
	accessTokenTTL  = 24 * time.Hour
	refreshTokenTTL = 30 * 24 * time.Hour
)

type AuthenticationService struct {
	identityV1.UnimplementedAuthenticationServiceServer

	userRepo      *data.UserRepo
	sysConfigRepo *data.SysConfigRepo
	authenticator authnEngine.Authenticator
	log           *log.Helper

	crypto passCrypto.Crypto
}

func NewAuthenticationService(ctx *bootstrap.Context, userRepo *data.UserRepo, sysConfigRepo *data.SysConfigRepo, authenticator authnEngine.Authenticator) *AuthenticationService {
	crypto, _ := passCrypto.CreateCrypto("argon2")
	return &AuthenticationService{
		userRepo:      userRepo,
		sysConfigRepo: sysConfigRepo,
		authenticator: authenticator,
		log:           ctx.NewLoggerHelper("authn/service/core-service"),
		crypto:        crypto,
	}
}

func (s *AuthenticationService) Login(ctx context.Context, req *identityV1.LoginRequest) (*identityV1.LoginResponse, error) {
	u, err := s.userRepo.GetByUsername(ctx, req.GetUsername())
	if err != nil {
		return nil, identityV1.ErrorWrongPassword("incorrect username or password")
	}
	if u.Status != nil && *u.Status == uint8(identityV1.UserStatus_USER_STATUS_DISABLED) {
		return nil, identityV1.ErrorUserDisabled("user disabled")
	}
	if u.PasswordHash == nil {
		return nil, identityV1.ErrorWrongPassword("incorrect username or password")
	}
	ok, err := s.crypto.Verify(req.GetPassword(), *u.PasswordHash)
	if err != nil || !ok {
		return nil, identityV1.ErrorWrongPassword("incorrect username or password")
	}
	return s.issueTokens(ctx, u)
}

func (s *AuthenticationService) Register(ctx context.Context, req *identityV1.RegisterRequest) (*identityV1.LoginResponse, error) {
	cfg, err := s.sysConfigRepo.Get(ctx)
	if err == nil && cfg.RegisterEnabled != nil && !*cfg.RegisterEnabled {
		return nil, identityV1.ErrorForbidden("register disabled")
	}
	if req.GetUsername() == "" || req.GetPassword() == "" {
		return nil, identityV1.ErrorBadRequest("username and password required")
	}
	exist, err := s.userRepo.ExistUsername(ctx, req.GetUsername())
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("query user failed")
	}
	if exist {
		return nil, identityV1.ErrorUsernameTaken("username already taken")
	}
	hash, err := s.crypto.Encrypt(req.GetPassword())
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("hash password failed")
	}
	nickname := req.GetNickname()
	if nickname == "" {
		nickname = req.GetUsername()
	}
	u, err := s.userRepo.Create(ctx, req.GetUsername(), hash, nickname)
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("create user failed")
	}
	return s.issueTokens(ctx, u)
}

// Logout 无状态 JWT 语义下服务端不做吊销；接入令牌黑名单（Redis）后在此回收。
func (s *AuthenticationService) Logout(ctx context.Context, req *identityV1.LogoutRequest) (*emptypb.Empty, error) {
	return &emptypb.Empty{}, nil
}

// RefreshToken 凭刷新令牌换新令牌对
func (s *AuthenticationService) RefreshToken(ctx context.Context, req *identityV1.RefreshTokenRequest) (*identityV1.LoginResponse, error) {
	claims, err := s.authenticator.AuthenticateToken(req.GetRefreshToken())
	if err != nil {
		return nil, identityV1.ErrorInvalidRefreshToken("invalid refresh token")
	}
	tokenType, _ := claims.GetString(authctx.ClaimTokenType)
	if tokenType != "refresh" {
		return nil, identityV1.ErrorInvalidRefreshToken("not a refresh token")
	}
	uid, _ := claims.GetUint32(authctx.ClaimUserID)
	u, err := s.userRepo.GetByID(ctx, uid)
	if err != nil {
		return nil, identityV1.ErrorInvalidRefreshToken("user not found")
	}
	return s.issueTokens(ctx, u)
}

// issueTokens 签发访问 / 刷新令牌对
func (s *AuthenticationService) issueTokens(ctx context.Context, u *ent.User) (*identityV1.LoginResponse, error) {
	base := authnEngine.AuthClaims{
		authctx.ClaimUserID:   u.ID,
		authctx.ClaimNickname: u.Nickname,
	}

	accessClaims := cloneClaims(base)
	accessClaims[authctx.ClaimTokenType] = "access"
	accessClaims["exp"] = time.Now().Add(accessTokenTTL).Unix()
	access, err := s.authenticator.CreateIdentity(accessClaims)
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("issue access token failed")
	}

	refreshClaims := cloneClaims(base)
	refreshClaims[authctx.ClaimTokenType] = "refresh"
	refreshClaims["exp"] = time.Now().Add(refreshTokenTTL).Unix()
	refresh, err := s.authenticator.CreateIdentity(refreshClaims)
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("issue refresh token failed")
	}

	return &identityV1.LoginResponse{
		Authenticator: &identityV1.Authenticator{
			AccessToken:  ptr(access),
			RefreshToken: ptr(refresh),
			ExpiresIn:    ptr(int64(accessTokenTTL.Seconds())),
			TokenType:    ptr("Bearer"),
		},
		User: toUser(u),
	}, nil
}

func cloneClaims(src authnEngine.AuthClaims) authnEngine.AuthClaims {
	dst := make(authnEngine.AuthClaims, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}
