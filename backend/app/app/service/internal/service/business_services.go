package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/fieldmaskpb"

	appV1 "go-wind-shortplay/api/gen/go/app/service/v1"
	feedV1 "go-wind-shortplay/api/gen/go/feed/service/v1"
	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	reportV1 "go-wind-shortplay/api/gen/go/report/service/v1"
	statsV1 "go-wind-shortplay/api/gen/go/stats/service/v1"
	ubaV1 "go-wind-shortplay/api/gen/go/uba/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"

	authnEngine "github.com/tx7do/kratos-authn/engine"

	authenticationV1 "go-wind-shortplay/api/gen/go/authentication/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"

	spmetadata "go-wind-shortplay/pkg/metadata"
	"go-wind-shortplay/pkg/middleware/auth"
)

// authOperatorSP 取当前登录操作者（app BFF 面未登录报 401）
func authOperatorSP(ctx context.Context) (*authenticationV1.UserTokenPayload, error) {
	op, err := auth.FromContext(ctx)
	if err != nil || op == nil || op.GetUserId() == 0 {
		return nil, appV1.ErrorUnauthorized("login required")
	}
	return op, nil
}

func trans_U32(v uint32) *uint32 { return &v }

func trans_Str(v string) *string { return &v }

// ── Feed 流（app BFF 薄转发，游客白名单面）──

type FeedService struct {
	appV1.FeedServiceHTTPServer

	feedClient feedV1.FeedServiceClient
	log        *log.Helper
}

func NewFeedService(ctx *bootstrap.Context, feedClient feedV1.FeedServiceClient) *FeedService {
	return &FeedService{
		log:        ctx.NewLoggerHelper("feed/service/app-service"),
		feedClient: feedClient,
	}
}

func (s *FeedService) GetFeed(ctx context.Context, req *feedV1.GetFeedRequest) (*feedV1.GetFeedResponse, error) {
	return s.feedClient.GetFeed(ctx, req)
}

func (s *FeedService) GetVideoDetail(ctx context.Context, req *feedV1.GetVideoDetailRequest) (*feedV1.VideoDetail, error) {
	return s.feedClient.GetVideoDetail(ctx, req)
}

func (s *FeedService) SearchVideos(ctx context.Context, req *feedV1.SearchVideosRequest) (*feedV1.GetFeedResponse, error) {
	return s.feedClient.SearchVideos(ctx, req)
}

func (s *FeedService) ListVideosByTag(ctx context.Context, req *feedV1.ListVideosByTagRequest) (*feedV1.GetFeedResponse, error) {
	return s.feedClient.ListVideosByTag(ctx, req)
}

// ── 互动（app BFF 薄转发）──

type InteractionService struct {
	appV1.InteractionServiceHTTPServer

	interactionClient  interactionV1.InteractionServiceClient
	accessTokenChecker auth.AccessTokenChecker
	log                *log.Helper
}

func NewInteractionService(ctx *bootstrap.Context, interactionClient interactionV1.InteractionServiceClient, accessTokenChecker auth.AccessTokenChecker) *InteractionService {
	return &InteractionService{
		log:                ctx.NewLoggerHelper("interaction/service/app-service"),
		interactionClient:  interactionClient,
		accessTokenChecker: accessTokenChecker,
	}
}

func (s *InteractionService) Like(ctx context.Context, req *interactionV1.LikeRequest) (*interactionV1.LikeResponse, error) {
	return s.interactionClient.Like(ctx, req)
}

func (s *InteractionService) Unlike(ctx context.Context, req *interactionV1.LikeRequest) (*interactionV1.LikeResponse, error) {
	return s.interactionClient.Unlike(ctx, req)
}

func (s *InteractionService) Collect(ctx context.Context, req *interactionV1.CollectRequest) (*interactionV1.CollectResponse, error) {
	return s.interactionClient.Collect(ctx, req)
}

func (s *InteractionService) Uncollect(ctx context.Context, req *interactionV1.CollectRequest) (*interactionV1.CollectResponse, error) {
	return s.interactionClient.Uncollect(ctx, req)
}

// GetInteractionStatus 批量互动状态：游客白名单端点 + 可选认证——携带有效
// token 时注入 operator 元数据，让 core 按 viewer 返回真实按钮态（与基座
// 游客评论 Create 的可选认证同口径）。
func (s *InteractionService) GetInteractionStatus(ctx context.Context, req *interactionV1.GetInteractionStatusRequest) (*interactionV1.GetInteractionStatusResponse, error) {
	if uid := s.optionalUserID(ctx); uid > 0 {
		if md, err := spmetadata.NewContext(ctx, spmetadata.NewUserOperator(uint64(uid), 0, 0, identityV1.DataScope_ALL)); err == nil {
			ctx = md
		}
	}
	return s.interactionClient.GetInteractionStatus(ctx, req)
}

// optionalUserID 可选认证：带有效 bearer 返回 uid，否则 0。
func (s *InteractionService) optionalUserID(ctx context.Context) uint32 {
	token, err := authnEngine.AuthFromMD(ctx, authnEngine.BearerWord, authnEngine.ContextTypeKratosMetaData)
	if err != nil || s.accessTokenChecker == nil {
		return 0
	}
	valid, payload := s.accessTokenChecker.IsValidAccessToken(ctx, token, false)
	if !valid || payload == nil {
		return 0
	}
	return payload.GetUserId()
}

func (s *InteractionService) ListCollectedVideos(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListVideoResponse, error) {
	return s.interactionClient.ListCollectedVideos(ctx, req)
}

func (s *InteractionService) Follow(ctx context.Context, req *interactionV1.FollowRequest) (*interactionV1.FollowResponse, error) {
	return s.interactionClient.Follow(ctx, req)
}

func (s *InteractionService) Unfollow(ctx context.Context, req *interactionV1.FollowRequest) (*interactionV1.FollowResponse, error) {
	return s.interactionClient.Unfollow(ctx, req)
}

func (s *InteractionService) GetFollowStatus(ctx context.Context, req *interactionV1.GetFollowStatusRequest) (*interactionV1.GetFollowStatusResponse, error) {
	return s.interactionClient.GetFollowStatus(ctx, req)
}

func (s *InteractionService) ListFollowing(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListFollowResponse, error) {
	return s.interactionClient.ListFollowing(ctx, req)
}

func (s *InteractionService) ListFollowers(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListFollowResponse, error) {
	return s.interactionClient.ListFollowers(ctx, req)
}

// ── 视频评论（app BFF 薄转发）──

type CommentService struct {
	appV1.CommentServiceHTTPServer

	commentClient interactionV1.CommentServiceClient
	log           *log.Helper
}

func NewCommentService(ctx *bootstrap.Context, commentClient interactionV1.CommentServiceClient) *CommentService {
	return &CommentService{
		log:           ctx.NewLoggerHelper("video-comment/service/app-service"),
		commentClient: commentClient,
	}
}

func (s *CommentService) CreateComment(ctx context.Context, req *interactionV1.CreateCommentRequest) (*interactionV1.Comment, error) {
	return s.commentClient.CreateComment(ctx, req)
}

func (s *CommentService) DeleteComment(ctx context.Context, req *interactionV1.DeleteCommentRequest) (*emptypb.Empty, error) {
	return s.commentClient.DeleteComment(ctx, req)
}

func (s *CommentService) ListComment(ctx context.Context, req *interactionV1.ListCommentRequest) (*interactionV1.ListCommentResponse, error) {
	return s.commentClient.ListComment(ctx, req)
}

func (s *CommentService) ListReply(ctx context.Context, req *interactionV1.ListReplyRequest) (*interactionV1.ListCommentResponse, error) {
	return s.commentClient.ListReply(ctx, req)
}

// ── 举报 / 埋点（app BFF 薄转发）──

type ReportService struct {
	appV1.ReportServiceHTTPServer

	reportClient reportV1.ReportServiceClient
	log          *log.Helper
}

func NewReportService(ctx *bootstrap.Context, reportClient reportV1.ReportServiceClient) *ReportService {
	return &ReportService{
		log:          ctx.NewLoggerHelper("report/service/app-service"),
		reportClient: reportClient,
	}
}

func (s *ReportService) CreateReport(ctx context.Context, req *reportV1.CreateReportRequest) (*reportV1.Report, error) {
	return s.reportClient.CreateReport(ctx, req)
}

type UbaService struct {
	appV1.UbaServiceHTTPServer

	ubaClient ubaV1.UbaServiceClient
	log       *log.Helper
}

func NewUbaService(ctx *bootstrap.Context, ubaClient ubaV1.UbaServiceClient) *UbaService {
	return &UbaService{
		log:       ctx.NewLoggerHelper("uba/service/app-service"),
		ubaClient: ubaClient,
	}
}

func (s *UbaService) ReportEvents(ctx context.Context, req *ubaV1.ReportEventsRequest) (*emptypb.Empty, error) {
	return s.ubaClient.ReportEvents(ctx, req)
}

// ── 创作发布（app BFF 薄转发；分片字节路由手工挂载见 rest_server）──

type VideoService struct {
	appV1.VideoServiceHTTPServer

	videoClient     videoV1.VideoServiceClient
	dashboardClient statsV1.DashboardServiceClient
	log             *log.Helper
}

func NewVideoService(ctx *bootstrap.Context, videoClient videoV1.VideoServiceClient, dashboardClient statsV1.DashboardServiceClient) *VideoService {
	return &VideoService{
		log:             ctx.NewLoggerHelper("video/service/app-service"),
		videoClient:     videoClient,
		dashboardClient: dashboardClient,
	}
}

func (s *VideoService) CreateUploadTask(ctx context.Context, req *videoV1.CreateUploadTaskRequest) (*videoV1.UploadTask, error) {
	return s.videoClient.CreateUploadTask(ctx, req)
}

// UploadChunk 分片上传：原始字节路由手工挂载（raw body），此方法供手挂路由调用。
// app 面请求类型为 app.service.v1.UploadChunkRequest（生成路由 body:"data" 契约），
// 这里转成核心域请求转发。
func (s *VideoService) UploadChunk(ctx context.Context, req *appV1.UploadChunkRequest) (*videoV1.UploadChunkResponse, error) {
	return s.videoClient.UploadChunk(ctx, &videoV1.UploadChunkRequest{
		TaskId:     req.GetTaskId(),
		ChunkIndex: req.GetChunkIndex(),
		Data:       req.GetData(),
	})
}

func (s *VideoService) CompleteUpload(ctx context.Context, req *videoV1.CompleteUploadRequest) (*videoV1.UploadTask, error) {
	return s.videoClient.CompleteUpload(ctx, req)
}

func (s *VideoService) GetUploadTask(ctx context.Context, req *videoV1.GetUploadTaskRequest) (*videoV1.UploadTask, error) {
	return s.videoClient.GetUploadTask(ctx, req)
}

func (s *VideoService) SaveDraft(ctx context.Context, req *videoV1.SaveDraftRequest) (*videoV1.VideoDraft, error) {
	return s.videoClient.SaveDraft(ctx, req)
}

func (s *VideoService) ListDraft(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListDraftResponse, error) {
	return s.videoClient.ListDraft(ctx, req)
}

func (s *VideoService) GetDraft(ctx context.Context, req *videoV1.GetDraftRequest) (*videoV1.VideoDraft, error) {
	return s.videoClient.GetDraft(ctx, req)
}

func (s *VideoService) DeleteDraft(ctx context.Context, req *videoV1.DeleteDraftRequest) (*emptypb.Empty, error) {
	return s.videoClient.DeleteDraft(ctx, req)
}

func (s *VideoService) SubmitDraft(ctx context.Context, req *videoV1.SubmitDraftRequest) (*videoV1.Video, error) {
	return s.videoClient.SubmitDraft(ctx, req)
}

func (s *VideoService) UpdateVideo(ctx context.Context, req *videoV1.UpdateVideoRequest) (*videoV1.Video, error) {
	return s.videoClient.UpdateVideo(ctx, req)
}

func (s *VideoService) DeleteVideo(ctx context.Context, req *videoV1.DeleteVideoRequest) (*emptypb.Empty, error) {
	return s.videoClient.DeleteVideo(ctx, req)
}

func (s *VideoService) ListTag(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListTagResponse, error) {
	return s.videoClient.ListTag(ctx, req)
}

func (s *VideoService) GetCreatorOverview(ctx context.Context, req *statsV1.GetCreatorOverviewRequest) (*statsV1.CreatorOverview, error) {
	return s.dashboardClient.GetCreatorOverview(ctx, req)
}

// ── 用户主页（app BFF：资料转发 identity 域，统计转发 stats 域）──

type UserService struct {
	appV1.UserServiceHTTPServer

	userClient      identityV1.UserServiceClient
	dashboardClient statsV1.DashboardServiceClient
	videoClient     videoV1.VideoServiceClient
	log             *log.Helper
}

func NewUserService(
	ctx *bootstrap.Context,
	userClient identityV1.UserServiceClient,
	dashboardClient statsV1.DashboardServiceClient,
	videoClient videoV1.VideoServiceClient,
) *UserService {
	return &UserService{
		log:             ctx.NewLoggerHelper("user/service/app-service"),
		userClient:      userClient,
		dashboardClient: dashboardClient,
		videoClient:     videoClient,
	}
}

// userDetailOf 基座 User → 业务 UserDetail（avatar→avatarUrl、description→bio）
func userDetailOf(u *identityV1.User) *appV1.UserDetail {
	if u == nil {
		return nil
	}
	return &appV1.UserDetail{
		Id:        trans_U32(u.GetId()),
		Username:  trans_Str(u.GetUsername()),
		Nickname:  trans_Str(u.GetNickname()),
		AvatarUrl: trans_Str(u.GetAvatar()),
		Bio:       trans_Str(u.GetDescription()),
		CreatedAt: u.CreatedAt,
	}
}

func (s *UserService) GetUser(ctx context.Context, req *appV1.GetAppUserRequest) (*appV1.UserDetail, error) {
	u, err := s.userClient.Get(ctx, &identityV1.GetUserRequest{
		QueryBy: &identityV1.GetUserRequest_Id{Id: req.GetId()},
	})
	if err != nil {
		return nil, err
	}
	return userDetailOf(u), nil
}

func (s *UserService) GetUserStats(ctx context.Context, req *identityV1.GetUserStatsRequest) (*identityV1.UserStats, error) {
	return s.dashboardClient.GetUserStats(ctx, req)
}

func (s *UserService) UpdateProfile(ctx context.Context, req *appV1.UpdateProfileRequest) (*appV1.UserDetail, error) {
	operator, err := authOperatorSP(ctx)
	if err != nil {
		return nil, err
	}
	if _, err := s.userClient.Update(ctx, &identityV1.UpdateUserRequest{
		Id: operator.UserId,
		Data: &identityV1.User{
			Nickname:    req.Nickname,
			Avatar:      req.AvatarUrl,
			Description: req.Bio,
		},
		// 基座 userRepo.Update 依赖 update_mask 定位写入列，缺省 panic
		UpdateMask: &fieldmaskpb.FieldMask{Paths: []string{"nickname", "avatar", "description"}},
	}); err != nil {
		return nil, err
	}
	return s.GetUser(ctx, &appV1.GetAppUserRequest{Id: operator.UserId})
}

func (s *UserService) ListUserVideos(ctx context.Context, req *appV1.ListUserVideosRequest) (*videoV1.ListVideoResponse, error) {
	return s.videoClient.ListUserVideo(ctx, &videoV1.ListUserVideoRequest{
		UserId:   req.GetUserId(),
		PageNum:  req.PageNum,
		PageSize: req.PageSize,
	})
}
