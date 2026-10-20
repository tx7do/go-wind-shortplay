package service

import (
	"context"
	"encoding/json"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	adminV1 "go-wind-shortplay/api/gen/go/admin/service/v1"
	seriesV1 "go-wind-shortplay/api/gen/go/series/service/v1"
)

// SeriesService 剧集管理服务（admin BFF 薄转发）。
// React 前端的 query（剧名关键字）/authorId 直传，翻译成 go-crud 过滤 JSON 再转发 core。
type SeriesService struct {
	adminV1.SeriesServiceHTTPServer

	seriesClient seriesV1.SeriesServiceClient
	log          *log.Helper
}

func NewSeriesService(
	ctx *bootstrap.Context,
	seriesClient seriesV1.SeriesServiceClient,
) *SeriesService {
	return &SeriesService{
		log:          ctx.NewLoggerHelper("series/service/admin-service"),
		seriesClient: seriesClient,
	}
}

func (s *SeriesService) List(ctx context.Context, req *paginationV1.PagingRequest) (*seriesV1.ListSeriesResponse, error) {
	if req != nil {
		// 原始 query 参数（非 JSON）视为剧名关键字
		raw := req.GetQuery()
		if raw != "" && !json.Valid([]byte(raw)) {
			if b, err := json.Marshal(map[string]any{"title___icontains": raw}); err == nil {
				setPagingQuerySP(req, string(b))
			}
		}
		// authorId 过滤
		if authorID := spQueryAuthorID(ctx); authorID > 0 {
			obj := map[string]any{"author_id": authorID}
			if req.GetQuery() != "" {
				var m map[string]any
				if json.Unmarshal([]byte(req.GetQuery()), &m) == nil && m != nil {
					m["author_id"] = authorID
					obj = m
				}
			}
			if b, err := json.Marshal(obj); err == nil {
				setPagingQuerySP(req, string(b))
			}
		}
	}
	return s.seriesClient.ListSeries(ctx, req)
}

func (s *SeriesService) Get(ctx context.Context, req *seriesV1.GetSeriesRequest) (*seriesV1.SeriesDetail, error) {
	return s.seriesClient.GetSeries(ctx, req)
}

func (s *SeriesService) Update(ctx context.Context, req *seriesV1.UpdateSeriesRequest) (*seriesV1.Series, error) {
	return s.seriesClient.UpdateSeries(ctx, req)
}

func (s *SeriesService) Delete(ctx context.Context, req *seriesV1.DeleteSeriesRequest) (*emptypb.Empty, error) {
	return s.seriesClient.DeleteSeries(ctx, req)
}
