package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	appV1 "go-wind-shortplay/api/gen/go/app/service/v1"
	seriesV1 "go-wind-shortplay/api/gen/go/series/service/v1"
)

// SeriesService 剧集服务（app BFF 薄转发；详情/列表为游客白名单，归属与可见性在 core 把关）。
type SeriesService struct {
	appV1.SeriesServiceHTTPServer

	seriesClient seriesV1.SeriesServiceClient
	log          *log.Helper
}

func NewSeriesService(
	ctx *bootstrap.Context,
	seriesClient seriesV1.SeriesServiceClient,
) *SeriesService {
	return &SeriesService{
		log:          ctx.NewLoggerHelper("series/service/app-service"),
		seriesClient: seriesClient,
	}
}

func (s *SeriesService) CreateSeries(ctx context.Context, req *seriesV1.CreateSeriesRequest) (*seriesV1.Series, error) {
	return s.seriesClient.CreateSeries(ctx, req)
}

func (s *SeriesService) GetSeries(ctx context.Context, req *seriesV1.GetSeriesRequest) (*seriesV1.SeriesDetail, error) {
	return s.seriesClient.GetSeries(ctx, req)
}

func (s *SeriesService) UpdateSeries(ctx context.Context, req *seriesV1.UpdateSeriesRequest) (*seriesV1.Series, error) {
	return s.seriesClient.UpdateSeries(ctx, req)
}

func (s *SeriesService) DeleteSeries(ctx context.Context, req *seriesV1.DeleteSeriesRequest) (*emptypb.Empty, error) {
	return s.seriesClient.DeleteSeries(ctx, req)
}

func (s *SeriesService) ListSeries(ctx context.Context, req *seriesV1.QuerySeriesRequest) (*seriesV1.ListSeriesResponse, error) {
	return s.seriesClient.QuerySeries(ctx, req)
}

func (s *SeriesService) FollowSeries(ctx context.Context, req *seriesV1.FollowSeriesRequest) (*seriesV1.FollowSeriesResponse, error) {
	return s.seriesClient.FollowSeries(ctx, req)
}

func (s *SeriesService) UnfollowSeries(ctx context.Context, req *seriesV1.FollowSeriesRequest) (*seriesV1.FollowSeriesResponse, error) {
	return s.seriesClient.UnfollowSeries(ctx, req)
}

func (s *SeriesService) ListFollowedSeries(ctx context.Context, req *paginationV1.PagingRequest) (*seriesV1.ListSeriesResponse, error) {
	return s.seriesClient.ListFollowedSeries(ctx, req)
}
