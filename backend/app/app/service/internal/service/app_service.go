package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"

	appV1 "go-wind-shortplay/api/gen/go/app/service/v1"
	feedV1 "go-wind-shortplay/api/gen/go/feed/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	notifyV1 "go-wind-shortplay/api/gen/go/notify/service/v1"
	reportV1 "go-wind-shortplay/api/gen/go/report/service/v1"
	statsV1 "go-wind-shortplay/api/gen/go/stats/service/v1"
	ubaV1 "go-wind-shortplay/api/gen/go/uba/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
	"go-wind-shortplay/pkg/authctx"
)

// ── AuthenticationService 注册 / 登录 ──

type AuthenticationService struct {
	appV1.AuthenticationServiceHTTPServer

	authenticationServiceClient identityV1.AuthenticationServiceClient
	log                         *log.Helper
}

func NewAuthenticationService(ctx *bootstrap.Context, c identityV1.AuthenticationServiceClient) *AuthenticationService {
	return &AuthenticationService{
		log:                         ctx.NewLoggerHelper("authentication/service/app-service"),
		authenticationServiceClient: c,
	}
}

func (s *AuthenticationService) Login(ctx context.Context, req *identityV1.LoginRequest) (*identityV1.LoginResponse, error) {
	return s.authenticationServiceClient.Login(ctx, req)
}

func (s *AuthenticationService) Register(ctx context.Context, req *identityV1.RegisterRequest) (*identityV1.LoginResponse, error) {
	return s.authenticationServiceClient.Register(ctx, req)
}

func (s *AuthenticationService) RefreshToken(ctx context.Context, req *identityV1.RefreshTokenRequest) (*identityV1.LoginResponse, error) {
	return s.authenticationServiceClient.RefreshToken(ctx, req)
}

func (s *AuthenticationService) Logout(ctx context.Context, req *identityV1.LogoutRequest) (*emptypb.Empty, error) {
	if req.UserId == nil {
		req.UserId = ptrU32(authctx.UserIDFromContext(ctx))
	}
	return s.authenticationServiceClient.Logout(ctx, req)
}

// ── UserService 用户主页 ──

type UserService struct {
	appV1.UserServiceHTTPServer

	userServiceClient identityV1.UserServiceClient
	videoServiceClient videoV1.VideoServiceClient
	log               *log.Helper
}

func NewUserService(ctx *bootstrap.Context, uc identityV1.UserServiceClient, vc videoV1.VideoServiceClient) *UserService {
	return &UserService{
		log:                ctx.NewLoggerHelper("user/service/app-service"),
		userServiceClient:  uc,
		videoServiceClient: vc,
	}
}

func (s *UserService) GetUser(ctx context.Context, req *identityV1.GetUserRequest) (*identityV1.User, error) {
	return s.userServiceClient.GetUser(ctx, req)
}

func (s *UserService) GetUserStats(ctx context.Context, req *identityV1.GetUserStatsRequest) (*identityV1.UserStats, error) {
	return s.userServiceClient.GetUserStats(ctx, req)
}

// UpdateProfile 编辑我的资料（user_id 强制取令牌主体，杜绝越权）
func (s *UserService) UpdateProfile(ctx context.Context, req *identityV1.UpdateUserRequest) (*identityV1.User, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, appV1.ErrorUnauthorized("login required")
	}
	req.Id = uid
	return s.userServiceClient.UpdateUser(ctx, req)
}

func (s *UserService) ListUserVideos(ctx context.Context, req *appV1.ListUserVideosRequest) (*videoV1.ListVideoResponse, error) {
	return s.videoServiceClient.ListUserVideo(ctx, &videoV1.ListUserVideoRequest{
		UserId:   req.GetUserId(),
		PageNum:  req.PageNum,
		PageSize: req.PageSize,
	})
}

// ── FeedService Feed 流 ──

type FeedService struct {
	appV1.FeedServiceHTTPServer

	feedServiceClient feedV1.FeedServiceClient
	log               *log.Helper
}

func NewFeedService(ctx *bootstrap.Context, c feedV1.FeedServiceClient) *FeedService {
	return &FeedService{
		log:               ctx.NewLoggerHelper("feed/service/app-service"),
		feedServiceClient: c,
	}
}

func (s *FeedService) GetFeed(ctx context.Context, req *feedV1.GetFeedRequest) (*feedV1.GetFeedResponse, error) {
	return s.feedServiceClient.GetFeed(ctx, req)
}

func (s *FeedService) GetVideoDetail(ctx context.Context, req *feedV1.GetVideoDetailRequest) (*feedV1.VideoDetail, error) {
	return s.feedServiceClient.GetVideoDetail(ctx, req)
}

func (s *FeedService) SearchVideos(ctx context.Context, req *feedV1.SearchVideosRequest) (*feedV1.GetFeedResponse, error) {
	return s.feedServiceClient.SearchVideos(ctx, req)
}

func (s *FeedService) ListVideosByTag(ctx context.Context, req *feedV1.ListVideosByTagRequest) (*feedV1.GetFeedResponse, error) {
	return s.feedServiceClient.ListVideosByTag(ctx, req)
}

// ── VideoService 创作（分片上传 / 草稿 / 我的作品） ──

type VideoService struct {
	appV1.VideoServiceHTTPServer

	videoServiceClient videoV1.VideoServiceClient
	dashboardClient    statsV1.DashboardServiceClient
	log                *log.Helper
}

func NewVideoService(ctx *bootstrap.Context, c videoV1.VideoServiceClient, dc statsV1.DashboardServiceClient) *VideoService {
	return &VideoService{
		log:                ctx.NewLoggerHelper("video/service/app-service"),
		videoServiceClient: c,
		dashboardClient:    dc,
	}
}

// GetCreatorOverview 创作者中心总览
func (s *VideoService) GetCreatorOverview(ctx context.Context, req *statsV1.GetCreatorOverviewRequest) (*statsV1.CreatorOverview, error) {
	return s.dashboardClient.GetCreatorOverview(ctx, req)
}

func (s *VideoService) CreateUploadTask(ctx context.Context, req *videoV1.CreateUploadTaskRequest) (*videoV1.UploadTask, error) {
	return s.videoServiceClient.CreateUploadTask(ctx, req)
}

func (s *VideoService) UploadChunk(ctx context.Context, req *appV1.UploadChunkRequest) (*videoV1.UploadChunkResponse, error) {
	if req.GetTaskId() == "" {
		return nil, appV1.ErrorBadRequest("invalid parameter")
	}
	return s.videoServiceClient.UploadChunk(ctx, &videoV1.UploadChunkRequest{
		TaskId:     req.GetTaskId(),
		ChunkIndex: req.GetChunkIndex(),
		Data:       req.GetData(),
	})
}

func (s *VideoService) CompleteUpload(ctx context.Context, req *videoV1.CompleteUploadRequest) (*videoV1.UploadTask, error) {
	return s.videoServiceClient.CompleteUpload(ctx, req)
}

func (s *VideoService) GetUploadTask(ctx context.Context, req *videoV1.GetUploadTaskRequest) (*videoV1.UploadTask, error) {
	return s.videoServiceClient.GetUploadTask(ctx, req)
}

func (s *VideoService) SaveDraft(ctx context.Context, req *videoV1.SaveDraftRequest) (*videoV1.VideoDraft, error) {
	return s.videoServiceClient.SaveDraft(ctx, req)
}

func (s *VideoService) ListDraft(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListDraftResponse, error) {
	return s.videoServiceClient.ListDraft(ctx, req)
}

func (s *VideoService) GetDraft(ctx context.Context, req *videoV1.GetDraftRequest) (*videoV1.VideoDraft, error) {
	return s.videoServiceClient.GetDraft(ctx, req)
}

func (s *VideoService) DeleteDraft(ctx context.Context, req *videoV1.DeleteDraftRequest) (*emptypb.Empty, error) {
	return s.videoServiceClient.DeleteDraft(ctx, req)
}

func (s *VideoService) SubmitDraft(ctx context.Context, req *videoV1.SubmitDraftRequest) (*videoV1.Video, error) {
	return s.videoServiceClient.SubmitDraft(ctx, req)
}

func (s *VideoService) UpdateVideo(ctx context.Context, req *videoV1.UpdateVideoRequest) (*videoV1.Video, error) {
	return s.videoServiceClient.UpdateVideo(ctx, req)
}

func (s *VideoService) DeleteVideo(ctx context.Context, req *videoV1.DeleteVideoRequest) (*emptypb.Empty, error) {
	return s.videoServiceClient.DeleteVideo(ctx, req)
}

func (s *VideoService) ListTag(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListTagResponse, error) {
	return s.videoServiceClient.ListTag(ctx, req)
}

// ── InteractionService 点赞 / 收藏 / 关注 ──

type InteractionService struct {
	appV1.InteractionServiceHTTPServer

	interactionServiceClient interactionV1.InteractionServiceClient
	videoServiceClient       videoV1.VideoServiceClient
	log                      *log.Helper
}

func NewInteractionService(ctx *bootstrap.Context, ic interactionV1.InteractionServiceClient, vc videoV1.VideoServiceClient) *InteractionService {
	return &InteractionService{
		log:                      ctx.NewLoggerHelper("interaction/service/app-service"),
		interactionServiceClient: ic,
		videoServiceClient:       vc,
	}
}

func (s *InteractionService) Like(ctx context.Context, req *interactionV1.LikeRequest) (*interactionV1.LikeResponse, error) {
	return s.interactionServiceClient.Like(ctx, req)
}

func (s *InteractionService) Unlike(ctx context.Context, req *interactionV1.LikeRequest) (*interactionV1.LikeResponse, error) {
	return s.interactionServiceClient.Unlike(ctx, req)
}

func (s *InteractionService) Collect(ctx context.Context, req *interactionV1.CollectRequest) (*interactionV1.CollectResponse, error) {
	return s.interactionServiceClient.Collect(ctx, req)
}

func (s *InteractionService) Uncollect(ctx context.Context, req *interactionV1.CollectRequest) (*interactionV1.CollectResponse, error) {
	return s.interactionServiceClient.Uncollect(ctx, req)
}

func (s *InteractionService) GetInteractionStatus(ctx context.Context, req *interactionV1.GetInteractionStatusRequest) (*interactionV1.GetInteractionStatusResponse, error) {
	return s.interactionServiceClient.GetInteractionStatus(ctx, req)
}

func (s *InteractionService) ListCollectedVideos(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListVideoResponse, error) {
	return s.interactionServiceClient.ListCollectedVideos(ctx, req)
}

func (s *InteractionService) Follow(ctx context.Context, req *interactionV1.FollowRequest) (*interactionV1.FollowResponse, error) {
	return s.interactionServiceClient.Follow(ctx, req)
}

func (s *InteractionService) Unfollow(ctx context.Context, req *interactionV1.FollowRequest) (*interactionV1.FollowResponse, error) {
	return s.interactionServiceClient.Unfollow(ctx, req)
}

func (s *InteractionService) ListFollowing(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListFollowResponse, error) {
	return s.interactionServiceClient.ListFollowing(ctx, req)
}

func (s *InteractionService) ListFollowers(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListFollowResponse, error) {
	return s.interactionServiceClient.ListFollowers(ctx, req)
}

// ── CommentService 评论 ──

type CommentService struct {
	appV1.CommentServiceHTTPServer

	commentServiceClient interactionV1.CommentServiceClient
	log                  *log.Helper
}

func NewCommentService(ctx *bootstrap.Context, c interactionV1.CommentServiceClient) *CommentService {
	return &CommentService{
		log:                  ctx.NewLoggerHelper("comment/service/app-service"),
		commentServiceClient: c,
	}
}

func (s *CommentService) CreateComment(ctx context.Context, req *interactionV1.CreateCommentRequest) (*interactionV1.Comment, error) {
	return s.commentServiceClient.CreateComment(ctx, req)
}

func (s *CommentService) DeleteComment(ctx context.Context, req *interactionV1.DeleteCommentRequest) (*emptypb.Empty, error) {
	return s.commentServiceClient.DeleteComment(ctx, req)
}

func (s *CommentService) ListComment(ctx context.Context, req *interactionV1.ListCommentRequest) (*interactionV1.ListCommentResponse, error) {
	return s.commentServiceClient.ListComment(ctx, req)
}

// ListReply 评论的回复列表（楼中楼）
func (s *CommentService) ListReply(ctx context.Context, req *interactionV1.ListReplyRequest) (*interactionV1.ListCommentResponse, error) {
	return s.commentServiceClient.ListReply(ctx, req)
}

// ── NotifyService 通知 ──

type NotifyService struct {
	appV1.NotifyServiceHTTPServer

	notifyServiceClient notifyV1.NotifyServiceClient
	log                 *log.Helper
}

func NewNotifyService(ctx *bootstrap.Context, c notifyV1.NotifyServiceClient) *NotifyService {
	return &NotifyService{
		log:                 ctx.NewLoggerHelper("notify/service/app-service"),
		notifyServiceClient: c,
	}
}

func (s *NotifyService) ListNotification(ctx context.Context, req *notifyV1.ListNotificationRequest) (*notifyV1.ListNotificationResponse, error) {
	return s.notifyServiceClient.ListNotification(ctx, req)
}

func (s *NotifyService) MarkRead(ctx context.Context, req *notifyV1.MarkReadRequest) (*emptypb.Empty, error) {
	return s.notifyServiceClient.MarkRead(ctx, req)
}

func (s *NotifyService) MarkAllRead(ctx context.Context, req *emptypb.Empty) (*emptypb.Empty, error) {
	return s.notifyServiceClient.MarkAllRead(ctx, req)
}

func (s *NotifyService) GetUnreadCount(ctx context.Context, req *emptypb.Empty) (*notifyV1.GetUnreadCountResponse, error) {
	return s.notifyServiceClient.GetUnreadCount(ctx, req)
}

// ── ReportService 举报 ──

type ReportService struct {
	appV1.ReportServiceHTTPServer

	reportServiceClient reportV1.ReportServiceClient
	log                 *log.Helper
}

func NewAppReportService(ctx *bootstrap.Context, c reportV1.ReportServiceClient) *ReportService {
	return &ReportService{
		log:                 ctx.NewLoggerHelper("report/service/app-service"),
		reportServiceClient: c,
	}
}

func (s *ReportService) CreateReport(ctx context.Context, req *reportV1.CreateReportRequest) (*reportV1.Report, error) {
	return s.reportServiceClient.CreateReport(ctx, req)
}

// ── UbaService 埋点 ──

type UbaService struct {
	appV1.UbaServiceHTTPServer

	ubaServiceClient ubaV1.UbaServiceClient
	log              *log.Helper
}

func NewUbaService(ctx *bootstrap.Context, c ubaV1.UbaServiceClient) *UbaService {
	return &UbaService{
		log:              ctx.NewLoggerHelper("uba/service/app-service"),
		ubaServiceClient: c,
	}
}

func (s *UbaService) ReportEvents(ctx context.Context, req *ubaV1.ReportEventsRequest) (*emptypb.Empty, error) {
	return s.ubaServiceClient.ReportEvents(ctx, req)
}

func ptrU32(v uint32) *uint32 { return &v }
