package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	"go-wind-shortplay/app/core/service/internal/data"

	ubaV1 "go-wind-shortplay/api/gen/go/uba/service/v1"
)

// 上报批量上限（防刷）
const ubaMaxBatchSize = 100

type UbaService struct {
	ubaV1.UnimplementedUbaServiceServer

	log *log.Helper

	ubaRepo *data.UbaRepo
}

func NewUbaService(ctx *bootstrap.Context, ubaRepo *data.UbaRepo) *UbaService {
	return &UbaService{
		log:     ctx.NewLoggerHelper("uba/service/core-service"),
		ubaRepo: ubaRepo,
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
