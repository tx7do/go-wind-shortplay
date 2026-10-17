package service

import (
	"context"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	statsV1 "go-wind-shortplay/api/gen/go/stats/service/v1"
	sysconfV1 "go-wind-shortplay/api/gen/go/sysconf/service/v1"
	ubaV1 "go-wind-shortplay/api/gen/go/uba/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/pkg/authctx"
)

// SysConfService 系统配置
type SysConfService struct {
	sysconfV1.UnimplementedSysConfServiceServer

	sysConfigRepo *data.SysConfigRepo
	log           *log.Helper
}

func NewSysConfService(ctx *bootstrap.Context, sysConfigRepo *data.SysConfigRepo) *SysConfService {
	return &SysConfService{
		sysConfigRepo: sysConfigRepo,
		log:           ctx.NewLoggerHelper("sysconf/service/core-service"),
	}
}

func (s *SysConfService) GetSysConf(ctx context.Context, _ *emptypb.Empty) (*sysconfV1.SysConf, error) {
	cfg, err := s.sysConfigRepo.Get(ctx)
	if err != nil {
		return nil, sysconfV1.ErrorInternalServerError("load sysconf failed")
	}
	return toSysConf(cfg), nil
}

func (s *SysConfService) UpdateSysConf(ctx context.Context, req *sysconfV1.UpdateSysConfRequest) (*sysconfV1.SysConf, error) {
	cfg, err := s.sysConfigRepo.Update(ctx,
		req.MaxUploadSizeMb,
		req.MaxDurationSeconds,
		req.ManualReviewEnabled,
		req.RegisterEnabled,
		req.AllowedVideoTypes,
	)
	if err != nil {
		return nil, sysconfV1.ErrorInternalServerError("update sysconf failed")
	}
	return toSysConf(cfg), nil
}

// ── UbaService 行为埋点 ──

type UbaService struct {
	ubaV1.UnimplementedUbaServiceServer

	ubaRepo  *data.UbaRepo
	feedSvc  *FeedService
	videoRepo *data.VideoRepo
	log      *log.Helper
}

func NewUbaService(ctx *bootstrap.Context, ubaRepo *data.UbaRepo, feedSvc *FeedService, videoRepo *data.VideoRepo) *UbaService {
	return &UbaService{
		ubaRepo:   ubaRepo,
		feedSvc:   feedSvc,
		videoRepo: videoRepo,
		log:       ctx.NewLoggerHelper("uba/service/core-service"),
	}
}

// ReportEvents 批量落事件；播放事件顺带维护已看集合与播放量
func (s *UbaService) ReportEvents(ctx context.Context, req *ubaV1.ReportEventsRequest) (*emptypb.Empty, error) {
	uid := authctx.UserIDFromContext(ctx) // 游客为 0
	now := time.Now()

	rows := make([]data.UbaEventRow, 0, len(req.GetEvents()))
	for _, e := range req.GetEvents() {
		row := data.UbaEventRow{
			EventType:    uint8(e.GetEventType()),
			VideoID:      e.GetVideoId(),
			UserID:       uid,
			TargetUserID: e.GetTargetUserId(),
			DurationMs:   int64(e.GetDurationMs()),
			WatchPercent: e.GetWatchPercent(),
			Extra:        e.Extra,
			OccurredAt:   now,
		}
		if e.OccurredAt != nil {
			row.OccurredAt = e.OccurredAt.AsTime()
		}
		rows = append(rows, row)

		// 播放事件：记入已看集合（Feed 去重）
		if e.GetEventType() == ubaV1.EventType_EVENT_TYPE_VIDEO_PLAY {
			if s.feedSvc != nil {
				s.feedSvc.RecordSeen(ctx, uid, e.GetVideoId())
			}
		}
		// 完播事件：播放量 +1（观看口径；详情页 PV 另计）
		if e.GetEventType() == ubaV1.EventType_EVENT_TYPE_VIDEO_COMPLETE && e.GetVideoId() > 0 {
			_ = s.videoRepo.IncViewCount(ctx, e.GetVideoId())
		}
	}

	// 尽力而为：落库失败不影响播放链路
	_ = s.ubaRepo.InsertBatch(ctx, rows)
	return &emptypb.Empty{}, nil
}

// ── DashboardService 数据看板 ──

type DashboardService struct {
	statsV1.UnimplementedDashboardServiceServer

	statsRepo *data.StatsRepo
	videoRepo *data.VideoRepo
	interRepo *data.InteractionRepo
	log       *log.Helper
}

func NewDashboardService(ctx *bootstrap.Context, statsRepo *data.StatsRepo, videoRepo *data.VideoRepo, interRepo *data.InteractionRepo) *DashboardService {
	return &DashboardService{
		statsRepo: statsRepo,
		videoRepo: videoRepo,
		interRepo: interRepo,
		log:       ctx.NewLoggerHelper("stats/service/core-service"),
	}
}

func (s *DashboardService) GetOverview(ctx context.Context, _ *statsV1.GetOverviewRequest) (*statsV1.Overview, error) {
	o, err := s.statsRepo.GetOverview(ctx)
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("query overview failed")
	}
	return &statsV1.Overview{
		TotalVideos:      ptr(uint64(o.TotalVideos)),
		PublishedVideos:  ptr(uint64(o.PublishedVideos)),
		TotalViews:       ptr(uint64(o.TotalViews)),
		TotalLikes:       ptr(uint64(o.TotalLikes)),
		TotalComments:    ptr(uint64(o.TotalComments)),
		TotalUsers:       ptr(uint64(o.TotalUsers)),
		TodayPublished:   ptr(uint64(o.TodayPublished)),
	}, nil
}

// GetCreatorOverview 创作者中心总览（viewer 本人）
func (s *DashboardService) GetCreatorOverview(ctx context.Context, _ *statsV1.GetCreatorOverviewRequest) (*statsV1.CreatorOverview, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, statsV1.ErrorUnauthorized("login required")
	}
	o, err := s.statsRepo.GetCreatorOverview(ctx, uid)
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("query creator overview failed")
	}
	out := &statsV1.CreatorOverview{
		VideoCount:    ptr(uint64(o.VideoCount)),
		TotalViews:    ptr(uint64(o.TotalViews)),
		TotalLikes:    ptr(uint64(o.TotalLikes)),
		TotalCollects: ptr(uint64(o.TotalCollects)),
		TotalComments: ptr(uint64(o.TotalComments)),
	}
	if s.interRepo != nil {
		_, followers, ferr := s.interRepo.FollowCounts(ctx, uid)
		if ferr == nil {
			out.FollowerCount = ptr(uint64(followers))
		}
	}
	return out, nil
}

func (s *DashboardService) ListTopVideos(ctx context.Context, req *statsV1.ListTopVideosRequest) (*videoV1.ListVideoResponse, error) {
	orderBy := "view_count"
	switch req.GetMetric() {
	case statsV1.ListTopVideosRequest_METRIC_LIKE:
		orderBy = "like_count"
	case statsV1.ListTopVideosRequest_METRIC_COLLECT:
		orderBy = "collect_count"
	case statsV1.ListTopVideosRequest_METRIC_COMMENT:
		orderBy = "comment_count"
	}
	limit := int(req.GetLimit())
	if limit < 1 {
		limit = 10
	}
	items, _, err := s.videoRepo.List(ctx, 0, limit, ptr(uint8(3)), nil, "", orderBy)
	if err != nil {
		return nil, statsV1.ErrorInternalServerError("query top videos failed")
	}
	out := make([]*videoV1.Video, 0, len(items))
	for _, it := range items {
		out = append(out, toVideo(it, nil))
	}
	return &videoV1.ListVideoResponse{Items: out}, nil
}

func toSysConf(cfg *ent.SysConfig) *sysconfV1.SysConf {
	return &sysconfV1.SysConf{
		MaxUploadSizeMb:      cfg.MaxUploadSizeMB,
		MaxDurationSeconds:   cfg.MaxDurationSeconds,
		ManualReviewEnabled:  cfg.ManualReviewEnabled,
		RegisterEnabled:      cfg.RegisterEnabled,
		AllowedVideoTypes:    cfg.AllowedVideoTypes,
		UpdatedAt:            tsPtr(cfg.UpdatedAt),
	}
}

