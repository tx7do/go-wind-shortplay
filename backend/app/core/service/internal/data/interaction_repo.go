package data

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/userfollow"
	"go-wind-shortplay/app/core/service/internal/data/ent/videocollect"
	"go-wind-shortplay/app/core/service/internal/data/ent/videolike"
	"go-wind-shortplay/app/core/service/internal/data/ent/video"
)

// InteractionRepo 点赞 / 收藏 / 关注仓储（ledger 唯一写入方）。
//
// MVP 计数策略：ledger 与视频计数列在同一事务内增减（单行 UPDATE，小流量足够）；
// Redis 计数缓存与异步批量落库为升级路径（商业版高并发场景），接口形态不变。
type InteractionRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewInteractionRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *InteractionRepo {
	return &InteractionRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("interaction/repo/core-service"),
	}
}

func (r *InteractionRepo) Client() *ent.Client {
	return r.entClient.Client()
}

func (r *InteractionRepo) withTx(ctx context.Context, fn func(tx *ent.Tx) error) (err error) {
	tx, err := r.Client().Tx(ctx)
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
			return
		}
		err = tx.Commit()
	}()
	return fn(tx)
}

// ── 点赞 ──

// Like 点赞；返回操作后的最终状态（幂等）
func (r *InteractionRepo) Like(ctx context.Context, userID uint32, targetType, targetID uint32) (liked bool, count int64, err error) {
	exist, err := r.Client().VideoLike.Query().
		Where(videolike.UserID(userID), videolike.TargetType(uint8(targetType)), videolike.TargetID(targetID)).
		Exist(ctx)
	if err != nil {
		return false, 0, err
	}
	if exist {
		count, err = r.targetLikeCount(ctx, targetType, targetID)
		return true, count, err
	}
	err = r.withTx(ctx, func(tx *ent.Tx) error {
		if _, err := tx.VideoLike.Create().
			SetUserID(userID).
			SetTargetType(uint8(targetType)).
			SetTargetID(targetID).
			Save(ctx); err != nil {
			return err
		}
		return r.incrTargetCount(ctx, tx, targetType, targetID, 1)
	})
	if err != nil {
		return false, 0, err
	}
	count, err = r.targetLikeCount(ctx, targetType, targetID)
	return true, count, err
}

// Unlike 取消点赞（幂等）
func (r *InteractionRepo) Unlike(ctx context.Context, userID uint32, targetType, targetID uint32) (liked bool, count int64, err error) {
	n, err := r.Client().VideoLike.Delete().
		Where(videolike.UserID(userID), videolike.TargetType(uint8(targetType)), videolike.TargetID(targetID)).
		Exec(ctx)
	if err != nil {
		return false, 0, err
	}
	if n > 0 {
		if err := r.withTx(ctx, func(tx *ent.Tx) error {
			return r.incrTargetCount(ctx, tx, targetType, targetID, -1)
		}); err != nil {
			return false, 0, err
		}
	}
	count, err = r.targetLikeCount(ctx, targetType, targetID)
	return false, count, err
}

// targetLikeCount 目标当前点赞数（视频取计数列；评论取评论计数列）
func (r *InteractionRepo) targetLikeCount(ctx context.Context, targetType, targetID uint32) (int64, error) {
	if targetType == uint32(interactionV1.TargetType_TARGET_TYPE_COMMENT) {
		c, err := r.Client().VideoComment.Get(ctx, targetID)
		if err != nil {
			return 0, nil // 目标可能已删除，点赞数按 0 兜底
		}
		return derefI64(c.LikeCount), nil
	}
	v, err := r.Client().Video.Get(ctx, targetID)
	if err != nil {
		return 0, nil
	}
	return derefI64(v.LikeCount), nil
}

// incrTargetCount 在事务内增减目标点赞计数列
func (r *InteractionRepo) incrTargetCount(ctx context.Context, tx *ent.Tx, targetType, targetID uint32, delta int) error {
	if targetType == uint32(interactionV1.TargetType_TARGET_TYPE_COMMENT) {
		_, err := tx.VideoComment.UpdateOneID(targetID).AddLikeCount(int64(delta)).Save(ctx)
		return err
	}
	_, err := tx.Video.UpdateOneID(targetID).AddLikeCount(int64(delta)).Save(ctx)
	return err
}

// ── 收藏 ──

func (r *InteractionRepo) Collect(ctx context.Context, userID, videoID uint32) (collected bool, count int64, err error) {
	exist, err := r.Client().VideoCollect.Query().
		Where(videocollect.UserID(userID), videocollect.VideoID(videoID)).
		Exist(ctx)
	if err != nil {
		return false, 0, err
	}
	if exist {
		count, err = r.videoCount(ctx, videoID, video.FieldCollectCount)
		return true, count, err
	}
	err = r.withTx(ctx, func(tx *ent.Tx) error {
		if _, err := tx.VideoCollect.Create().SetUserID(userID).SetVideoID(videoID).Save(ctx); err != nil {
			return err
		}
		_, err := tx.Video.UpdateOneID(videoID).AddCollectCount(1).Save(ctx)
		return err
	})
	if err != nil {
		return false, 0, err
	}
	count, err = r.videoCount(ctx, videoID, video.FieldCollectCount)
	return true, count, err
}

func (r *InteractionRepo) Uncollect(ctx context.Context, userID, videoID uint32) (collected bool, count int64, err error) {
	n, err := r.Client().VideoCollect.Delete().
		Where(videocollect.UserID(userID), videocollect.VideoID(videoID)).
		Exec(ctx)
	if err != nil {
		return false, 0, err
	}
	if n > 0 {
		if err := r.withTx(ctx, func(tx *ent.Tx) error {
			_, err := tx.Video.UpdateOneID(videoID).AddCollectCount(-1).Save(ctx)
			return err
		}); err != nil {
			return false, 0, err
		}
	}
	count, err = r.videoCount(ctx, videoID, video.FieldCollectCount)
	return false, count, err
}

func (r *InteractionRepo) videoCount(ctx context.Context, videoID uint32, field string) (int64, error) {
	v, err := r.Client().Video.Query().Where(video.ID(videoID)).Only(ctx)
	if err != nil {
		return 0, nil
	}
	switch field {
	case video.FieldCollectCount:
		return derefI64(v.CollectCount), nil
	case video.FieldViewCount:
		return derefI64(v.ViewCount), nil
	default:
		return derefI64(v.LikeCount), nil
	}
}

// GetInteractionStatus 批量查询 viewer 对视频的点赞 / 收藏状态
func (r *InteractionRepo) GetInteractionStatus(ctx context.Context, userID uint32, videoIDs []uint32) (map[uint32]bool, map[uint32]bool, error) {
	liked := make(map[uint32]bool, len(videoIDs))
	collected := make(map[uint32]bool, len(videoIDs))
	if userID == 0 || len(videoIDs) == 0 {
		return liked, collected, nil
	}
	likes, err := r.Client().VideoLike.Query().
		Where(videolike.UserID(userID), videolike.TargetType(uint8(interactionV1.TargetType_TARGET_TYPE_VIDEO)), videolike.TargetIDIn(videoIDs...)).
		All(ctx)
	if err != nil {
		return nil, nil, err
	}
	for _, l := range likes {
		if l.TargetID != nil {
		liked[*l.TargetID] = true
	}
	}
	collects, err := r.Client().VideoCollect.Query().
		Where(videocollect.UserID(userID), videocollect.VideoIDIn(videoIDs...)).
		All(ctx)
	if err != nil {
		return nil, nil, err
	}
	for _, c := range collects {
		if c.VideoID != nil {
		collected[*c.VideoID] = true
	}
	}
	return liked, collected, nil
}

// CollectedVideoIDs 我的收藏视频ID（按收藏时间倒序分页）
func (r *InteractionRepo) CollectedVideoIDs(ctx context.Context, userID uint32, offset, limit int) ([]uint32, int, error) {
	q := r.Client().VideoCollect.Query().Where(videocollect.UserID(userID))
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Desc(videocollect.FieldCreatedAt)).Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	ids := make([]uint32, 0, len(items))
	for _, it := range items {
		if it.VideoID != nil {
		ids = append(ids, *it.VideoID)
	}
	}
	return ids, total, nil
}

// ── 关注 ──

func (r *InteractionRepo) Follow(ctx context.Context, followerID, followeeID uint32) (bool, error) {
	if followerID == followeeID {
		return false, nil
	}
	exist, err := r.Client().UserFollow.Query().
		Where(userfollow.FollowerID(followerID), userfollow.FolloweeID(followeeID)).
		Exist(ctx)
	if err != nil {
		return false, err
	}
	if exist {
		return true, nil
	}
	_, err = r.Client().UserFollow.Create().SetFollowerID(followerID).SetFolloweeID(followeeID).Save(ctx)
	if err != nil {
		return false, err
	}
	return true, nil
}

func (r *InteractionRepo) Unfollow(ctx context.Context, followerID, followeeID uint32) (bool, error) {
	n, err := r.Client().UserFollow.Delete().
		Where(userfollow.FollowerID(followerID), userfollow.FolloweeID(followeeID)).
		Exec(ctx)
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

func (r *InteractionRepo) GetFollowStatus(ctx context.Context, followerID uint32, followeeIDs []uint32) (map[uint32]bool, error) {
	res := make(map[uint32]bool, len(followeeIDs))
	if followerID == 0 || len(followeeIDs) == 0 {
		return res, nil
	}
	items, err := r.Client().UserFollow.Query().
		Where(userfollow.FollowerID(followerID), userfollow.FolloweeIDIn(followeeIDs...)).
		All(ctx)
	if err != nil {
		return nil, err
	}
	for _, it := range items {
		if it.FolloweeID != nil {
		res[*it.FolloweeID] = true
	}
	}
	return res, nil
}

// FollowList 关注 / 粉丝列表。byFollowee=true 时查粉丝（followee=followeeID），否则查关注。
func (r *InteractionRepo) FollowList(ctx context.Context, userID uint32, byFollowee bool, offset, limit int) ([]*ent.UserFollow, int, error) {
	q := r.Client().UserFollow.Query()
	if byFollowee {
		q = q.Where(userfollow.FolloweeID(userID))
	} else {
		q = q.Where(userfollow.FollowerID(userID))
	}
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Desc(userfollow.FieldCreatedAt)).Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

// FollowCounts 用户的关注数 / 粉丝数
func (r *InteractionRepo) FollowCounts(ctx context.Context, userID uint32) (following, followers int, err error) {
	following, err = r.Client().UserFollow.Query().Where(userfollow.FollowerID(userID)).Count(ctx)
	if err != nil {
		return 0, 0, err
	}
	followers, err = r.Client().UserFollow.Query().Where(userfollow.FolloweeID(userID)).Count(ctx)
	if err != nil {
		return 0, 0, err
	}
	return following, followers, nil
}

// FollowingAuthorIDs 关注的作者ID列表（Feed 召回用）
func (r *InteractionRepo) FollowingAuthorIDs(ctx context.Context, userID uint32, limit int) ([]uint32, error) {
	items, err := r.Client().UserFollow.Query().
		Where(userfollow.FollowerID(userID)).
		Order(ent.Desc(userfollow.FieldCreatedAt)).
		Limit(limit).
		All(ctx)
	if err != nil {
		return nil, err
	}
	ids := make([]uint32, 0, len(items))
	for _, it := range items {
		if it.FolloweeID != nil {
			ids = append(ids, *it.FolloweeID)
		}
	}
	return ids, nil
}

// derefI64 可空 int64 取值
func derefI64(p *int64) int64 {
	if p == nil {
		return 0
	}
	return *p
}
