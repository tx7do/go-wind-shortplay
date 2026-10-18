package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"

	"go-wind-shortplay/app/core/service/internal/data"

	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	statsV1 "go-wind-shortplay/api/gen/go/stats/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
)

type DashboardService struct {
	statsV1.UnimplementedDashboardServiceServer

	log *log.Helper

	statsRepo *data.StatsRepo
	videoRepo *data.VideoRepo
	interRepo *data.InteractionRepo
	userRepo  data.UserRepo
}

func NewDashboardService(
	ctx *bootstrap.Context,
	statsRepo *data.StatsRepo,
	videoRepo *data.VideoRepo,
	interRepo *data.InteractionRepo,
	userRepo data.UserRepo,
) *DashboardService {
	return &DashboardService{
		log:       ctx.NewLoggerHelper("stats/service/core-service"),
		statsRepo: statsRepo,
		videoRepo: videoRepo,
		interRepo: interRepo,
		userRepo:  userRepo,
	}
}

// GetOverview 运营总览。
func (s *DashboardService) GetOverview(ctx context.Context, req *statsV1.GetOverviewRequest) (*statsV1.Overview, error) {
	totalUsers, err := s.statsRepo.TotalUsers(ctx)
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("count users failed")
	}
	row, err := s.statsRepo.Overview(ctx, totalUsers)
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("overview aggregate failed")
	}
	return row.ToProto(totalUsers), nil
}

// ListTrends 近 N 日趋势。
func (s *DashboardService) ListTrends(ctx context.Context, req *statsV1.ListTrendsRequest) (*statsV1.ListTrendsResponse, error) {
	rows, err := s.statsRepo.TrendRows(ctx, int(req.GetDays()))
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("trends aggregate failed")
	}
	resp := &statsV1.ListTrendsResponse{}
	for _, row := range rows {
		resp.Items = append(resp.Items, &statsV1.TrendItem{
			Date:      trans.Ptr(row.Day),
			Published: trans.Ptr(row.Published),
			Plays:     trans.Ptr(row.Plays),
			Likes:     trans.Ptr(row.Likes),
		})
	}
	return resp, nil
}

// ListTopVideos 视频 TOP 排行。
func (s *DashboardService) ListTopVideos(ctx context.Context, req *statsV1.ListTopVideosRequest) (*videoV1.ListVideoResponse, error) {
	metric := data.TopMetricView
	switch req.GetMetric() {
	case statsV1.ListTopVideosRequest_METRIC_LIKE:
		metric = data.TopMetricLike
	case statsV1.ListTopVideosRequest_METRIC_COLLECT:
		metric = data.TopMetricCollect
	case statsV1.ListTopVideosRequest_METRIC_COMMENT:
		metric = data.TopMetricComment
	}
	limit := int(req.GetLimit())
	if limit <= 0 {
		limit = 10
	}
	if limit > 50 {
		limit = 50
	}
	videos, err := s.videoRepo.ListTopByMetric(ctx, metric, limit)
	if err != nil {
		return nil, err
	}
	resp := &videoV1.ListVideoResponse{Total: trans.Ptr(int64(len(videos)))}
	for _, v := range videos {
		tags, _ := s.videoRepo.TagsOfVideo(ctx, v.ID)
		resp.Items = append(resp.Items, spVideoToDTO(v, tags))
	}
	return resp, nil
}

// GetCreatorOverview 创作者中心总览（viewer 本人）。
func (s *DashboardService) GetCreatorOverview(ctx context.Context, req *statsV1.GetCreatorOverviewRequest) (*statsV1.CreatorOverview, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, statsV1.ErrorUnauthorized("login required")
	}
	agg, err := s.statsRepo.AuthorAggregates(ctx, uid, true)
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("creator aggregate failed")
	}
	followers, err := s.statsRepo.FollowerCount(ctx, uid)
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("follower count failed")
	}
	return &statsV1.CreatorOverview{
		VideoCount:    trans.Ptr(agg.Cnt),
		TotalViews:    trans.Ptr(agg.Views),
		TotalLikes:    trans.Ptr(agg.Likes),
		TotalCollects: trans.Ptr(agg.Collects),
		TotalComments: trans.Ptr(agg.Comments),
		FollowerCount: trans.Ptr(followers),
	}, nil
}

// GetUserStats 用户统计（用户主页；游客可读）。
func (s *DashboardService) GetUserStats(ctx context.Context, req *identityV1.GetUserStatsRequest) (*identityV1.UserStats, error) {
	uid := req.GetUserId()
	if uid == 0 {
		return nil, statsV1.ErrorBadRequest("invalid parameter")
	}
	agg, err := s.statsRepo.AuthorAggregates(ctx, uid, true)
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("author aggregate failed")
	}
	followers, err := s.statsRepo.FollowerCount(ctx, uid)
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("follower count failed")
	}
	following, err := s.statsRepo.FollowingCount(ctx, uid)
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("following count failed")
	}
	likeReceived, err := s.statsRepo.AuthorAggregates(ctx, uid, false)
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("like received failed")
	}
	return &identityV1.UserStats{
		UserId:           trans.Ptr(uid),
		VideoCount:       trans.Ptr(agg.Cnt),
		FollowerCount:    trans.Ptr(followers),
		FollowingCount:   trans.Ptr(following),
		LikeReceivedCount: trans.Ptr(likeReceived.Likes),
	}, nil
}

// ListCreatorVideos 占位保持 pagination 引用（用户作品列表由 video 域提供）
var _ = paginationV1.PagingRequest{}
