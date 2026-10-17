package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"

	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/pkg/authctx"
)

type UserService struct {
	identityV1.UnimplementedUserServiceServer

	userRepo       *data.UserRepo
	interactionRepo *data.InteractionRepo
	videoRepo      *data.VideoRepo
	log            *log.Helper
}

func NewUserService(ctx *bootstrap.Context, userRepo *data.UserRepo, interactionRepo *data.InteractionRepo, videoRepo *data.VideoRepo) *UserService {
	return &UserService{
		userRepo:        userRepo,
		interactionRepo: interactionRepo,
		videoRepo:       videoRepo,
		log:             ctx.NewLoggerHelper("user/service/core-service"),
	}
}

func (s *UserService) GetUser(ctx context.Context, req *identityV1.GetUserRequest) (*identityV1.User, error) {
	u, err := s.userRepo.GetByID(ctx, req.GetId())
	if err != nil {
		return nil, identityV1.ErrorNotFound("user not found")
	}
	return toUser(u), nil
}

func (s *UserService) GetUserByUsername(ctx context.Context, req *identityV1.GetUserByUsernameRequest) (*identityV1.User, error) {
	u, err := s.userRepo.GetByUsername(ctx, req.GetUsername())
	if err != nil {
		return nil, identityV1.ErrorNotFound("user not found")
	}
	return toUser(u), nil
}

func (s *UserService) ListUser(ctx context.Context, req *paginationV1.PagingRequest) (*identityV1.ListUserResponse, error) {
	offset, limit := pageArgs(req.GetPage(), req.GetPageSize())
	items, total, err := s.userRepo.List(ctx, offset, limit, req.GetQuery())
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("list users failed")
	}
	out := make([]*identityV1.User, 0, len(items))
	for _, it := range items {
		out = append(out, toUser(it))
	}
	return &identityV1.ListUserResponse{Items: out, Total: ptr(int64(total))}, nil
}

func (s *UserService) CreateUser(ctx context.Context, req *identityV1.CreateUserRequest) (*identityV1.User, error) {
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
	hash, err := hashPassword(req.GetPassword())
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("hash password failed")
	}
	u, err := s.userRepo.Create(ctx, req.GetUsername(), hash, req.GetNickname())
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("create user failed")
	}
	return toUser(u), nil
}

func (s *UserService) UpdateUser(ctx context.Context, req *identityV1.UpdateUserRequest) (*identityV1.User, error) {
	var passwordHash *string
	if req.GetPassword() != "" {
		h, err := hashPassword(req.GetPassword())
		if err != nil {
			return nil, identityV1.ErrorInternalServerError("hash password failed")
		}
		passwordHash = &h
	}
	u, err := s.userRepo.Update(ctx, req.GetId(), req.Nickname, req.AvatarUrl, req.Bio, passwordHash)
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("update user failed")
	}
	return toUser(u), nil
}

func (s *UserService) DeleteUser(ctx context.Context, req *identityV1.DeleteUserRequest) (*emptypb.Empty, error) {
	if err := s.userRepo.Delete(ctx, req.GetId()); err != nil {
		return nil, identityV1.ErrorInternalServerError("delete user failed")
	}
	return &emptypb.Empty{}, nil
}

func (s *UserService) UpdateUserStatus(ctx context.Context, req *identityV1.UpdateUserStatusRequest) (*identityV1.User, error) {
	u, err := s.userRepo.UpdateStatus(ctx, req.GetId(), uint8(req.GetStatus()))
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("update user status failed")
	}
	return toUser(u), nil
}

// GetUserStats 用户创作统计（作品 / 粉丝 / 关注 / 获赞）
func (s *UserService) GetUserStats(ctx context.Context, req *identityV1.GetUserStatsRequest) (*identityV1.UserStats, error) {
	uid := req.GetUserId()
	stats := &identityV1.UserStats{UserId: ptr(uid)}

	// 作品数（已发布）
	_, videoTotal, err := s.videoRepo.List(ctx, 0, 1, ptr(uint8(3)), ptr(uid), "", "")
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("query user stats failed")
	}
	stats.VideoCount = ptr(uint64(videoTotal))

	following, followers, err := s.interactionRepo.FollowCounts(ctx, uid)
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("query follow counts failed")
	}
	stats.FollowingCount = ptr(uint64(following))
	stats.FollowerCount = ptr(uint64(followers))

	// 获赞总数：作者全部视频点赞列求和（小流量直接聚合）
	likeReceived, err := s.videoRepo.SumLikeCountByAuthor(ctx, uid)
	if err != nil {
		return nil, identityV1.ErrorInternalServerError("query like count failed")
	}
	stats.LikeReceivedCount = ptr(uint64(likeReceived))

	return stats, nil
}

// callerUserID 取操作者（游客返回 0）
func callerUserID(ctx context.Context) uint32 {
	return authctx.UserIDFromContext(ctx)
}

// pageArgs 页码页大小 → 偏移量与条数（含缺省与上限）
func pageArgs(page, pageSize uint32) (offset, limit int) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 10
	}
	if pageSize > 50 {
		pageSize = 50
	}
	return int((page - 1) * pageSize), int(pageSize)
}
