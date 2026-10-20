package data

import (
	"context"
	"encoding/json"
	"time"

	"entgo.io/ent/dialect/sql"
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
	"go-wind-shortplay/app/core/service/internal/data/ent/videotag"
	"go-wind-shortplay/app/core/service/internal/data/ent/videotagrel"

	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
)

// statusEntityOfVideo proto 枚举 → ent 枚举
func statusEntityOfVideo(s videoV1.VideoStatus) video.Status {
	switch s {
	case videoV1.VideoStatus_VIDEO_STATUS_DRAFT:
		return video.StatusDraft
	case videoV1.VideoStatus_VIDEO_STATUS_REVIEWING:
		return video.StatusReviewing
	case videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED:
		return video.StatusPublished
	case videoV1.VideoStatus_VIDEO_STATUS_REJECTED:
		return video.StatusRejected
	case videoV1.VideoStatus_VIDEO_STATUS_OFFLINE:
		return video.StatusOffline
	default:
		return video.StatusDraft
	}
}

// statusDTOOfVideo ent 枚举 → proto 枚举
func statusDTOOfVideo(s video.Status) videoV1.VideoStatus {
	switch s {
	case video.StatusDraft:
		return videoV1.VideoStatus_VIDEO_STATUS_DRAFT
	case video.StatusReviewing:
		return videoV1.VideoStatus_VIDEO_STATUS_REVIEWING
	case video.StatusPublished:
		return videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED
	case video.StatusRejected:
		return videoV1.VideoStatus_VIDEO_STATUS_REJECTED
	case video.StatusOffline:
		return videoV1.VideoStatus_VIDEO_STATUS_OFFLINE
	default:
		return videoV1.VideoStatus_VIDEO_STATUS_UNSPECIFIED
	}
}

// videoEntityToDTO ent.Video → proto Video
func videoEntityToDTO(e *ent.Video, tags []string) *videoV1.Video {
	if e == nil {
		return nil
	}
	dto := &videoV1.Video{
		Id:           trans.Ptr(e.ID),
		Title:        trans.Ptr(e.Title),
		Description:  e.Description,
		CoverUrl:     e.CoverURL,
		VideoUrl:     e.VideoURL,
		Duration:     trans.Ptr(e.Duration),
		Width:        trans.Ptr(e.Width),
		Height:       trans.Ptr(e.Height),
		Status:       statusDTOOfVideo(e.Status).Enum(),
		AuthorId:     trans.Ptr(e.AuthorID),
		LikeCount:    trans.Ptr(e.LikeCount),
		CollectCount: trans.Ptr(e.CollectCount),
		CommentCount: trans.Ptr(e.CommentCount),
		ViewCount:    trans.Ptr(e.ViewCount),
		RejectReason: e.RejectReason,
		PublishedAt:  timeutil.TimeToTimestamppb(e.PublishedAt),
		CreatedAt:    timeutil.TimeToTimestamppb(e.CreatedAt),
		UpdatedAt:    timeutil.TimeToTimestamppb(e.UpdatedAt),
	}
	if tags != nil {
		dto.Tags = tags
	}
	if e.SeriesID > 0 {
		dto.SeriesId = trans.Ptr(e.SeriesID)
		dto.EpisodeNumber = trans.Ptr(e.EpisodeNumber)
	}
	return dto
}

// spVideoListFilter admin 列表过滤条件（BFF 翻译 query JSON 后的结构）
type spVideoListFilter struct {
	Title    *string `json:"title___icontains"`
	Status   *string `json:"status"`
	AuthorID *uint32 `json:"author_id"`
}

type VideoRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewVideoRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *VideoRepo {
	return &VideoRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("video/repo/core-service"),
	}
}

// pageArgsOf 解析分页参数（缺省 1/10，上限 50）
func pageArgsOf(req *paginationV1.PagingRequest) (offset, limit int) {
	page := int(req.GetPage())
	if page < 1 {
		page = 1
	}
	size := int(req.GetPageSize())
	if size <= 0 {
		size = 10
	}
	if size > 50 {
		size = 50
	}
	return (page - 1) * size, size
}

func (r *VideoRepo) toDTO(ctx context.Context, e *ent.Video) (*videoV1.Video, error) {
	tags, err := r.TagsOfVideo(ctx, e.ID)
	if err != nil {
		tags = nil
	}
	dto := videoEntityToDTO(e, tags)
	r.fillSeriesTitles(ctx, dto)
	return dto, nil
}

// fillSeriesTitles 批量回填剧集名（展示冗余字段，查询失败静默跳过）
func (r *VideoRepo) fillSeriesTitles(ctx context.Context, items ...*videoV1.Video) {
	ids := make([]uint32, 0, len(items))
	seen := make(map[uint32]struct{}, len(items))
	for _, v := range items {
		if sid := v.GetSeriesId(); sid > 0 {
			if _, dup := seen[sid]; !dup {
				seen[sid] = struct{}{}
				ids = append(ids, sid)
			}
		}
	}
	if len(ids) == 0 {
		return
	}
	ss, err := r.entClient.Client().Series.Query().Where(series.IDIn(ids...)).All(ctx)
	if err != nil {
		return
	}
	names := make(map[uint32]string, len(ss))
	for _, s := range ss {
		names[s.ID] = s.Title
	}
	for _, v := range items {
		if n, ok := names[v.GetSeriesId()]; ok {
			v.SeriesTitle = &n
		}
	}
}

func (r *VideoRepo) Get(ctx context.Context, id uint32) (*videoV1.Video, error) {
	e, err := r.entClient.Client().Video.Query().Where(video.IDEQ(id)).Only(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, videoV1.ErrorVideoNotFound("video not found")
		}
		r.log.Errorf("get video failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("get video failed")
	}
	return r.toDTO(ctx, e)
}

// GetEntityRaw 内部取实体（计数 ledger 等场景）
func (r *VideoRepo) GetEntityRaw(ctx context.Context, id uint32) (*ent.Video, error) {
	return r.entClient.Client().Video.Query().Where(video.IDEQ(id)).Only(ctx)
}

// ToDTO 实体转 DTO（跨域组装：series 详情选集列表）
func (r *VideoRepo) ToDTO(ctx context.Context, e *ent.Video) (*videoV1.Video, error) {
	return r.toDTO(ctx, e)
}

// adminListFilter 解析 BFF 翻译后的过滤 JSON
func (r *VideoRepo) adminListFilter(req *paginationV1.PagingRequest) (predicates []predicate.Video) {
	if req.GetQuery() == "" {
		return nil
	}
	var f spVideoListFilter
	if err := json.Unmarshal([]byte(req.GetQuery()), &f); err != nil {
		return nil
	}
	if f.Title != nil && *f.Title != "" {
		predicates = append(predicates, video.TitleContainsFold(*f.Title))
	}
	if f.Status != nil && *f.Status != "" {
		predicates = append(predicates, video.StatusEQ(video.Status(*f.Status)))
	}
	if f.AuthorID != nil && *f.AuthorID > 0 {
		predicates = append(predicates, video.AuthorIDEQ(*f.AuthorID))
	}
	return predicates
}

// List 管理端列表（分页 + 过滤）
func (r *VideoRepo) List(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListVideoResponse, error) {
	offs, limit := pageArgsOf(req)
	q := r.entClient.Client().Video.Query().Offset(offs).Limit(limit).Order(ent.Desc(video.FieldID))
	if ps := r.adminListFilter(req); len(ps) > 0 {
		q.Where(ps...)
	}
	items, err := q.All(ctx)
	if err != nil {
		r.log.Errorf("list video failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("list video failed")
	}

	cq := r.entClient.Client().Video.Query()
	if ps := r.adminListFilter(req); len(ps) > 0 {
		cq.Where(ps...)
	}
	total, err := cq.Count(ctx)
	if err != nil {
		r.log.Errorf("count video failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("count video failed")
	}

	resp := &videoV1.ListVideoResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		tags, _ := r.TagsOfVideo(ctx, e.ID)
		resp.Items = append(resp.Items, videoEntityToDTO(e, tags))
	}
	r.fillSeriesTitles(ctx, resp.Items...)
	return resp, nil
}

// ListPublishedByAuthors 关注召回：指定作者的已发布视频（按发布时间倒序）
func (r *VideoRepo) ListPublishedByAuthors(ctx context.Context, authorIDs []uint32, limit int) ([]*ent.Video, error) {
	if len(authorIDs) == 0 {
		return nil, nil
	}
	return r.entClient.Client().Video.Query().
		Where(video.StatusEQ(video.StatusPublished), video.AuthorIDIn(authorIDs...)).
		Order(ent.Desc(video.FieldPublishedAt)).
		Limit(limit).
		All(ctx)
}

// ListHot 热门召回：互动加权（view 优先 + like 加成），近发布优先
func (r *VideoRepo) ListHot(ctx context.Context, limit int) ([]*ent.Video, error) {
	return r.entClient.Client().Video.Query().
		Where(video.StatusEQ(video.StatusPublished)).
		Modify(func(s *sql.Selector) {
			// UBA 完播聚合（每视频至多一行，不产生行增殖）：完播是内容质量的
			// 强信号，计数列（view/like/collect）只反映互动量不反映看完率。
			agg := sql.Select("video_id", "COUNT(*) AS complete_cnt").
				From(sql.Table("sp_uba_events")).
				Where(sql.EQ("event_type", "VIDEO_COMPLETE")).
				GroupBy("video_id").
				As("uba_agg")
			s.LeftJoin(agg).On(s.C(video.FieldID), "video_id")
			// 热度分：播放 + 点赞×3 + 收藏×5 + 完播×4，同分近发布优先。
			// 商业版 AI 推荐服务替换本召回时接口形态不变（ROADMAP 预留）。
			s.OrderBy(sql.Desc(
				"view_count * 1 + like_count * 3 + collect_count * 5 + COALESCE(complete_cnt, 0) * 4"),
				sql.Desc(video.FieldPublishedAt),
			)
		}).
		Limit(limit).
		All(ctx)
}

// ListLatest 最新兜底召回
func (r *VideoRepo) ListLatest(ctx context.Context, limit int) ([]*ent.Video, error) {
	return r.entClient.Client().Video.Query().
		Where(video.StatusEQ(video.StatusPublished)).
		Order(ent.Desc(video.FieldPublishedAt), ent.Desc(video.FieldID)).
		Limit(limit).
		All(ctx)
}

// SearchByKeyword 搜索：标题模糊 + 标签精确命中的视频 ID 集合
func (r *VideoRepo) SearchByKeyword(ctx context.Context, keyword string, limit int) ([]*ent.Video, error) {
	if keyword == "" {
		return nil, nil
	}
	// 标题模糊
	byTitle, err := r.entClient.Client().Video.Query().
		Where(video.StatusEQ(video.StatusPublished), video.TitleContainsFold(keyword)).
		Order(ent.Desc(video.FieldPublishedAt)).
		Limit(limit).
		All(ctx)
	if err != nil {
		r.log.Errorf("search video by title failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("search video failed")
	}

	// 标签精确
	byTag, err := r.ListByTag(ctx, keyword, limit)
	if err != nil {
		return nil, err
	}

	merged := make(map[uint32]*ent.Video, len(byTitle)+len(byTag))
	for _, v := range byTitle {
		merged[v.ID] = v
	}
	for _, v := range byTag {
		if _, dup := merged[v.ID]; !dup {
			merged[v.ID] = v
		}
	}
	out := make([]*ent.Video, 0, len(merged))
	for _, v := range merged {
		out = append(out, v)
	}
	return out, nil
}

// ListByTag 标签聚合
func (r *VideoRepo) ListByTag(ctx context.Context, tagName string, limit int) ([]*ent.Video, error) {
	tag, err := r.entClient.Client().VideoTag.Query().Where(videotag.NameEQ(tagName)).Only(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, nil
		}
		r.log.Errorf("get tag failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("get tag failed")
	}
	rels, err := r.entClient.Client().VideoTagRel.Query().
		Where(videotagrel.TagIDEQ(tag.ID)).
		Order(ent.Desc(videotagrel.FieldID)).
		Limit(limit).
		All(ctx)
	if err != nil {
		r.log.Errorf("list tag rels failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("list tag rels failed")
	}
	if len(rels) == 0 {
		return nil, nil
	}
	ids := make([]uint32, 0, len(rels))
	for _, rel := range rels {
		ids = append(ids, rel.VideoID)
	}
	return r.entClient.Client().Video.Query().
		Where(video.IDIn(ids...), video.StatusEQ(video.StatusPublished)).
		All(ctx)
}

// ListByAuthor 用户主页作品列表。isSelf=本人（含草稿/审核中/驳回/下架），否则仅已发布。
func (r *VideoRepo) ListByAuthor(ctx context.Context, authorID uint32, isSelf bool, page, pageSize uint32) (*videoV1.ListVideoResponse, error) {
	if page < 1 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	if pageSize > 50 {
		pageSize = 50
	}
	ps := []predicate.Video{video.AuthorIDEQ(authorID)}
	if !isSelf {
		ps = append(ps, video.StatusEQ(video.StatusPublished))
	}
	q := r.entClient.Client().Video.Query().Where(ps...)
	total, err := q.Count(ctx)
	if err != nil {
		r.log.Errorf("count author videos failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("count author videos failed")
	}
	items, err := q.Order(ent.Desc(video.FieldCreatedAt)).Offset(int(page-1) * int(pageSize)).Limit(int(pageSize)).All(ctx)
	if err != nil {
		r.log.Errorf("list author videos failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("list author videos failed")
	}
	resp := &videoV1.ListVideoResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		tags, _ := r.TagsOfVideo(ctx, e.ID)
		resp.Items = append(resp.Items, videoEntityToDTO(e, tags))
	}
	r.fillSeriesTitles(ctx, resp.Items...)
	return resp, nil
}

// ListCollectedByUser 我的收藏（按收藏时间倒序）
func (r *VideoRepo) ListCollectedByUser(ctx context.Context, videoIDs []uint32) ([]*ent.Video, error) {
	if len(videoIDs) == 0 {
		return nil, nil
	}
	return r.entClient.Client().Video.Query().Where(video.IDIn(videoIDs...)).All(ctx)
}

// ListTopByMetric TOP 排行
func (r *VideoRepo) ListTopByMetric(ctx context.Context, metric TopMetric, limit int) ([]*ent.Video, error) {
	field := video.FieldViewCount
	switch metric {
	case TopMetricLike:
		field = video.FieldLikeCount
	case TopMetricCollect:
		field = video.FieldCollectCount
	case TopMetricComment:
		field = video.FieldCommentCount
	}
	return r.entClient.Client().Video.Query().
		Where(video.StatusEQ(video.StatusPublished)).
		Order(ent.Desc(field)).
		Limit(limit).
		All(ctx)
}

// Create 创建视频
func (r *VideoRepo) Create(ctx context.Context, dto *videoV1.Video, tags []string) (*videoV1.Video, error) {
	if dto == nil {
		return nil, videoV1.ErrorBadRequest("invalid parameter")
	}
	builder := r.entClient.Client().Video.Create().
		SetTitle(dto.GetTitle()).
		SetDescription(dto.GetDescription()).
		SetCoverURL(dto.GetCoverUrl()).
		SetVideoURL(dto.GetVideoUrl()).
		SetDuration(dto.GetDuration()).
		SetWidth(dto.GetWidth()).
		SetHeight(dto.GetHeight()).
		SetStatus(statusEntityOfVideo(dto.GetStatus())).
		SetAuthorID(dto.GetAuthorId()).
		SetRejectReason(dto.GetRejectReason()).
		SetNillablePublishedAt(timeutil.TimestamppbToTime(dto.PublishedAt)).
		SetCreatedAt(time.Now())

	if dto.GetSeriesId() > 0 {
		builder.SetSeriesID(dto.GetSeriesId()).
			SetEpisodeNumber(dto.GetEpisodeNumber())
	}

	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}

	e, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("create video failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("create video failed")
	}
	if len(tags) > 0 {
		if err = r.SetTags(ctx, e.ID, tags); err != nil {
			return nil, err
		}
	}
	return r.toDTO(ctx, e)
}

// Update 更新视频（部分字段）
func (r *VideoRepo) Update(ctx context.Context, id uint32, dto *videoV1.Video, tags []string) (*videoV1.Video, error) {
	builder := r.entClient.Client().Video.UpdateOneID(id)
	if dto.Title != nil {
		builder.SetTitle(dto.GetTitle())
	}
	if dto.Description != nil {
		builder.SetDescription(*dto.Description)
	}
	if dto.CoverUrl != nil {
		builder.SetCoverURL(*dto.CoverUrl)
	}
	if dto.VideoUrl != nil {
		builder.SetVideoURL(*dto.VideoUrl)
	}
	if dto.Duration != nil {
		builder.SetDuration(dto.GetDuration())
	}
	if dto.Width != nil {
		builder.SetWidth(dto.GetWidth())
	}
	if dto.Height != nil {
		builder.SetHeight(dto.GetHeight())
	}
	if dto.Status != nil {
		builder.SetStatus(statusEntityOfVideo(*dto.Status))
	}
	if dto.RejectReason != nil {
		builder.SetRejectReason(*dto.RejectReason)
	}
	if dto.PublishedAt != nil {
		builder.SetNillablePublishedAt(timeutil.TimestamppbToTime(dto.PublishedAt))
	}
	// 挂靠变更：series_id 出现即生效（>0 挂靠 / =0 解挂），集号随行
	if dto.SeriesId != nil {
		builder.SetSeriesID(*dto.SeriesId)
		if *dto.SeriesId == 0 {
			builder.SetEpisodeNumber(0)
		} else if dto.EpisodeNumber != nil {
			builder.SetEpisodeNumber(*dto.EpisodeNumber)
		}
	}
	builder.SetUpdatedAt(time.Now())

	e, err := builder.Save(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, videoV1.ErrorVideoNotFound("video not found")
		}
		r.log.Errorf("update video failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("update video failed")
	}
	if tags != nil {
		if err = r.SetTags(ctx, id, tags); err != nil {
			return nil, err
		}
	}
	return r.toDTO(ctx, e)
}

// Delete 删除视频（连带标签关联）
func (r *VideoRepo) Delete(ctx context.Context, id uint32) error {
	if _, err := r.entClient.Client().VideoTagRel.Delete().Where(videotagrel.VideoIDEQ(id)).Exec(ctx); err != nil {
		r.log.Errorf("delete video tag rels failed: %s", err.Error())
	}
	if err := r.entClient.Client().Video.DeleteOneID(id).Exec(ctx); err != nil {
		if ent.IsNotFound(err) {
			return videoV1.ErrorVideoNotFound("video not found")
		}
		r.log.Errorf("delete video failed: %s", err.Error())
		return videoV1.ErrorInternalServerError("delete video failed")
	}
	return nil
}

// ── 计数 ledger：只允许在互动台账事务内经本组方法增减（全仓铁律 5）──

// AddCountDelta 在事务 tx 内对视频计数列做有符号增减（PG BIGINT 列，负增量到 0 截断由调用方保证）。
func (r *VideoRepo) AddCountDelta(ctx context.Context, tx *ent.Tx, videoID uint32, like, collect, comment int64) error {
	builder := tx.Video.UpdateOneID(videoID)
	apply := func(delta int64, add func(int64) *ent.VideoUpdateOne) {
		if delta != 0 {
			add(delta)
		}
	}
	apply(like, builder.AddLikeCount)
	apply(collect, builder.AddCollectCount)
	apply(comment, builder.AddCommentCount)
	if err := builder.Exec(ctx); err != nil {
		r.log.Errorf("add count delta failed: %s", err.Error())
		return videoV1.ErrorInternalServerError("add count delta failed")
	}
	return nil
}

// AddViewCount 播放量 +1（详情页调用，容忍丢失）
func (r *VideoRepo) AddViewCount(ctx context.Context, videoID uint32) error {
	_, err := r.entClient.Client().Video.Update().Where(video.IDEQ(videoID)).AddViewCount(1).Save(ctx)
	return err
}

// CountTodayPublished 今日发布数
func (r *VideoRepo) CountTodayPublished(ctx context.Context) (int, error) {
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	return r.entClient.Client().Video.Query().
		Where(video.StatusEQ(video.StatusPublished), video.PublishedAtGTE(start)).
		Count(ctx)
}

// CountByStatus 按状态计数
func (r *VideoRepo) CountByStatus(ctx context.Context, status video.Status) (int, error) {
	return r.entClient.Client().Video.Query().Where(video.StatusEQ(status)).Count(ctx)
}

// SumFieldOverview 运营总览聚合（总量 + 播放/点赞/评论总和）
func (r *VideoRepo) SumFieldOverview(ctx context.Context) (total int, published int, views uint64, likes uint64, comments uint64, err error) {
	var sel []*ent.Video
	sel, err = r.entClient.Client().Video.Query().All(ctx)
	if err != nil {
		r.log.Errorf("sum overview failed: %s", err.Error())
		return
	}
	total = len(sel)
	for _, v := range sel {
		if v.Status == video.StatusPublished {
			published++
		}
		views += v.ViewCount
		likes += v.LikeCount
		comments += v.CommentCount
	}
	return
}

// ── 标签 ──

// TagsOfVideo 视频标签名列表
func (r *VideoRepo) TagsOfVideo(ctx context.Context, videoID uint32) ([]string, error) {
	rels, err := r.entClient.Client().VideoTagRel.Query().Where(videotagrel.VideoIDEQ(videoID)).All(ctx)
	if err != nil {
		return nil, err
	}
	if len(rels) == 0 {
		return nil, nil
	}
	tagIDs := make([]uint32, 0, len(rels))
	for _, rel := range rels {
		tagIDs = append(tagIDs, rel.TagID)
	}
	tags, err := r.entClient.Client().VideoTag.Query().Where(videotag.IDIn(tagIDs...)).All(ctx)
	if err != nil {
		return nil, err
	}
	names := make([]string, 0, len(tags))
	for _, t := range tags {
		names = append(names, t.Name)
	}
	return names, nil
}

// SetTags 覆盖式设置视频标签（标签不存在则创建；引用计数同步）
func (r *VideoRepo) SetTags(ctx context.Context, videoID uint32, tags []string) error {
	oldRels, err := r.entClient.Client().VideoTagRel.Query().Where(videotagrel.VideoIDEQ(videoID)).All(ctx)
	if err != nil {
		r.log.Errorf("query old tag rels failed: %s", err.Error())
		return videoV1.ErrorInternalServerError("query old tag rels failed")
	}
	oldTagIDs := make(map[uint32]struct{}, len(oldRels))
	for _, rel := range oldRels {
		oldTagIDs[rel.TagID] = struct{}{}
	}

	newTagIDs := make([]uint32, 0, len(tags))
	for _, name := range tags {
		if name == "" {
			continue
		}
		tag, err := r.ensureTag(ctx, name)
		if err != nil {
			return err
		}
		newTagIDs = append(newTagIDs, tag.ID)
	}

	// 删除移除的关联并扣计数
	for _, rel := range oldRels {
		if _, keep := containsUint32(newTagIDs, rel.TagID); keep {
			continue
		}
		if _, err = r.entClient.Client().VideoTagRel.Delete().Where(videotagrel.IDEQ(rel.ID)).Exec(ctx); err != nil {
			r.log.Errorf("delete tag rel failed: %s", err.Error())
			return videoV1.ErrorInternalServerError("delete tag rel failed")
		}
		if err = r.bumpTagCount(ctx, rel.TagID, -1); err != nil {
			return err
		}
	}
	// 新增关联并加计数
	for _, tagID := range newTagIDs {
		if _, exists := oldTagIDs[tagID]; exists {
			continue
		}
		if _, err = r.entClient.Client().VideoTagRel.Create().SetVideoID(videoID).SetTagID(tagID).Save(ctx); err != nil {
			r.log.Errorf("create tag rel failed: %s", err.Error())
			return videoV1.ErrorInternalServerError("create tag rel failed")
		}
		if err = r.bumpTagCount(ctx, tagID, 1); err != nil {
			return err
		}
	}
	return nil
}

func containsUint32(list []uint32, v uint32) (uint32, bool) {
	for _, item := range list {
		if item == v {
			return item, true
		}
	}
	return 0, false
}

func (r *VideoRepo) ensureTag(ctx context.Context, name string) (*ent.VideoTag, error) {
	tag, err := r.entClient.Client().VideoTag.Query().Where(videotag.NameEQ(name)).Only(ctx)
	if err == nil {
		return tag, nil
	}
	if !ent.IsNotFound(err) {
		r.log.Errorf("query tag failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("query tag failed")
	}
	tag, err = r.entClient.Client().VideoTag.Create().SetName(name).Save(ctx)
	if err != nil {
		// 并发创建冲突则回读
		tag, err = r.entClient.Client().VideoTag.Query().Where(videotag.NameEQ(name)).Only(ctx)
		if err != nil {
			r.log.Errorf("create tag failed: %s", err.Error())
			return nil, videoV1.ErrorInternalServerError("create tag failed")
		}
	}
	return tag, nil
}

func (r *VideoRepo) bumpTagCount(ctx context.Context, tagID uint32, delta int) error {
	_, err := r.entClient.Client().VideoTag.UpdateOneID(tagID).AddVideoCount(int64(delta)).Save(ctx)
	return err
}

// ListTags 标签列表（按引用数倒序）
func (r *VideoRepo) ListTags(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListTagResponse, error) {
	offs, limit := pageArgsOf(req)
	q := r.entClient.Client().VideoTag.Query().Offset(offs).Limit(limit).Order(ent.Desc(videotag.FieldVideoCount))
	items, err := q.All(ctx)
	if err != nil {
		r.log.Errorf("list tags failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("list tags failed")
	}
	total, err := r.entClient.Client().VideoTag.Query().Count(ctx)
	if err != nil {
		r.log.Errorf("count tags failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("count tags failed")
	}
	resp := &videoV1.ListTagResponse{Total: trans.Ptr(int64(total))}
	for _, t := range items {
		resp.Items = append(resp.Items, &videoV1.Tag{
			Id:         trans.Ptr(t.ID),
			Name:       trans.Ptr(t.Name),
			VideoCount: trans.Ptr(t.VideoCount),
		})
	}
	return resp, nil
}

// ── stats 排行指标内部约定 ──

// TopMetric TOP 排行指标（stats 域用）
type TopMetric int

const (
	TopMetricView TopMetric = iota
	TopMetricLike
	TopMetricCollect
	TopMetricComment
)
