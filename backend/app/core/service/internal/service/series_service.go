package service

import (
	"context"
	"strconv"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"
	"github.com/tx7do/go-utils/trans"

	seriesV1 "go-wind-shortplay/api/gen/go/series/service/v1"

	"go-wind-shortplay/app/core/service/internal/data"
)

// spFollowedSeriesCap 我的追剧列表单次拉取上限（内存排序派生分页）
const spFollowedSeriesCap = 500

// SeriesService 剧集服务（core 真实业务：建剧/编辑/选集浏览/追剧）。
// 可见性跟随视频审核状态：非作者/游客视角仅含有已发布集的剧与已发布集。
type SeriesService struct {
	seriesV1.UnimplementedSeriesServiceServer

	log        *log.Helper
	seriesRepo *data.SeriesRepo
	videoRepo  *data.VideoRepo

	seriesFollowRepo *data.SeriesFollowRepo
	internalMessage  InternalMessageNotifier
}

func NewSeriesService(
	ctx *bootstrap.Context,
	seriesRepo *data.SeriesRepo,
	videoRepo *data.VideoRepo,
	seriesFollowRepo *data.SeriesFollowRepo,
) *SeriesService {
	return &SeriesService{
		log:              ctx.NewLoggerHelper("series/service/core-service"),
		seriesRepo:       seriesRepo,
		videoRepo:        videoRepo,
		seriesFollowRepo: seriesFollowRepo,
	}
}

// RegisterNotifier 注入站内信通知能力（追剧更新通知）。
func (s *SeriesService) RegisterNotifier(n InternalMessageNotifier) {
	s.internalMessage = n
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

	// 追剧人数 + 观看者追剧状态（尽力而为，失败不阻塞详情）
	if s.seriesFollowRepo != nil {
		if fc, ferr := s.seriesFollowRepo.FollowerCount(ctx, req.GetId()); ferr == nil {
			detail.FollowerCount = trans.Ptr(uint64(fc))
			dto.FollowerCount = trans.Ptr(uint64(fc))
		}
		if uid := spViewerUserID(ctx); uid > 0 {
			st, serr := s.seriesFollowRepo.GetFollowStatus(ctx, uid, []uint32{req.GetId()})
			if serr == nil {
				detail.ViewerFollowing = trans.Ptr(st[req.GetId()])
			}
		}
	}
	if detail.ViewerFollowing == nil {
		detail.ViewerFollowing = trans.Ptr(false)
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

// ── 追剧 ──

// FollowSeries 追剧（幂等）。对公众不可见的剧（无已发布集且非本人）按不存在处理，防探测。
func (s *SeriesService) FollowSeries(ctx context.Context, req *seriesV1.FollowSeriesRequest) (*seriesV1.FollowSeriesResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, seriesV1.ErrorUnauthorized("login required")
	}
	if req == nil || req.GetSeriesId() == 0 {
		return nil, seriesV1.ErrorBadRequest("invalid parameter")
	}
	dto, err := s.seriesRepo.Get(ctx, req.GetSeriesId())
	if err != nil {
		return nil, err
	}
	if !isSeriesOwner(ctx, dto.GetAuthorId()) && dto.GetPublishedCount() == 0 {
		return nil, seriesV1.ErrorSeriesNotFound("series not found")
	}
	if _, err := s.seriesFollowRepo.Follow(ctx, uid, req.GetSeriesId()); err != nil {
		return nil, err
	}
	fc, _ := s.seriesFollowRepo.FollowerCount(ctx, req.GetSeriesId())
	return &seriesV1.FollowSeriesResponse{
		Following:     trans.Ptr(true),
		FollowerCount: trans.Ptr(uint64(fc)),
	}, nil
}

// UnfollowSeries 取消追剧（幂等，删自己的关注行不涉剧可见性）。
func (s *SeriesService) UnfollowSeries(ctx context.Context, req *seriesV1.FollowSeriesRequest) (*seriesV1.FollowSeriesResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, seriesV1.ErrorUnauthorized("login required")
	}
	if req == nil || req.GetSeriesId() == 0 {
		return nil, seriesV1.ErrorBadRequest("invalid parameter")
	}
	if _, err := s.seriesFollowRepo.Unfollow(ctx, uid, req.GetSeriesId()); err != nil {
		return nil, err
	}
	fc, _ := s.seriesFollowRepo.FollowerCount(ctx, req.GetSeriesId())
	return &seriesV1.FollowSeriesResponse{
		Following:     trans.Ptr(false),
		FollowerCount: trans.Ptr(uint64(fc)),
	}, nil
}

// ListFollowedSeries 我的追剧列表（按追剧时间倒序；公开可见性同 QuerySeries）
func (s *SeriesService) ListFollowedSeries(ctx context.Context, req *paginationV1.PagingRequest) (*seriesV1.ListSeriesResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, seriesV1.ErrorUnauthorized("login required")
	}
	page, pageSize := pageArgsOfSeries(req)
	ids, err := s.seriesFollowRepo.FollowedSeriesIDs(ctx, uid, spFollowedSeriesCap)
	if err != nil {
		return nil, seriesV1.ErrorInternalServerError("list followed series failed")
	}
	return s.seriesRepo.ListByIDs(ctx, ids, !spIsAdminCaller(ctx), page, pageSize)
}

// GetSeriesFollowStatus 批量追剧状态（游客全 false）
func (s *SeriesService) GetSeriesFollowStatus(ctx context.Context, req *seriesV1.GetSeriesFollowStatusRequest) (*seriesV1.GetSeriesFollowStatusResponse, error) {
	resp := &seriesV1.GetSeriesFollowStatusResponse{Statuses: make(map[uint32]*seriesV1.SeriesFollowStatus)}
	if req == nil || len(req.GetSeriesIds()) == 0 {
		return resp, nil
	}
	following := make(map[uint32]bool)
	if uid := spViewerUserID(ctx); uid > 0 {
		following, _ = s.seriesFollowRepo.GetFollowStatus(ctx, uid, req.GetSeriesIds())
	}
	for _, id := range req.GetSeriesIds() {
		resp.Statuses[id] = &seriesV1.SeriesFollowStatus{Following: trans.Ptr(following[id])}
	}
	return resp, nil
}

// pageArgsSeriesOf pagination.PagingRequest → (page, pageSize)，缺省 1/10 上限 50。
func pageArgsOfSeries(req *paginationV1.PagingRequest) (uint32, uint32) {
	page, pageSize := uint32(1), uint32(10)
	if req == nil {
		return page, pageSize
	}
	if req.GetPage() > 0 {
		page = req.GetPage()
	}
	if req.GetPageSize() > 0 {
		pageSize = req.GetPageSize()
	}
	if pageSize > 50 {
		pageSize = 50
	}
	return page, pageSize
}

// NotifyFollowersNewEpisode 剧集更新通知：新集发布后 fan-out 给追剧者（作者除外，
// 系统口径无 actor；尽力而为不回滚发布主流程；人数截断到 spSeriesFollowNotifyCap）。
func (s *SeriesService) NotifyFollowersNewEpisode(ctx context.Context, seriesID, videoID, episodeNumber uint32, videoTitle string, authorID uint32) {
	if s.internalMessage == nil || s.seriesFollowRepo == nil || seriesID == 0 || videoID == 0 {
		return
	}
	targets := s.seriesFollowRepo.FollowerUserIDs(ctx, seriesID)
	filtered := make([]uint32, 0, len(targets))
	for _, uid := range targets {
		if uid != 0 && uid != authorID {
			filtered = append(filtered, uid)
		}
	}
	if len(filtered) == 0 {
		return
	}
	se, err := s.seriesRepo.GetEntityRaw(ctx, seriesID)
	if err != nil {
		return
	}
	body := "你追的剧《" + se.Title + "》更新了：第 " + strconv.FormatUint(uint64(episodeNumber), 10) +
		" 集《" + videoTitle + "》已上线" + spVideoBizMarker(videoID)
	if _, err := s.internalMessage.SendSystemNotification(ctx, "追更更新", body, filtered); err != nil {
		s.log.Errorf("notify series followers failed: %s", err.Error())
	}
}
