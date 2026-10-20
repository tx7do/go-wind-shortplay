package data

import (
	"context"
	"time"

	"entgo.io/ent/dialect/sql"
	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/sysconfig"
	"go-wind-shortplay/app/core/service/internal/data/ent/ubaevent"

	sysconfV1 "go-wind-shortplay/api/gen/go/sysconf/service/v1"
	ubaV1 "go-wind-shortplay/api/gen/go/uba/service/v1"
)

// ── 系统配置（单行表，懒播种 id=1）──

type SysConfRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewSysConfRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *SysConfRepo {
	return &SysConfRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("sysconf/repo/core-service"),
	}
}

// GetEnsure 读取配置；首行不存在时以默认值播种（幂等）。
func (r *SysConfRepo) GetEnsure(ctx context.Context) (*ent.SysConfig, error) {
	e, err := r.entClient.Client().SysConfig.Query().Where(sysconfig.IDEQ(1)).Only(ctx)
	if err == nil {
		return e, nil
	}
	if !ent.IsNotFound(err) {
		r.log.Errorf("get sysconf failed: %s", err.Error())
		return nil, sysconfV1.ErrorInternalServerError("get sysconf failed")
	}
	e, err = r.entClient.Client().SysConfig.Create().
		SetID(1).
		SetMaxUploadSizeMB(500).
		SetMaxDurationSeconds(600).
		SetManualReviewEnabled(false).
		SetRegisterEnabled(true).
		SetAllowedVideoTypes([]string{".mp4", ".mov", ".m4v", ".webm"}).
		SetCreatedAt(time.Now()).
		Save(ctx)
	if err != nil {
		// 并发播种冲突回读
		if e, err = r.entClient.Client().SysConfig.Query().Where(sysconfig.IDEQ(1)).Only(ctx); err == nil {
			return e, nil
		}
		r.log.Errorf("seed sysconf failed: %s", err.Error())
		return nil, sysconfV1.ErrorInternalServerError("seed sysconf failed")
	}
	return e, nil
}

func (r *SysConfRepo) Update(ctx context.Context, maxUploadMB, maxDuration *uint32, manualReview, register *bool, types []string) (*ent.SysConfig, error) {
	if _, err := r.GetEnsure(ctx); err != nil {
		return nil, err
	}
	builder := r.entClient.Client().SysConfig.UpdateOneID(1).SetUpdatedAt(time.Now())
	if maxUploadMB != nil {
		builder.SetMaxUploadSizeMB(*maxUploadMB)
	}
	if maxDuration != nil {
		builder.SetMaxDurationSeconds(*maxDuration)
	}
	if manualReview != nil {
		builder.SetManualReviewEnabled(*manualReview)
	}
	if register != nil {
		builder.SetRegisterEnabled(*register)
	}
	if types != nil {
		builder.SetAllowedVideoTypes(types)
	}
	e, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("update sysconf failed: %s", err.Error())
		return nil, sysconfV1.ErrorInternalServerError("update sysconf failed")
	}
	return e, nil
}

// ── UBA 事件 ──

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

func ubaEventTypeEntity(t ubaV1.EventType) ubaevent.EventType {
	switch t {
	case ubaV1.EventType_EVENT_TYPE_VIDEO_HEARTBEAT:
		return ubaevent.EventTypeVideoHeartbeat
	case ubaV1.EventType_EVENT_TYPE_VIDEO_COMPLETE:
		return ubaevent.EventTypeVideoComplete
	case ubaV1.EventType_EVENT_TYPE_VIDEO_SWIPE_AWAY:
		return ubaevent.EventTypeVideoSwipeAway
	case ubaV1.EventType_EVENT_TYPE_VIDEO_LIKE:
		return ubaevent.EventTypeVideoLike
	case ubaV1.EventType_EVENT_TYPE_VIDEO_COLLECT:
		return ubaevent.EventTypeVideoCollect
	case ubaV1.EventType_EVENT_TYPE_COMMENT_CREATE:
		return ubaevent.EventTypeCommentCreate
	case ubaV1.EventType_EVENT_TYPE_FOLLOW_AUTHOR:
		return ubaevent.EventTypeFollowAuthor
	default:
		return ubaevent.EventTypeVideoPlay
	}
}

// CreateBatch 批量落库（尽力而为：单条失败不中断整批）
func (r *UbaRepo) CreateBatch(ctx context.Context, userID uint32, events []*ubaV1.UbaEvent) (int, error) {
	saved := 0
	for _, ev := range events {
		if ev == nil {
			continue
		}
		builder := r.entClient.Client().UbaEvent.Create().
			SetUserID(userID).
			SetEventType(ubaEventTypeEntity(ev.GetEventType())).
			SetVideoID(ev.GetVideoId()).
			SetTargetUserID(ev.GetTargetUserId()).
			SetDurationMs(ev.GetDurationMs()).
			SetWatchPercent(ev.GetWatchPercent()).
			SetNillableExtra(ev.Extra).
			SetNillableOccurredAt(timePtrOfUba(ev.OccurredAt.AsTime(), ev.OccurredAt != nil)).
			SetCreatedAt(time.Now())
		if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
			builder.SetTenantID(tid)
		}
		if _, err := builder.Save(ctx); err != nil {
			r.log.Errorf("save uba event failed: %s", err.Error())
			continue
		}
		saved++
	}
	return saved, nil
}

func timePtrOfUba(t time.Time, ok bool) *time.Time {
	if !ok {
		return nil
	}
	return &t
}

// WatchedVideo 观看历史条目（派生自播放事件聚合）
type WatchedVideo struct {
	VideoID   uint32
	WatchedAt time.Time
}

// ListWatchHistoryPage 观看历史分页：用户 VIDEO_PLAY 事件按视频聚合，
// 最近观看时间倒序（occurred_at 优先、created_at 兜底）。返回当页 + 去重视频总数。
func (r *UbaRepo) ListWatchHistoryPage(ctx context.Context, userID uint32, offset, limit int) ([]WatchedVideo, int, error) {
	base := r.entClient.Client().UbaEvent.Query().
		Where(
			ubaevent.UserIDEQ(userID),
			ubaevent.EventTypeEQ(ubaevent.EventTypeVideoPlay),
			ubaevent.VideoIDGT(0),
		)

	// 单用户看过的视频量级小，一次聚合全量取回后内存分页
	var rows []struct {
		VideoID   uint32     `json:"video_id"`
		WatchedAt *time.Time `json:"watched_at"`
	}
	err := base.Modify(func(s *sql.Selector) {
		s.Select(
			"video_id",
			"MAX(COALESCE(occurred_at, created_at)) AS watched_at",
		).GroupBy("video_id").OrderBy(sql.Desc("watched_at"))
	}).Scan(ctx, &rows)
	if err != nil {
		r.log.Errorf("list watch history failed: %s", err.Error())
		return nil, 0, err
	}
	total := len(rows)
	if offset >= total {
		return nil, total, nil
	}
	end := offset + limit
	if end > total {
		end = total
	}
	out := make([]WatchedVideo, 0, end-offset)
	for _, row := range rows[offset:end] {
		watched := time.Time{}
		if row.WatchedAt != nil {
			watched = *row.WatchedAt
		}
		out = append(out, WatchedVideo{VideoID: row.VideoID, WatchedAt: watched})
	}
	return out, total, nil
}
