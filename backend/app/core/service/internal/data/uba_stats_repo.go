package data

import (
	"context"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/video"
)

// UbaRepo 行为埋点事件仓储（尽力写入，不阻塞播放链路）
type UbaRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewUbaRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *UbaRepo {
	return &UbaRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("uba/repo/core-service"),
	}
}

func (r *UbaRepo) Client() *ent.Client {
	return r.entClient.Client()
}

// UbaEventRow 单条事件写入参数
type UbaEventRow struct {
	EventType    uint8
	VideoID      uint32
	UserID       uint32
	TargetUserID uint32
	DurationMs   int64
	WatchPercent uint32
	Extra        *string
	OccurredAt   time.Time
}

func (r *UbaRepo) InsertBatch(ctx context.Context, rows []UbaEventRow) error {
	if len(rows) == 0 {
		return nil
	}
	bulk := make([]*ent.UbaEventCreate, 0, len(rows))
	for i := range rows {
		bulk = append(bulk, r.Client().UbaEvent.Create().
			SetEventType(rows[i].EventType).
			SetVideoID(rows[i].VideoID).
			SetUserID(rows[i].UserID).
			SetTargetUserID(rows[i].TargetUserID).
			SetDurationMs(rows[i].DurationMs).
			SetWatchPercent(rows[i].WatchPercent).
			SetNillableExtra(rows[i].Extra).
			SetOccurredAt(rows[i].OccurredAt),
		)
	}
	if _, err := r.Client().UbaEvent.CreateBulk(bulk...).Save(ctx); err != nil {
		r.log.Errorf("uba insert batch failed: %s", err.Error())
	}
	return nil
}

// StatsRepo 数据看板聚合（直接对主表 COUNT/SUM，小流量够用）
type StatsRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewStatsRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *StatsRepo {
	return &StatsRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("stats/repo/core-service"),
	}
}

func (r *StatsRepo) Client() *ent.Client {
	return r.entClient.Client()
}

type Overview struct {
	TotalVideos      int
	PublishedVideos  int
	TotalViews       int64
	TotalLikes       int64
	TotalComments    int
	TotalUsers       int
	TodayPublished   int
}

func (r *StatsRepo) GetOverview(ctx context.Context) (*Overview, error) {
	o := &Overview{}
	var err error
	if o.TotalVideos, err = r.Client().Video.Query().Count(ctx); err != nil {
		return nil, err
	}
	if o.PublishedVideos, err = r.Client().Video.Query().Where(video.Status(3)).Count(ctx); err != nil {
		return nil, err
	}
	if o.TotalComments, err = r.Client().VideoComment.Query().Count(ctx); err != nil {
		return nil, err
	}
	if o.TotalUsers, err = r.Client().User.Query().Count(ctx); err != nil {
		return nil, err
	}
	todayStart := time.Now().Truncate(24 * time.Hour)
	if o.TodayPublished, err = r.Client().Video.Query().Where(video.PublishedAtGTE(todayStart)).Count(ctx); err != nil {
		return nil, err
	}
	if o.TotalViews, err = sumColumn(ctx, r.Client().Video.Query(), video.FieldViewCount); err != nil {
		return nil, err
	}
	if o.TotalLikes, err = sumColumn(ctx, r.Client().Video.Query(), video.FieldLikeCount); err != nil {
		return nil, err
	}
	return o, nil
}

// CreatorOverview 创作者中心总览（本人已发布作品聚合）
type CreatorOverview struct {
	VideoCount    int
	TotalViews    int64
	TotalLikes    int64
	TotalCollects int64
	TotalComments int64
}

// GetCreatorOverview 聚合本人已发布作品的播放 / 点赞 / 收藏 / 评论
func (r *StatsRepo) GetCreatorOverview(ctx context.Context, userID uint32) (*CreatorOverview, error) {
	o := &CreatorOverview{}
	mine := func() *ent.VideoQuery {
		return r.Client().Video.Query().Where(video.AuthorID(userID), video.Status(uint8(3)))
	}
	var err error
	if o.VideoCount, err = mine().Count(ctx); err != nil {
		return nil, err
	}
	if o.TotalViews, err = sumColumn(ctx, mine(), video.FieldViewCount); err != nil {
		return nil, err
	}
	if o.TotalLikes, err = sumColumn(ctx, mine(), video.FieldLikeCount); err != nil {
		return nil, err
	}
	if o.TotalCollects, err = sumColumn(ctx, mine(), video.FieldCollectCount); err != nil {
		return nil, err
	}
	if o.TotalComments, err = sumColumn(ctx, mine(), video.FieldCommentCount); err != nil {
		return nil, err
	}
	return o, nil
}
