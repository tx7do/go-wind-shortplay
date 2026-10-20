package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
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

	ubaRepo  *data.UbaRepo
	videoRepo *data.VideoRepo
}

func NewUbaService(ctx *bootstrap.Context, ubaRepo *data.UbaRepo, videoRepo *data.VideoRepo) *UbaService {
	return &UbaService{
		log:      ctx.NewLoggerHelper("uba/service/core-service"),
		ubaRepo:  ubaRepo,
		videoRepo: videoRepo,
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
		resp.Items = append(resp.Items, &ubaV1.WatchHistoryItem{
			Video:     vd,
			WatchedAt: timeutil.TimeToTimestamppb(&row.WatchedAt),
		})
	}
	return resp, nil
}
