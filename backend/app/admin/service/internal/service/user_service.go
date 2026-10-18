package service

import (
	"context"
	"encoding/json"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/tx7do/go-utils/trans"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/fieldmaskpb"
	"google.golang.org/protobuf/types/known/timestamppb"

	adminV1 "go-wind-shortplay/api/gen/go/admin/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	permissionV1 "go-wind-shortplay/api/gen/go/permission/service/v1"
	statsV1 "go-wind-shortplay/api/gen/go/stats/service/v1"
)

// UserService 用户管理服务（admin BFF，shortplay 业务 App 用户）。
// 转发基座 identity UserService / permission RoleService / stats DashboardService，
// 并做业务契约形状映射（avatar→avatarUrl、description→bio、状态枚举 ↔ 1/2）。
type UserService struct {
	adminV1.UserServiceHTTPServer

	log *log.Helper

	userServiceClient identityV1.UserServiceClient
	roleServiceClient permissionV1.RoleServiceClient
	dashboardClient   statsV1.DashboardServiceClient
}

func NewUserService(
	ctx *bootstrap.Context,
	userServiceClient identityV1.UserServiceClient,
	roleServiceClient permissionV1.RoleServiceClient,
	dashboardClient statsV1.DashboardServiceClient,
) *UserService {
	return &UserService{
		log:               ctx.NewLoggerHelper("user/service/admin-service"),
		userServiceClient: userServiceClient,
		roleServiceClient: roleServiceClient,
		dashboardClient:   dashboardClient,
	}
}

// appUserStatusOf 基座状态枚举 → 业务 1禁用/2正常
func appUserStatusOf(s identityV1.User_Status) int32 {
	if s == identityV1.User_NORMAL {
		return 2
	}
	return 1
}

// statusOfAppUser 业务 "1"禁用/"2"正常 → 基座状态枚举
func statusOfAppUser(v string) identityV1.User_Status {
	if v == "1" {
		return identityV1.User_DISABLED
	}
	return identityV1.User_NORMAL
}

// appUserOf 基座 User → 业务 AppUser
func appUserOf(u *identityV1.User) *adminV1.AppUser {
	if u == nil {
		return nil
	}
	return &adminV1.AppUser{
		Id:        trans.Ptr(u.GetId()),
		Username:  trans.Ptr(u.GetUsername()),
		Nickname:  trans.Ptr(u.GetNickname()),
		AvatarUrl: trans.Ptr(u.GetAvatar()),
		Bio:       trans.Ptr(u.GetDescription()),
		Status:    trans.Ptr(appUserStatusOf(u.GetStatus())),
		CreatedAt: u.CreatedAt,
		UpdatedAt: u.UpdatedAt,
	}
}

func (s *UserService) List(ctx context.Context, req *paginationV1.PagingRequest) (*adminV1.ListAppUserResponse, error) {
	// 前端 query（昵称关键字）→ 基座过滤 JSON；filter（状态数字串）→ 状态枚举
	if req != nil {
		raw := req.GetQuery()
		if raw != "" && !json.Valid([]byte(raw)) {
			setPagingQuerySP(req, `{"nickname___icontains":"` + raw + `"}`)
		} else if raw == "" && req.GetFilter() != "" {
			st := "NORMAL"
			if req.GetFilter() == "1" {
				st = "DISABLED"
			}
			setPagingQuerySP(req, `{"status":"` + st + `"}`)
		}
	}
	resp, err := s.userServiceClient.List(ctx, req)
	if err != nil {
		return nil, err
	}
	out := &adminV1.ListAppUserResponse{}
	if resp.GetTotal() > 0 {
		out.Total = trans.Ptr(int64(resp.GetTotal()))
	} else {
		out.Total = trans.Ptr(int64(len(resp.GetItems())))
	}
	for _, u := range resp.GetItems() {
		out.Items = append(out.Items, appUserOf(u))
	}
	return out, nil
}

func (s *UserService) Get(ctx context.Context, req *adminV1.GetAppUserRequest) (*adminV1.AppUser, error) {
	u, err := s.userServiceClient.Get(ctx, &identityV1.GetUserRequest{
		QueryBy: &identityV1.GetUserRequest_Id{Id: req.GetId()},
	})
	if err != nil {
		return nil, err
	}
	return appUserOf(u), nil
}

func (s *UserService) Create(ctx context.Context, req *adminV1.CreateAppUserRequest) (*adminV1.AppUser, error) {
	if req == nil || req.GetUsername() == "" || req.GetPassword() == "" {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}
	resp, err := s.userServiceClient.Create(ctx, &identityV1.CreateUserRequest{
		Data: &identityV1.User{
			Username:    trans.Ptr(req.GetUsername()),
			Nickname:    trans.Ptr(req.GetNickname()),
			Avatar:      trans.Ptr(req.GetAvatarUrl()),
			Description: trans.Ptr(req.GetBio()),
			Status:      identityV1.User_NORMAL.Enum(),
			TenantId:    trans.Ptr(uint32(0)),
		},
		Password: trans.Ptr(req.GetPassword()),
	})
	if err != nil {
		return nil, err
	}
	return appUserOf(resp), nil
}

func (s *UserService) Update(ctx context.Context, req *adminV1.UpdateAppUserRequest) (*adminV1.AppUser, error) {
	if req == nil || req.GetId() == 0 {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}
	// 基座 userRepo.Update 依赖 update_mask 定位写入列，缺省 panic；
	// 未传的字段不进 mask（避免空串覆盖既有值）。
	paths := make([]string, 0, 3)
	data := &identityV1.User{}
	if req.GetNickname() != "" {
		data.Nickname = trans.Ptr(req.GetNickname())
		paths = append(paths, "nickname")
	}
	if req.GetAvatarUrl() != "" {
		data.Avatar = trans.Ptr(req.GetAvatarUrl())
		paths = append(paths, "avatar")
	}
	if req.GetBio() != "" {
		data.Description = trans.Ptr(req.GetBio())
		paths = append(paths, "description")
	}
	if _, err := s.userServiceClient.Update(ctx, &identityV1.UpdateUserRequest{
		Id:         req.GetId(),
		Data:       data,
		UpdateMask: &fieldmaskpb.FieldMask{Paths: paths},
		Password:   req.Password,
	}); err != nil {
		return nil, err
	}
	return s.Get(ctx, &adminV1.GetAppUserRequest{Id: req.GetId()})
}

func (s *UserService) Delete(ctx context.Context, req *adminV1.GetAppUserRequest) (*emptypb.Empty, error) {
	return s.userServiceClient.Delete(ctx, &identityV1.DeleteUserRequest{
		QueryBy: &identityV1.DeleteUserRequest_Id{Id: req.GetId()},
	})
}

func (s *UserService) UpdateStatus(ctx context.Context, req *adminV1.UpdateAppUserStatusRequest) (*adminV1.AppUser, error) {
	if req == nil || req.GetId() == 0 {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}
	if _, err := s.userServiceClient.Update(ctx, &identityV1.UpdateUserRequest{
		Id: req.GetId(),
		Data: &identityV1.User{
			Status: statusOfAppUser(req.GetStatus()).Enum(),
		},
		UpdateMask: &fieldmaskpb.FieldMask{Paths: []string{"status"}},
	}); err != nil {
		return nil, err
	}
	return s.Get(ctx, &adminV1.GetAppUserRequest{Id: req.GetId()})
}

func (s *UserService) GetStats(ctx context.Context, req *identityV1.GetUserStatsRequest) (*identityV1.UserStats, error) {
	return s.dashboardClient.GetUserStats(ctx, req)
}

func (s *UserService) SetUserRoles(ctx context.Context, req *adminV1.SetUserRolesRequest) (*emptypb.Empty, error) {
	if req == nil || req.GetId() == 0 {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}
	return s.roleServiceClient.AssignRolesToUser(ctx, &permissionV1.AssignRolesToUserRequest{
		UserId:  req.GetId(),
		RoleIds: req.GetRoleIds(),
	})
}

func (s *UserService) GetUserRoleIds(ctx context.Context, req *adminV1.GetAppUserRequest) (*adminV1.GetUserRoleIdsResponse, error) {
	resp, err := s.roleServiceClient.ListUserRoleIDs(ctx, &permissionV1.ListUserRoleIDsRequest{
		QueryBy: &permissionV1.ListUserRoleIDsRequest_UserId{UserId: req.GetId()},
	})
	if err != nil {
		return nil, err
	}
	return &adminV1.GetUserRoleIdsResponse{RoleIds: resp.GetRoleIds()}, nil
}

var _ = timestamppb.Now
