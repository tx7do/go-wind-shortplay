package data

import (
	"context"
	"encoding/json"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/go-utils/timeutil"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/danmaku"
	"go-wind-shortplay/app/core/service/internal/data/ent/predicate"

	danmakuV1 "go-wind-shortplay/api/gen/go/danmaku/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
)

// spDanmakuVideoListCap 视频弹幕单次拉取上限（防巨量拉爆；超出按 time_offset 截断到上限内）
const spDanmakuVideoListCap = 1000

// danmakuStatusEntity proto 状态 → ent 枚举
func danmakuStatusEntity(s danmakuV1.DanmakuStatus) danmaku.Status {
	if s == danmakuV1.DanmakuStatus_DANMAKU_STATUS_HIDDEN {
		return danmaku.StatusHidden
	}
	return danmaku.StatusVisible
}

// danmakuStatusDTO ent 枚举 → proto 状态
func danmakuStatusDTO(s danmaku.Status) danmakuV1.DanmakuStatus {
	if s == danmaku.StatusHidden {
		return danmakuV1.DanmakuStatus_DANMAKU_STATUS_HIDDEN
	}
	return danmakuV1.DanmakuStatus_DANMAKU_STATUS_VISIBLE
}

func DanmakuEntityToDTO(e *ent.Danmaku, user *identityV1.UserBrief) *danmakuV1.Danmaku {
	if e == nil {
		return nil
	}
	return &danmakuV1.Danmaku{
		Id:           trans.Ptr(e.ID),
		VideoId:      trans.Ptr(e.VideoID),
		UserId:       trans.Ptr(e.UserID),
		User:         user,
		Content:      trans.Ptr(e.Content),
		TimeOffsetMs: trans.Ptr(e.TimeOffsetMs),
		Status:       danmakuStatusDTO(e.Status).Enum(),
		CreatedAt:    timeutil.TimeToTimestamppb(e.CreatedAt),
	}
}

type DanmakuRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewDanmakuRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *DanmakuRepo {
	return &DanmakuRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("danmaku/repo/core-service"),
	}
}

// Create 落一条弹幕
func (r *DanmakuRepo) Create(ctx context.Context, videoID, userID int64, content string, timeOffsetMs int64) (*ent.Danmaku, error) {
	builder := r.entClient.Client().Danmaku.Create().
		SetVideoID(videoID).
		SetUserID(userID).
		SetContent(content).
		SetTimeOffsetMs(uint64(timeOffsetMs)).
		SetStatus(danmaku.StatusVisible).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	e, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("create danmaku failed: %s", err.Error())
		return nil, danmakuV1.ErrorInternalServerError("create danmaku failed")
	}
	return e, nil
}

// ListByVideo 视频弹幕（VISIBLE，按 time_offset 升序、id 兜底；超上限截断）
func (r *DanmakuRepo) ListByVideo(ctx context.Context, videoID int64, limit int64) ([]*ent.Danmaku, int, error) {
	if limit <= 0 {
		limit = 500
	}
	if limit > spDanmakuVideoListCap {
		limit = spDanmakuVideoListCap
	}
	total, err := r.entClient.Client().Danmaku.Query().
		Where(danmaku.VideoIDEQ(videoID), danmaku.StatusEQ(danmaku.StatusVisible)).
		Count(ctx)
	if err != nil {
		r.log.Errorf("count danmaku failed: %s", err.Error())
		return nil, 0, danmakuV1.ErrorInternalServerError("list danmaku failed")
	}
	items, err := r.entClient.Client().Danmaku.Query().
		Where(danmaku.VideoIDEQ(videoID), danmaku.StatusEQ(danmaku.StatusVisible)).
		Order(ent.Asc(danmaku.FieldTimeOffsetMs), ent.Asc(danmaku.FieldID)).
		Limit(int(limit)).
		All(ctx)
	if err != nil {
		r.log.Errorf("list danmaku failed: %s", err.Error())
		return nil, 0, danmakuV1.ErrorInternalServerError("list danmaku failed")
	}
	return items, total, nil
}

// spDanmakuAdminFilter 管理端弹幕列表过滤
type spDanmakuAdminFilter struct {
	Content *string `json:"content___icontains"`
	VideoID *int64  `json:"video_id"`
	Status  *string `json:"status"`
}

// ListAdmin 管理端全量弹幕列表（分页 + videoId/status/content 过滤）
func (r *DanmakuRepo) ListAdmin(ctx context.Context, req *paginationV1.PagingRequest) (*danmakuV1.ListDanmakuResponse, error) {
	page, pageSize := pageArgsOf(req)

	var ps []predicate.Danmaku
	if req.GetQuery() != "" {
		var f spDanmakuAdminFilter
		if err := json.Unmarshal([]byte(req.GetQuery()), &f); err == nil {
			if f.Content != nil && *f.Content != "" {
				ps = append(ps, danmaku.ContentContainsFold(*f.Content))
			}
			if f.VideoID != nil && *f.VideoID > 0 {
				ps = append(ps, danmaku.VideoIDEQ(*f.VideoID))
			}
			if f.Status != nil && *f.Status != "" {
				switch *f.Status {
				case "DANMAKU_STATUS_HIDDEN":
					ps = append(ps, danmaku.StatusEQ(danmaku.StatusHidden))
				case "DANMAKU_STATUS_VISIBLE":
					ps = append(ps, danmaku.StatusEQ(danmaku.StatusVisible))
				}
			}
		}
	}

	q := r.entClient.Client().Danmaku.Query()
	if len(ps) > 0 {
		q.Where(ps...)
	}
	total, err := q.Count(ctx)
	if err != nil {
		r.log.Errorf("count danmaku failed: %s", err.Error())
		return nil, danmakuV1.ErrorInternalServerError("count danmaku failed")
	}
	items, err := q.Order(ent.Desc(danmaku.FieldID)).
		Offset(page).Limit(pageSize).All(ctx)
	if err != nil {
		r.log.Errorf("list danmaku failed: %s", err.Error())
		return nil, danmakuV1.ErrorInternalServerError("list danmaku failed")
	}
	resp := &danmakuV1.ListDanmakuResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		resp.Items = append(resp.Items, DanmakuEntityToDTO(e, nil))
	}
	return resp, nil
}

// Get 取单条（服务层归属判断用）
func (r *DanmakuRepo) Get(ctx context.Context, id int64) (*ent.Danmaku, error) {
	e, err := r.entClient.Client().Danmaku.Query().Where(danmaku.IDEQ(id)).Only(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, danmakuV1.ErrorDanmakuNotFound("danmaku not found")
		}
		r.log.Errorf("get danmaku failed: %s", err.Error())
		return nil, danmakuV1.ErrorInternalServerError("get danmaku failed")
	}
	return e, nil
}

// Delete 删除弹幕
func (r *DanmakuRepo) Delete(ctx context.Context, id int64) error {
	if err := r.entClient.Client().Danmaku.DeleteOneID(id).Exec(ctx); err != nil {
		if ent.IsNotFound(err) {
			return danmakuV1.ErrorDanmakuNotFound("danmaku not found")
		}
		r.log.Errorf("delete danmaku failed: %s", err.Error())
		return danmakuV1.ErrorInternalServerError("delete danmaku failed")
	}
	return nil
}

// SetStatus 隐藏/恢复弹幕
func (r *DanmakuRepo) SetStatus(ctx context.Context, id int64, status danmakuV1.DanmakuStatus) (*ent.Danmaku, error) {
	e, err := r.entClient.Client().Danmaku.UpdateOneID(id).
		SetStatus(danmakuStatusEntity(status)).
		SetUpdatedAt(time.Now()).
		Save(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, danmakuV1.ErrorDanmakuNotFound("danmaku not found")
		}
		r.log.Errorf("set danmaku status failed: %s", err.Error())
		return nil, danmakuV1.ErrorInternalServerError("set danmaku status failed")
	}
	return e, nil
}

// UserIDsOf 批量补全发送人昵称头像用（取一页弹幕的去重用户 ID）
func (r *DanmakuRepo) UserIDsOf(items []*ent.Danmaku) []int64 {
	ids := make(map[int64]struct{}, len(items))
	for _, e := range items {
		if e.UserID > 0 {
			ids[e.UserID] = struct{}{}
		}
	}
	out := make([]int64, 0, len(ids))
	for id := range ids {
		out = append(out, id)
	}
	return out
}
