package data

import (
	"context"
	"encoding/json"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/tx7do/go-utils/timeutil"
	"github.com/tx7do/go-utils/trans"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/predicate"
	"go-wind-shortplay/app/core/service/internal/data/ent/series"
	"go-wind-shortplay/app/core/service/internal/data/ent/video"

	seriesV1 "go-wind-shortplay/api/gen/go/series/service/v1"
)

// spSeriesEpisodeLimit 剧集详情单次下发的选集上限（防巨剧全量拉爆）
const spSeriesEpisodeLimit = 200

// seriesEntityToDTO ent.Series → proto Series（集数为实时派生，由调用方传入）
func seriesEntityToDTO(e *ent.Series, episodeCount, publishedCount uint64) *seriesV1.Series {
	if e == nil {
		return nil
	}
	return &seriesV1.Series{
		Id:             trans.Ptr(e.ID),
		Title:          trans.Ptr(e.Title),
		Description:    e.Description,
		CoverUrl:       e.CoverURL,
		AuthorId:       trans.Ptr(e.AuthorID),
		EpisodeCount:   trans.Ptr(episodeCount),
		PublishedCount: trans.Ptr(publishedCount),
		CreatedAt:      timeutil.TimeToTimestamppb(e.CreatedAt),
		UpdatedAt:      timeutil.TimeToTimestamppb(e.UpdatedAt),
	}
}

// fillEpisodeCovers 剧集展示封面回退：未设封面的剧批量取第一集（集号最小、已发布优先）的封面回填。
// 仅回填响应 DTO，不落库；单条查询失败静默跳过（展示冗余字段）。
func (r *SeriesRepo) fillEpisodeCovers(ctx context.Context, items ...*seriesV1.Series) {
	ids := make([]uint32, 0, len(items))
	for _, it := range items {
		if it != nil && it.GetCoverUrl() == "" && it.GetId() > 0 {
			ids = append(ids, it.GetId())
		}
	}
	if len(ids) == 0 {
		return
	}
	vs, err := r.entClient.Client().Video.Query().
		Where(video.SeriesIDIn(ids...)).
		Order(ent.Asc(video.FieldEpisodeNumber), ent.Asc(video.FieldID)).
		Select(video.FieldSeriesID, video.FieldStatus, video.FieldCoverURL).
		All(ctx)
	if err != nil {
		r.log.Errorf("fill episode covers failed: %s", err.Error())
		return
	}
	// 每剧取第一集；已发布集优先于未发布（保持集号升序）
	firstAny, firstPub := pickEpisodeCovers(vs)
	for _, it := range items {
		if it == nil || it.GetCoverUrl() != "" {
			continue
		}
		if cover, ok := firstPub[it.GetId()]; ok {
			it.CoverUrl = trans.Ptr(cover)
		} else if cover, ok := firstAny[it.GetId()]; ok {
			it.CoverUrl = trans.Ptr(cover)
		}
	}
}

// pickEpisodeCovers 纯选取逻辑（可单测）：按集号升序入参扫描，每剧记录
// 首个带封面的集（firstAny）与首个已发布带封面的集（firstPub）。
func pickEpisodeCovers(vs []*ent.Video) (firstAny, firstPub map[uint32]string) {
	firstAny = make(map[uint32]string, len(vs))
	firstPub = make(map[uint32]string, len(vs))
	for _, v := range vs {
		if v == nil || v.CoverURL == nil || *v.CoverURL == "" {
			continue
		}
		if _, dup := firstAny[v.SeriesID]; !dup {
			firstAny[v.SeriesID] = *v.CoverURL
		}
		if v.Status == video.StatusPublished {
			if _, dup := firstPub[v.SeriesID]; !dup {
				firstPub[v.SeriesID] = *v.CoverURL
			}
		}
	}
	return firstAny, firstPub
}

// spSeriesListFilter 列表过滤条件（BFF 翻译 query JSON 后的结构）
type spSeriesListFilter struct {
	Title    *string `json:"title___icontains"`
	AuthorID *uint32 `json:"author_id"`
}

type SeriesRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewSeriesRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *SeriesRepo {
	return &SeriesRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("series/repo/core-service"),
	}
}

// seriesCountsOf 批量统计剧集的集总数与已发布集数（按 series_id 聚合，免维护计数列）
func (r *SeriesRepo) seriesCountsOf(ctx context.Context, seriesIDs []uint32) (total, published map[uint32]uint64, err error) {
	total = make(map[uint32]uint64, len(seriesIDs))
	published = make(map[uint32]uint64, len(seriesIDs))
	if len(seriesIDs) == 0 {
		return
	}
	vs, err := r.entClient.Client().Video.Query().
		Where(video.SeriesIDIn(seriesIDs...)).
		Select(video.FieldSeriesID, video.FieldStatus).
		All(ctx)
	if err != nil {
		r.log.Errorf("count series videos failed: %s", err.Error())
		return
	}
	for _, v := range vs {
		total[v.SeriesID]++
		if v.Status == video.StatusPublished {
			published[v.SeriesID]++
		}
	}
	return
}

func (r *SeriesRepo) Get(ctx context.Context, id uint32) (*seriesV1.Series, error) {
	e, err := r.GetEntityRaw(ctx, id)
	if err != nil {
		return nil, err
	}
	total, published, err := r.seriesCountsOf(ctx, []uint32{id})
	if err != nil {
		return nil, seriesV1.ErrorInternalServerError("get series failed")
	}
	dto := seriesEntityToDTO(e, total[id], published[id])
	r.fillEpisodeCovers(ctx, dto)
	return dto, nil
}

// GetEntityRaw 内部取实体（服务层归属/可见性判断用）
func (r *SeriesRepo) GetEntityRaw(ctx context.Context, id uint32) (*ent.Series, error) {
	e, err := r.entClient.Client().Series.Query().Where(series.IDEQ(id)).Only(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, seriesV1.ErrorSeriesNotFound("series not found")
		}
		r.log.Errorf("get series failed: %s", err.Error())
		return nil, seriesV1.ErrorInternalServerError("get series failed")
	}
	return e, nil
}

// adminListFilter 解析 BFF 翻译后的过滤 JSON
func (r *SeriesRepo) adminListFilter(req *paginationV1.PagingRequest) []predicate.Series {
	if req.GetQuery() == "" {
		return nil
	}
	var f spSeriesListFilter
	if err := json.Unmarshal([]byte(req.GetQuery()), &f); err != nil {
		return nil
	}
	var predicates []predicate.Series
	if f.Title != nil && *f.Title != "" {
		predicates = append(predicates, series.TitleContainsFold(*f.Title))
	}
	if f.AuthorID != nil && *f.AuthorID > 0 {
		predicates = append(predicates, series.AuthorIDEQ(*f.AuthorID))
	}
	return predicates
}

// List 管理端列表（分页 + 过滤）
func (r *SeriesRepo) List(ctx context.Context, req *paginationV1.PagingRequest) (*seriesV1.ListSeriesResponse, error) {
	offs, limit := pageArgsOf(req)
	ps := r.adminListFilter(req)

	q := r.entClient.Client().Series.Query().Offset(offs).Limit(limit).Order(ent.Desc(series.FieldID))
	if len(ps) > 0 {
		q.Where(ps...)
	}
	items, err := q.All(ctx)
	if err != nil {
		r.log.Errorf("list series failed: %s", err.Error())
		return nil, seriesV1.ErrorInternalServerError("list series failed")
	}

	cq := r.entClient.Client().Series.Query()
	if len(ps) > 0 {
		cq.Where(ps...)
	}
	total, err := cq.Count(ctx)
	if err != nil {
		r.log.Errorf("count series failed: %s", err.Error())
		return nil, seriesV1.ErrorInternalServerError("count series failed")
	}

	ids := make([]uint32, 0, len(items))
	for _, e := range items {
		ids = append(ids, e.ID)
	}
	totalCount, publishedCount, err := r.seriesCountsOf(ctx, ids)
	if err != nil {
		return nil, seriesV1.ErrorInternalServerError("count series videos failed")
	}

	resp := &seriesV1.ListSeriesResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		resp.Items = append(resp.Items, seriesEntityToDTO(e, totalCount[e.ID], publishedCount[e.ID]))
	}
	r.fillEpisodeCovers(ctx, resp.Items...)
	return resp, nil
}

// ListByFilter App 剧集列表（query 剧名模糊 / authorId 过滤；onlyPublished 仅含有已发布集的剧）
func (r *SeriesRepo) ListByFilter(ctx context.Context, query string, authorID uint32, onlyPublished bool, page, pageSize uint32) (*seriesV1.ListSeriesResponse, error) {
	if page < 1 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	if pageSize > 50 {
		pageSize = 50
	}
	var ps []predicate.Series
	if query != "" {
		ps = append(ps, series.TitleContainsFold(query))
	}
	if authorID > 0 {
		ps = append(ps, series.AuthorIDEQ(authorID))
	}
	if onlyPublished {
		pubIDs, err := r.publishedSeriesIDs(ctx)
		if err != nil {
			return nil, err
		}
		if len(pubIDs) == 0 {
			return &seriesV1.ListSeriesResponse{Total: trans.Ptr(int64(0))}, nil
		}
		ps = append(ps, series.IDIn(pubIDs...))
	}

	q := r.entClient.Client().Series.Query().Where(ps...)
	total, err := q.Count(ctx)
	if err != nil {
		r.log.Errorf("count series by filter failed: %s", err.Error())
		return nil, seriesV1.ErrorInternalServerError("count series failed")
	}
	items, err := q.Order(ent.Desc(series.FieldUpdatedAt), ent.Desc(series.FieldID)).
		Offset(int(page-1) * int(pageSize)).Limit(int(pageSize)).All(ctx)
	if err != nil {
		r.log.Errorf("list series by filter failed: %s", err.Error())
		return nil, seriesV1.ErrorInternalServerError("list series failed")
	}

	ids := make([]uint32, 0, len(items))
	for _, e := range items {
		ids = append(ids, e.ID)
	}
	totalCount, publishedCount, err := r.seriesCountsOf(ctx, ids)
	if err != nil {
		return nil, seriesV1.ErrorInternalServerError("count series videos failed")
	}

	resp := &seriesV1.ListSeriesResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		resp.Items = append(resp.Items, seriesEntityToDTO(e, totalCount[e.ID], publishedCount[e.ID]))
	}
	r.fillEpisodeCovers(ctx, resp.Items...)
	return resp, nil
}

// publishedSeriesIDs 存在已发布集的剧集 ID 集合（全量派生；行数为有剧的 series 数量级）
func (r *SeriesRepo) publishedSeriesIDs(ctx context.Context) ([]uint32, error) {
	vs, err := r.entClient.Client().Video.Query().
		Where(video.SeriesIDGT(0), video.StatusEQ(video.StatusPublished)).
		Select(video.FieldSeriesID).
		All(ctx)
	if err != nil {
		r.log.Errorf("query published series ids failed: %s", err.Error())
		return nil, seriesV1.ErrorInternalServerError("list series failed")
	}
	seen := make(map[uint32]struct{}, len(vs))
	ids := make([]uint32, 0, len(vs))
	for _, v := range vs {
		if _, dup := seen[v.SeriesID]; !dup {
			seen[v.SeriesID] = struct{}{}
			ids = append(ids, v.SeriesID)
		}
	}
	return ids, nil
}

// ListVideosOfSeries 剧内选集（episode_number 升序、id 兜底）
func (r *SeriesRepo) ListVideosOfSeries(ctx context.Context, seriesID uint32, onlyPublished bool) ([]*ent.Video, error) {
	ps := []predicate.Video{video.SeriesIDEQ(seriesID)}
	if onlyPublished {
		ps = append(ps, video.StatusEQ(video.StatusPublished))
	}
	return r.entClient.Client().Video.Query().Where(ps...).
		Order(ent.Asc(video.FieldEpisodeNumber), ent.Asc(video.FieldID)).
		Limit(spSeriesEpisodeLimit).
		All(ctx)
}

// NextEpisodeNumber 剧内下一个集号（当前最大 +1；空剧为 1）
func (r *SeriesRepo) NextEpisodeNumber(ctx context.Context, seriesID uint32) uint32 {
	last, err := r.entClient.Client().Video.Query().
		Where(video.SeriesIDEQ(seriesID)).
		Order(ent.Desc(video.FieldEpisodeNumber)).
		First(ctx)
	if err != nil || last == nil {
		return 1
	}
	return last.EpisodeNumber + 1
}

// Create 创建剧集
func (r *SeriesRepo) Create(ctx context.Context, dto *seriesV1.Series, authorID uint32) (*seriesV1.Series, error) {
	if dto == nil || dto.GetTitle() == "" {
		return nil, seriesV1.ErrorBadRequest("invalid parameter")
	}
	builder := r.entClient.Client().Series.Create().
		SetTitle(dto.GetTitle()).
		SetDescription(dto.GetDescription()).
		SetCoverURL(dto.GetCoverUrl()).
		SetAuthorID(authorID).
		SetCreatedAt(time.Now())

	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}

	e, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("create series failed: %s", err.Error())
		return nil, seriesV1.ErrorInternalServerError("create series failed")
	}
	return seriesEntityToDTO(e, 0, 0), nil
}

// Update 更新剧集（部分字段）
func (r *SeriesRepo) Update(ctx context.Context, id uint32, dto *seriesV1.Series) (*seriesV1.Series, error) {
	builder := r.entClient.Client().Series.UpdateOneID(id)
	if dto.Title != nil {
		builder.SetTitle(dto.GetTitle())
	}
	if dto.Description != nil {
		builder.SetDescription(*dto.Description)
	}
	if dto.CoverUrl != nil {
		builder.SetCoverURL(*dto.CoverUrl)
	}
	builder.SetUpdatedAt(time.Now())

	e, err := builder.Save(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, seriesV1.ErrorSeriesNotFound("series not found")
		}
		r.log.Errorf("update series failed: %s", err.Error())
		return nil, seriesV1.ErrorInternalServerError("update series failed")
	}
	return seriesEntityToDTO(e, 0, 0), nil
}

// Delete 删除剧集行（剧内视频解挂由服务层同事务完成）
func (r *SeriesRepo) Delete(ctx context.Context, id uint32) error {
	if err := r.entClient.Client().Series.DeleteOneID(id).Exec(ctx); err != nil {
		if ent.IsNotFound(err) {
			return seriesV1.ErrorSeriesNotFound("series not found")
		}
		r.log.Errorf("delete series failed: %s", err.Error())
		return seriesV1.ErrorInternalServerError("delete series failed")
	}
	return nil
}

// DetachSeriesVideos 解挂剧内全部视频（清 series_id / episode_number）
func (r *SeriesRepo) DetachSeriesVideos(ctx context.Context, seriesID uint32) error {
	_, err := r.entClient.Client().Video.Update().
		Where(video.SeriesIDEQ(seriesID)).
		SetSeriesID(0).
		SetEpisodeNumber(0).
		Save(ctx)
	if err != nil {
		r.log.Errorf("detach series videos failed: %s", err.Error())
		return seriesV1.ErrorInternalServerError("detach series videos failed")
	}
	return nil
}
