package data

import (
	"context"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/seriesfollow"

	seriesV1 "go-wind-shortplay/api/gen/go/series/service/v1"
)

// spSeriesFollowNotifyCap 追剧更新通知单次 fan-out 人数上限（开源版防巨量 fan-out）
const spSeriesFollowNotifyCap = 200

type SeriesFollowRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewSeriesFollowRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *SeriesFollowRepo {
	return &SeriesFollowRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("series-follow/repo/core-service"),
	}
}

// Follow 追剧（幂等）。返回是否新建了关系。
func (r *SeriesFollowRepo) Follow(ctx context.Context, followerID, seriesID int64) (bool, error) {
	exists, err := r.entClient.Client().SeriesFollow.Query().
		Where(seriesfollow.FollowerIDEQ(followerID), seriesfollow.SeriesIDEQ(seriesID)).
		Exist(ctx)
	if err != nil {
		r.log.Errorf("check series follow failed: %s", err.Error())
		return false, seriesV1.ErrorInternalServerError("follow series failed")
	}
	if exists {
		return false, nil
	}
	builder := r.entClient.Client().SeriesFollow.Create().
		SetFollowerID(followerID).
		SetSeriesID(seriesID).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	if _, err := builder.Save(ctx); err != nil {
		r.log.Errorf("follow series failed: %s", err.Error())
		return false, seriesV1.ErrorInternalServerError("follow series failed")
	}
	return true, nil
}

// Unfollow 取消追剧（幂等）。返回是否真的删除了关系。
func (r *SeriesFollowRepo) Unfollow(ctx context.Context, followerID, seriesID int64) (bool, error) {
	n, err := r.entClient.Client().SeriesFollow.Delete().
		Where(seriesfollow.FollowerIDEQ(followerID), seriesfollow.SeriesIDEQ(seriesID)).
		Exec(ctx)
	if err != nil {
		r.log.Errorf("unfollow series failed: %s", err.Error())
		return false, seriesV1.ErrorInternalServerError("unfollow series failed")
	}
	return n > 0, nil
}

// FollowerCount 剧集追剧人数
func (r *SeriesFollowRepo) FollowerCount(ctx context.Context, seriesID int64) (int, error) {
	return r.entClient.Client().SeriesFollow.Query().
		Where(seriesfollow.SeriesIDEQ(seriesID)).
		Count(ctx)
}

// FollowerCounts 批量追剧人数
func (r *SeriesFollowRepo) FollowerCounts(ctx context.Context, seriesIDs []int64) (map[int64]int, error) {
	out := make(map[int64]int, len(seriesIDs))
	if len(seriesIDs) == 0 {
		return out, nil
	}
	rows, err := r.entClient.Client().SeriesFollow.Query().
		Where(seriesfollow.SeriesIDIn(seriesIDs...)).
		All(ctx)
	if err != nil {
		return nil, err
	}
	for _, row := range rows {
		out[row.SeriesID]++
	}
	return out, nil
}

// GetFollowStatus 批量追剧状态（viewer → 剧集）
func (r *SeriesFollowRepo) GetFollowStatus(ctx context.Context, followerID int64, seriesIDs []int64) (map[int64]bool, error) {
	out := make(map[int64]bool, len(seriesIDs))
	if followerID == 0 || len(seriesIDs) == 0 {
		return out, nil
	}
	rows, err := r.entClient.Client().SeriesFollow.Query().
		Where(seriesfollow.FollowerIDEQ(followerID), seriesfollow.SeriesIDIn(seriesIDs...)).
		All(ctx)
	if err != nil {
		return nil, err
	}
	for _, row := range rows {
		out[row.SeriesID] = true
	}
	return out, nil
}

// FollowedSeriesIDs 追剧的剧集 ID 列表（按追剧时间倒序）
func (r *SeriesFollowRepo) FollowedSeriesIDs(ctx context.Context, followerID int64, limit int) ([]int64, error) {
	rows, err := r.entClient.Client().SeriesFollow.Query().
		Where(seriesfollow.FollowerIDEQ(followerID)).
		Order(ent.Desc(seriesfollow.FieldCreatedAt)).
		Limit(limit).All(ctx)
	if err != nil {
		return nil, err
	}
	ids := make([]int64, 0, len(rows))
	for _, row := range rows {
		ids = append(ids, row.SeriesID)
	}
	return ids, nil
}

// FollowerUserIDs 剧集的追剧人 ID 列表（更新通知 fan-out 用，截断到上限）
func (r *SeriesFollowRepo) FollowerUserIDs(ctx context.Context, seriesID int64) []int64 {
	rows, err := r.entClient.Client().SeriesFollow.Query().
		Where(seriesfollow.SeriesIDEQ(seriesID)).
		Order(ent.Desc(seriesfollow.FieldCreatedAt)).
		Limit(spSeriesFollowNotifyCap).
		All(ctx)
	if err != nil {
		r.log.Errorf("list series followers failed: %s", err.Error())
		return nil
	}
	ids := make([]int64, 0, len(rows))
	for _, row := range rows {
		ids = append(ids, row.FollowerID)
	}
	return ids
}
