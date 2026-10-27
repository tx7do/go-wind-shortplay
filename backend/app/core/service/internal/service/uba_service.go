package service

import (
	"context"
	"fmt"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/redis/go-redis/v9"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/go-utils/timeutil"
	"google.golang.org/protobuf/types/known/emptypb"

	"go-wind-shortplay/app/core/service/internal/data"

	ubaV1 "go-wind-shortplay/api/gen/go/uba/service/v1"
)

// 上报批量上限（防刷）
const ubaMaxBatchSize = 100

type UbaService struct {
	ubaV1.UnimplementedUbaServiceServer

	log *log.Helper

	ubaRepo   *data.UbaRepo
	videoRepo *data.VideoRepo
	redis     *redis.Client
}

func NewUbaService(ctx *bootstrap.Context, ubaRepo *data.UbaRepo, videoRepo *data.VideoRepo, rdb *redis.Client) *UbaService {
	return &UbaService{
		log:       ctx.NewLoggerHelper("uba/service/core-service"),
		ubaRepo:   ubaRepo,
		videoRepo: videoRepo,
		redis:     rdb,
	}
}

// markDisliked 「不感兴趣」负反馈写入 Redis set（feed 召回过滤读；尽力而为）
func (s *UbaService) markDisliked(ctx context.Context, uid uint32, videoIDs []uint32) {
	if s.redis == nil || uid == 0 || len(videoIDs) == 0 {
		return
	}
	key := fmt.Sprintf("%s%d", feedDislikeKeyPrefix, uid)
	members := make([]interface{}, 0, len(videoIDs))
	for _, id := range videoIDs {
		members = append(members, fmt.Sprintf("%d", id))
	}
	pipe := s.redis.Pipeline()
	pipe.SAdd(ctx, key, members...)
	pipe.Expire(ctx, key, feedDislikeTTL)
	if _, err := pipe.Exec(ctx); err != nil {
		s.log.Warnf("mark disliked failed: %s", err.Error())
	}
}

// ReportEvents 批量上报行为事件（尽力而为：单条失败不阻塞，游客可上报）。
func (s *UbaService) ReportEvents(ctx context.Context, req *ubaV1.ReportEventsRequest) (*emptypb.Empty, error) {
	if req == nil || len(req.GetEvents()) == 0 {
		return &emptypb.Empty{}, nil
	}
	events := req.GetEvents()
	if len(events) > ubaMaxBatchSize {
		events = events[:ubaMaxBatchSize]
	}
	uid := spViewerUserID(ctx)
	saved, err := s.ubaRepo.CreateBatch(ctx, uid, events)
	if err != nil {
		// 尽力而为：落库失败也不阻塞播放链路
		s.log.Errorf("report uba events failed: %s", err.Error())
	}
	// 不感兴趣负反馈同步进 Redis 过滤集（登录用户）
	if uid > 0 {
		dislikedIDs := make([]uint32, 0, len(events))
		for _, ev := range events {
			if ev.GetEventType() == ubaV1.EventType_EVENT_TYPE_VIDEO_DISLIKE && ev.GetVideoId() > 0 {
				dislikedIDs = append(dislikedIDs, ev.GetVideoId())
			}
		}
		s.markDisliked(ctx, uid, dislikedIDs)
	}
	s.log.Debugf("uba events saved %d/%d (uid=%d)", saved, len(events), uid)
	return &emptypb.Empty{}, nil
}

// ListWatchHistory 观看历史（本人，最近观看倒序；派生自播放事件聚合）。
func (s *UbaService) ListWatchHistory(ctx context.Context, req *ubaV1.ListWatchHistoryRequest) (*ubaV1.WatchHistoryResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, ubaV1.ErrorUnauthorized("login required")
	}
	page := uint32(1)
	size := uint32(20)
	if req != nil {
		if req.GetPageNum() > 0 {
			page = req.GetPageNum()
		}
		if req.GetPageSize() > 0 {
			size = req.GetPageSize()
		}
	}
	if size > 50 {
		size = 50
	}
	rows, total, err := s.ubaRepo.ListWatchHistoryPage(ctx, uid, int(page-1)*int(size), int(size))
	if err != nil {
		return nil, ubaV1.ErrorInternalServerError("list watch history failed")
	}
	// 断点续播位置（尽力而为）：每视频取最近心跳上报的播放位置
	positions := s.ubaRepo.HeartbeatPositions(ctx, uid)
	resp := &ubaV1.WatchHistoryResponse{Total: trans.Ptr(int64(total))}
	for _, row := range rows {
		e, verr := s.videoRepo.GetEntityRaw(ctx, row.VideoID)
		if verr != nil {
			continue // 视频已删的历史条目跳过
		}
		vd, derr := s.videoRepo.ToDTO(ctx, e)
		if derr != nil {
			continue
		}
		item := &ubaV1.WatchHistoryItem{
			Video:     vd,
			WatchedAt: timeutil.TimeToTimestamppb(&row.WatchedAt),
		}
		if pos := positions[row.VideoID]; pos > 0 {
			item.ProgressSeconds = trans.Ptr(uint32(pos / 1000))
		}
		resp.Items = append(resp.Items, item)
	}
	return resp, nil
}
