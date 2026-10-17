package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"

	adminV1 "go-wind-shortplay/api/gen/go/admin/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	reportV1 "go-wind-shortplay/api/gen/go/report/service/v1"
	statsV1 "go-wind-shortplay/api/gen/go/stats/service/v1"
	sysconfV1 "go-wind-shortplay/api/gen/go/sysconf/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
)

// ── AuthenticationService 管理员登录 ──

type AuthenticationService struct {
	adminV1.AuthenticationServiceHTTPServer

	authenticationServiceClient identityV1.AuthenticationServiceClient
	log                         *log.Helper
}

func NewAuthenticationService(ctx *bootstrap.Context, c identityV1.AuthenticationServiceClient) *AuthenticationService {
	return &AuthenticationService{
		log:                         ctx.NewLoggerHelper("authentication/service/admin-service"),
		authenticationServiceClient: c,
	}
}

func (s *AuthenticationService) Login(ctx context.Context, req *identityV1.LoginRequest) (*identityV1.LoginResponse, error) {
	return s.authenticationServiceClient.Login(ctx, req)
}

func (s *AuthenticationService) Logout(ctx context.Context, req *identityV1.LogoutRequest) (*emptypb.Empty, error) {
	return s.authenticationServiceClient.Logout(ctx, req)
}

// ── UserService 用户管理 ──

type UserService struct {
	adminV1.UserServiceHTTPServer

	userServiceClient identityV1.UserServiceClient
	log               *log.Helper
}

func NewUserService(ctx *bootstrap.Context, c identityV1.UserServiceClient) *UserService {
	return &UserService{
		log:               ctx.NewLoggerHelper("user/service/admin-service"),
		userServiceClient: c,
	}
}

func (s *UserService) List(ctx context.Context, req *paginationV1.PagingRequest) (*identityV1.ListUserResponse, error) {
	return s.userServiceClient.ListUser(ctx, req)
}

func (s *UserService) Get(ctx context.Context, req *identityV1.GetUserRequest) (*identityV1.User, error) {
	return s.userServiceClient.GetUser(ctx, req)
}

func (s *UserService) GetStats(ctx context.Context, req *identityV1.GetUserStatsRequest) (*identityV1.UserStats, error) {
	return s.userServiceClient.GetUserStats(ctx, req)
}

func (s *UserService) Create(ctx context.Context, req *identityV1.CreateUserRequest) (*identityV1.User, error) {
	if req.GetUsername() == "" || req.GetPassword() == "" {
		return nil, adminV1.ErrorBadRequest("username and password required")
	}
	return s.userServiceClient.CreateUser(ctx, req)
}

func (s *UserService) Update(ctx context.Context, req *identityV1.UpdateUserRequest) (*identityV1.User, error) {
	if req == nil {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}
	return s.userServiceClient.UpdateUser(ctx, req)
}

func (s *UserService) Delete(ctx context.Context, req *identityV1.DeleteUserRequest) (*emptypb.Empty, error) {
	return s.userServiceClient.DeleteUser(ctx, req)
}

func (s *UserService) UpdateStatus(ctx context.Context, req *identityV1.UpdateUserStatusRequest) (*identityV1.User, error) {
	return s.userServiceClient.UpdateUserStatus(ctx, req)
}

// ── VideoService 视频管理 ──

type VideoService struct {
	adminV1.VideoServiceHTTPServer

	videoServiceClient videoV1.VideoServiceClient
	log                *log.Helper
}

func NewVideoService(ctx *bootstrap.Context, c videoV1.VideoServiceClient) *VideoService {
	return &VideoService{
		log:                ctx.NewLoggerHelper("video/service/admin-service"),
		videoServiceClient: c,
	}
}

func (s *VideoService) List(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListVideoResponse, error) {
	return s.videoServiceClient.ListVideo(ctx, req)
}

func (s *VideoService) Get(ctx context.Context, req *videoV1.GetVideoRequest) (*videoV1.Video, error) {
	return s.videoServiceClient.GetVideo(ctx, req)
}

func (s *VideoService) ChangeStatus(ctx context.Context, req *videoV1.ChangeVideoStatusRequest) (*videoV1.Video, error) {
	if req == nil || req.GetId() == 0 {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}
	return s.videoServiceClient.ChangeVideoStatus(ctx, req)
}

func (s *VideoService) Delete(ctx context.Context, req *videoV1.DeleteVideoRequest) (*emptypb.Empty, error) {
	return s.videoServiceClient.DeleteVideo(ctx, req)
}

// ── CommentService 评论管理 ──

type CommentService struct {
	adminV1.CommentServiceHTTPServer

	commentServiceClient interactionV1.CommentServiceClient
	log                  *log.Helper
}

func NewCommentService(ctx *bootstrap.Context, c interactionV1.CommentServiceClient) *CommentService {
	return &CommentService{
		log:                  ctx.NewLoggerHelper("comment/service/admin-service"),
		commentServiceClient: c,
	}
}

func (s *CommentService) List(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListCommentResponse, error) {
	// 全量列表：video_id=0（core 侧按全量处理）
	return s.commentServiceClient.ListComment(ctx, &interactionV1.ListCommentRequest{
		VideoId:  0,
		PageNum:  req.Page,
		PageSize: req.PageSize,
	})
}

func (s *CommentService) Delete(ctx context.Context, req *interactionV1.DeleteCommentRequest) (*emptypb.Empty, error) {
	return s.commentServiceClient.DeleteComment(ctx, req)
}

// ── ReportService 举报工单 ──

type ReportService struct {
	adminV1.ReportServiceHTTPServer

	reportServiceClient reportV1.ReportServiceClient
	log                 *log.Helper
}

func NewReportService(ctx *bootstrap.Context, c reportV1.ReportServiceClient) *ReportService {
	return &ReportService{
		log:                 ctx.NewLoggerHelper("report/service/admin-service"),
		reportServiceClient: c,
	}
}

func (s *ReportService) List(ctx context.Context, req *paginationV1.PagingRequest) (*reportV1.ListReportResponse, error) {
	return s.reportServiceClient.ListReport(ctx, req)
}

func (s *ReportService) Get(ctx context.Context, req *reportV1.GetReportRequest) (*reportV1.Report, error) {
	return s.reportServiceClient.GetReport(ctx, req)
}

func (s *ReportService) Handle(ctx context.Context, req *reportV1.HandleReportRequest) (*reportV1.Report, error) {
	if req == nil || req.GetId() == 0 {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}
	return s.reportServiceClient.HandleReport(ctx, req)
}

// ── DashboardService 数据看板 ──

type DashboardService struct {
	adminV1.DashboardServiceHTTPServer

	dashboardServiceClient statsV1.DashboardServiceClient
	log                    *log.Helper
}

func NewDashboardService(ctx *bootstrap.Context, c statsV1.DashboardServiceClient) *DashboardService {
	return &DashboardService{
		log:                    ctx.NewLoggerHelper("dashboard/service/admin-service"),
		dashboardServiceClient: c,
	}
}

func (s *DashboardService) GetOverview(ctx context.Context, req *statsV1.GetOverviewRequest) (*statsV1.Overview, error) {
	return s.dashboardServiceClient.GetOverview(ctx, req)
}

func (s *DashboardService) ListTopVideos(ctx context.Context, req *statsV1.ListTopVideosRequest) (*videoV1.ListVideoResponse, error) {
	return s.dashboardServiceClient.ListTopVideos(ctx, req)
}

// ── SysConfService 系统配置 ──

type SysConfService struct {
	adminV1.SysConfServiceHTTPServer

	sysConfServiceClient sysconfV1.SysConfServiceClient
	log                  *log.Helper
}

func NewSysConfService(ctx *bootstrap.Context, c sysconfV1.SysConfServiceClient) *SysConfService {
	return &SysConfService{
		log:                  ctx.NewLoggerHelper("sysconf/service/admin-service"),
		sysConfServiceClient: c,
	}
}

func (s *SysConfService) Get(ctx context.Context, req *emptypb.Empty) (*sysconfV1.SysConf, error) {
	return s.sysConfServiceClient.GetSysConf(ctx, req)
}

func (s *SysConfService) Update(ctx context.Context, req *sysconfV1.UpdateSysConfRequest) (*sysconfV1.SysConf, error) {
	return s.sysConfServiceClient.UpdateSysConf(ctx, req)
}
