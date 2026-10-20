package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"
	"github.com/tx7do/go-utils/trans"

	seriesV1 "go-wind-shortplay/api/gen/go/series/service/v1"

	"go-wind-shortplay/app/core/service/internal/data"
)

// SeriesService 剧集服务（core 真实业务：建剧/编辑/选集浏览）。
// 可见性跟随视频审核状态：非作者/游客视角仅含有已发布集的剧与已发布集。
type SeriesService struct {
	seriesV1.UnimplementedSeriesServiceServer

	log        *log.Helper
	seriesRepo *data.SeriesRepo
	videoRepo  *data.VideoRepo
}

func NewSeriesService(
	ctx *bootstrap.Context,
	seriesRepo *data.SeriesRepo,
	videoRepo *data.VideoRepo,
) *SeriesService {
	return &SeriesService{
		log:        ctx.NewLoggerHelper("series/service/core-service"),
		seriesRepo: seriesRepo,
		videoRepo:  videoRepo,
	}
}

// isSeriesOwner 归属判断：作者本人或管理端（平台/系统上下文）
func isSeriesOwner(ctx context.Context, authorID uint32) bool {
	if spIsAdminCaller(ctx) {
		return true
	}
	uid := spViewerUserID(ctx)
	return uid > 0 && uid == authorID
}

func (s *SeriesService) CreateSeries(ctx context.Context, req *seriesV1.CreateSeriesRequest) (*seriesV1.Series, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, seriesV1.ErrorUnauthorized("login required")
	}
	if req == nil || len([]rune(req.GetTitle())) == 0 {
		return nil, seriesV1.ErrorBadRequest("title is required")
	}
	if len([]rune(req.GetTitle())) > 100 {
		return nil, seriesV1.ErrorBadRequest("title too long (max 100)")
	}
	return s.seriesRepo.Create(ctx, &seriesV1.Series{
		Title:       trans.Ptr(req.GetTitle()),
		Description: req.Description,
		CoverUrl:    req.CoverUrl,
	}, uid)
}

func (s *SeriesService) GetSeries(ctx context.Context, req *seriesV1.GetSeriesRequest) (*seriesV1.SeriesDetail, error) {
	if req == nil || req.GetId() == 0 {
		return nil, seriesV1.ErrorBadRequest("invalid parameter")
	}
	dto, err := s.seriesRepo.Get(ctx, req.GetId())
	if err != nil {
		return nil, err
	}
	owner := isSeriesOwner(ctx, dto.GetAuthorId())
	if !owner && dto.GetPublishedCount() == 0 {
		// 无可见集：对公众等同不存在
		return nil, seriesV1.ErrorSeriesNotFound("series not found")
	}

	videos, err := s.seriesRepo.ListVideosOfSeries(ctx, req.GetId(), !owner)
	if err != nil {
		return nil, err
	}
	detail := &seriesV1.SeriesDetail{Series: dto}
	for _, v := range videos {
		vd, err := s.videoRepo.ToDTO(ctx, v)
		if err != nil {
			return nil, err
		}
		detail.Items = append(detail.Items, vd)
	}
	return detail, nil
}

func (s *SeriesService) UpdateSeries(ctx context.Context, req *seriesV1.UpdateSeriesRequest) (*seriesV1.Series, error) {
	if req == nil || req.GetId() == 0 {
		return nil, seriesV1.ErrorBadRequest("invalid parameter")
	}
	se, err := s.seriesRepo.GetEntityRaw(ctx, req.GetId())
	if err != nil {
		return nil, err
	}
	if !isSeriesOwner(ctx, se.AuthorID) {
		return nil, seriesV1.ErrorNotSeriesOwner("not series owner")
	}
	if req.Title != nil && len([]rune(req.GetTitle())) > 100 {
		return nil, seriesV1.ErrorBadRequest("title too long (max 100)")
	}
	return s.seriesRepo.Update(ctx, req.GetId(), &seriesV1.Series{
		Title:       req.Title,
		Description: req.Description,
		CoverUrl:    req.CoverUrl,
	})
}

func (s *SeriesService) DeleteSeries(ctx context.Context, req *seriesV1.DeleteSeriesRequest) (*emptypb.Empty, error) {
	if req == nil || req.GetId() == 0 {
		return nil, seriesV1.ErrorBadRequest("invalid parameter")
	}
	se, err := s.seriesRepo.GetEntityRaw(ctx, req.GetId())
	if err != nil {
		return nil, err
	}
	if !isSeriesOwner(ctx, se.AuthorID) {
		return nil, seriesV1.ErrorNotSeriesOwner("not series owner")
	}
	// 先解挂剧内视频（清 series_id/episode_number），再删剧行
	if err = s.seriesRepo.DetachSeriesVideos(ctx, req.GetId()); err != nil {
		return nil, err
	}
	if err = s.seriesRepo.Delete(ctx, req.GetId()); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// ListSeries 管理端全量列表
func (s *SeriesService) ListSeries(ctx context.Context, req *paginationV1.PagingRequest) (*seriesV1.ListSeriesResponse, error) {
	return s.seriesRepo.List(ctx, req)
}

// QuerySeries App 剧集列表：非本人视角仅含有已发布集的剧
func (s *SeriesService) QuerySeries(ctx context.Context, req *seriesV1.QuerySeriesRequest) (*seriesV1.ListSeriesResponse, error) {
	authorID := req.GetAuthorId()
	isSelf := authorID > 0 && authorID == spViewerUserID(ctx)
	return s.seriesRepo.ListByFilter(ctx, req.GetQuery(), authorID, !isSelf, req.GetPageNum(), req.GetPageSize())
}

// resolveSeriesAttach 校验挂靠请求：剧须存在且为本人所有，返回 (seriesID, episodeNumber)。
// episodeNumber 缺省（0）时自动排到剧内当前最大集号 +1。
func (s *SeriesService) ResolveSeriesAttach(ctx context.Context, uid uint32, seriesID, episodeNumber uint32) (uint32, uint32, error) {
	se, err := s.seriesRepo.GetEntityRaw(ctx, seriesID)
	if err != nil {
		return 0, 0, err
	}
	if !spIsAdminCaller(ctx) && se.AuthorID != uid {
		return 0, 0, seriesV1.ErrorNotSeriesOwner("not series owner")
	}
	if episodeNumber == 0 {
		episodeNumber = s.seriesRepo.NextEpisodeNumber(ctx, seriesID)
	}
	return seriesID, episodeNumber, nil
}
