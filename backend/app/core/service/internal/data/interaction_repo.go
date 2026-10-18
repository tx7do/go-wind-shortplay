package data

import (
	"context"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/userfollow"
	"go-wind-shortplay/app/core/service/internal/data/ent/videocollect"
	"go-wind-shortplay/app/core/service/internal/data/ent/videolike"

	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
)

// InteractionRepo 互动台账仓储：点赞 / 收藏 / 关注。
// 计数列只能随台账行在同一事务内增减（见 InteractionService）。
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

func likeTargetEntity(t interactionV1.TargetType) videolike.TargetType {
	if t == interactionV1.TargetType_TARGET_TYPE_COMMENT {
		return videolike.TargetTypeComment
	}
	return videolike.TargetTypeVideo
}

// ExistsLike 是否已点赞
func (r *InteractionRepo) ExistsLike(ctx context.Context, userID uint32, t interactionV1.TargetType, targetID uint32) (bool, error) {
	return r.entClient.Client().VideoLike.Query().
		Where(
			videolike.UserIDEQ(userID),
			videolike.TargetTypeEQ(likeTargetEntity(t)),
			videolike.TargetIDEQ(targetID),
		).Exist(ctx)
}

// CreateLike 点赞入账（存在则 no-op 返回 false）
func (r *InteractionRepo) CreateLike(ctx context.Context, userID uint32, t interactionV1.TargetType, targetID uint32) (bool, error) {
	exist, err := r.ExistsLike(ctx, userID, t, targetID)
	if err != nil {
		return false, err
	}
	if exist {
		return false, nil
	}
	builder := r.entClient.Client().VideoLike.Create().
		SetUserID(userID).
		SetTargetType(likeTargetEntity(t)).
		SetTargetID(targetID).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	if _, err := builder.Save(ctx); err != nil {
		r.log.Errorf("create like failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("create like failed")
	}
	return true, nil
}

// DeleteLike 取消点赞（不存在则 no-op 返回 false）
func (r *InteractionRepo) DeleteLike(ctx context.Context, userID uint32, t interactionV1.TargetType, targetID uint32) (bool, error) {
	n, err := r.entClient.Client().VideoLike.Delete().
		Where(
			videolike.UserIDEQ(userID),
			videolike.TargetTypeEQ(likeTargetEntity(t)),
			videolike.TargetIDEQ(targetID),
		).Exec(ctx)
	if err != nil {
		r.log.Errorf("delete like failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("delete like failed")
	}
	return n > 0, nil
}

// CountLikesOfTarget 目标当前点赞总数
func (r *InteractionRepo) CountLikesOfTarget(ctx context.Context, t interactionV1.TargetType, targetID uint32) (int, error) {
	return r.entClient.Client().VideoLike.Query().
		Where(videolike.TargetTypeEQ(likeTargetEntity(t)), videolike.TargetIDEQ(targetID)).
		Count(ctx)
}

// ── 台账事务：行入账 + 计数增减同事务提交（全仓铁律 5）──

// LikeVideoWithCounter 视频点赞：台账行 + like_count 同事务。
func (r *InteractionRepo) LikeVideoWithCounter(ctx context.Context, userID, videoID uint32) (liked bool, likeCount int64, err error) {
	tx, terr := r.entClient.Client().Tx(ctx)
	if terr != nil {
		return false, 0, interactionV1.ErrorInternalServerError("start transaction failed")
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
			return
		}
		err = tx.Commit()
	}()

	exist, err := r.ExistsLike(ctx, userID, interactionV1.TargetType_TARGET_TYPE_VIDEO, videoID)
	if err != nil {
		return false, 0, err
	}
	if exist {
		return false, 0, nil
	}
	builder := tx.VideoLike.Create().
		SetUserID(userID).
		SetTargetType(videolike.TargetTypeVideo).
		SetTargetID(videoID).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	if _, err = builder.Save(ctx); err != nil {
		r.log.Errorf("create like failed: %s", err.Error())
		return false, 0, interactionV1.ErrorInternalServerError("create like failed")
	}

	if err = tx.Video.UpdateOneID(videoID).AddLikeCount(1).Exec(ctx); err != nil {
		r.log.Errorf("inc like count failed: %s", err.Error())
		return false, 0, interactionV1.ErrorInternalServerError("inc like count failed")
	}
	return true, 0, nil
}

// UnlikeVideoWithCounter 视频取消点赞：删台账行 + like_count 同事务。
func (r *InteractionRepo) UnlikeVideoWithCounter(ctx context.Context, userID, videoID uint32) (removed bool, err error) {
	tx, terr := r.entClient.Client().Tx(ctx)
	if terr != nil {
		return false, interactionV1.ErrorInternalServerError("start transaction failed")
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
			return
		}
		err = tx.Commit()
	}()

	n, err := tx.VideoLike.Delete().
		Where(
			videolike.UserIDEQ(userID),
			videolike.TargetTypeEQ(videolike.TargetTypeVideo),
			videolike.TargetIDEQ(videoID),
		).Exec(ctx)
	if err != nil {
		r.log.Errorf("delete like failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("delete like failed")
	}
	if n == 0 {
		return false, nil
	}
	if err = tx.Video.UpdateOneID(videoID).AddLikeCount(-1).Exec(ctx); err != nil {
		r.log.Errorf("dec like count failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("dec like count failed")
	}
	return true, nil
}

// LikeCommentWithCounter 评论点赞：台账行 + 评论 like_count 同事务。
func (r *InteractionRepo) LikeCommentWithCounter(ctx context.Context, userID, commentID uint32) (liked bool, err error) {
	tx, terr := r.entClient.Client().Tx(ctx)
	if terr != nil {
		return false, interactionV1.ErrorInternalServerError("start transaction failed")
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
			return
		}
		err = tx.Commit()
	}()

	exist, err := r.ExistsLike(ctx, userID, interactionV1.TargetType_TARGET_TYPE_COMMENT, commentID)
	if err != nil {
		return false, err
	}
	if exist {
		return false, nil
	}
	builder := tx.VideoLike.Create().
		SetUserID(userID).
		SetTargetType(videolike.TargetTypeComment).
		SetTargetID(commentID).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	if _, err = builder.Save(ctx); err != nil {
		r.log.Errorf("create comment like failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("create like failed")
	}
	if err = tx.VideoComment.UpdateOneID(commentID).AddLikeCount(1).Exec(ctx); err != nil {
		r.log.Errorf("inc comment like count failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("inc like count failed")
	}
	return true, nil
}

// UnlikeCommentWithCounter 评论取消点赞。
func (r *InteractionRepo) UnlikeCommentWithCounter(ctx context.Context, userID, commentID uint32) (removed bool, err error) {
	tx, terr := r.entClient.Client().Tx(ctx)
	if terr != nil {
		return false, interactionV1.ErrorInternalServerError("start transaction failed")
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
			return
		}
		err = tx.Commit()
	}()

	n, err := tx.VideoLike.Delete().
		Where(
			videolike.UserIDEQ(userID),
			videolike.TargetTypeEQ(videolike.TargetTypeComment),
			videolike.TargetIDEQ(commentID),
		).Exec(ctx)
	if err != nil {
		r.log.Errorf("delete comment like failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("delete like failed")
	}
	if n == 0 {
		return false, nil
	}
	if err = tx.VideoComment.UpdateOneID(commentID).AddLikeCount(-1).Exec(ctx); err != nil {
		r.log.Errorf("dec comment like count failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("dec like count failed")
	}
	return true, nil
}

// CollectWithCounter 收藏：台账行 + collect_count 同事务。
func (r *InteractionRepo) CollectWithCounter(ctx context.Context, userID, videoID uint32) (collected bool, err error) {
	tx, terr := r.entClient.Client().Tx(ctx)
	if terr != nil {
		return false, interactionV1.ErrorInternalServerError("start transaction failed")
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
			return
		}
		err = tx.Commit()
	}()

	exist, err := r.ExistsCollect(ctx, userID, videoID)
	if err != nil {
		return false, err
	}
	if exist {
		return false, nil
	}
	builder := tx.VideoCollect.Create().
		SetUserID(userID).
		SetVideoID(videoID).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	if _, err = builder.Save(ctx); err != nil {
		r.log.Errorf("create collect failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("create collect failed")
	}
	if err = tx.Video.UpdateOneID(videoID).AddCollectCount(1).Exec(ctx); err != nil {
		r.log.Errorf("inc collect count failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("inc collect count failed")
	}
	return true, nil
}

// UncollectWithCounter 取消收藏。
func (r *InteractionRepo) UncollectWithCounter(ctx context.Context, userID, videoID uint32) (removed bool, err error) {
	tx, terr := r.entClient.Client().Tx(ctx)
	if terr != nil {
		return false, interactionV1.ErrorInternalServerError("start transaction failed")
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
			return
		}
		err = tx.Commit()
	}()

	n, err := tx.VideoCollect.Delete().
		Where(videocollect.UserIDEQ(userID), videocollect.VideoIDEQ(videoID)).Exec(ctx)
	if err != nil {
		r.log.Errorf("delete collect failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("delete collect failed")
	}
	if n == 0 {
		return false, nil
	}
	if err = tx.Video.UpdateOneID(videoID).AddCollectCount(-1).Exec(ctx); err != nil {
		r.log.Errorf("dec collect count failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("dec collect count failed")
	}
	return true, nil
}

// GetLikeStatus 批量视频点赞状态
func (r *InteractionRepo) GetLikeStatus(ctx context.Context, userID uint32, videoIDs []uint32) (map[uint32]bool, error) {
	out := make(map[uint32]bool, len(videoIDs))
	if userID == 0 || len(videoIDs) == 0 {
		return out, nil
	}
	rows, err := r.entClient.Client().VideoLike.Query().
		Where(videolike.UserIDEQ(userID), videolike.TargetTypeEQ(videolike.TargetTypeVideo), videolike.TargetIDIn(videoIDs...)).
		All(ctx)
	if err != nil {
		return nil, err
	}
	for _, row := range rows {
		out[row.TargetID] = true
	}
	return out, nil
}

// ── 收藏 ──

// ExistsCollect 是否已收藏
func (r *InteractionRepo) ExistsCollect(ctx context.Context, userID, videoID uint32) (bool, error) {
	return r.entClient.Client().VideoCollect.Query().
		Where(videocollect.UserIDEQ(userID), videocollect.VideoIDEQ(videoID)).Exist(ctx)
}

// CreateCollect 收藏入账
func (r *InteractionRepo) CreateCollect(ctx context.Context, userID, videoID uint32) (bool, error) {
	exist, err := r.ExistsCollect(ctx, userID, videoID)
	if err != nil {
		return false, err
	}
	if exist {
		return false, nil
	}
	builder := r.entClient.Client().VideoCollect.Create().
		SetUserID(userID).
		SetVideoID(videoID).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	if _, err := builder.Save(ctx); err != nil {
		r.log.Errorf("create collect failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("create collect failed")
	}
	return true, nil
}

// DeleteCollect 取消收藏
func (r *InteractionRepo) DeleteCollect(ctx context.Context, userID, videoID uint32) (bool, error) {
	n, err := r.entClient.Client().VideoCollect.Delete().
		Where(videocollect.UserIDEQ(userID), videocollect.VideoIDEQ(videoID)).Exec(ctx)
	if err != nil {
		r.log.Errorf("delete collect failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("delete collect failed")
	}
	return n > 0, nil
}

// CollectedVideoIDs 我的收藏视频 ID（按收藏时间倒序）
func (r *InteractionRepo) CollectedVideoIDs(ctx context.Context, userID uint32, page, pageSize uint32) ([]uint32, int, error) {
	if page < 1 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	if pageSize > 50 {
		pageSize = 50
	}
	q := r.entClient.Client().VideoCollect.Query().Where(videocollect.UserIDEQ(userID))
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	rows, err := q.Order(ent.Desc(videocollect.FieldCreatedAt)).
		Offset(int(page-1) * int(pageSize)).Limit(int(pageSize)).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	ids := make([]uint32, 0, len(rows))
	for _, row := range rows {
		ids = append(ids, row.VideoID)
	}
	return ids, total, nil
}

// GetCollectStatus 批量收藏状态
func (r *InteractionRepo) GetCollectStatus(ctx context.Context, userID uint32, videoIDs []uint32) (map[uint32]bool, error) {
	out := make(map[uint32]bool, len(videoIDs))
	if userID == 0 || len(videoIDs) == 0 {
		return out, nil
	}
	rows, err := r.entClient.Client().VideoCollect.Query().
		Where(videocollect.UserIDEQ(userID), videocollect.VideoIDIn(videoIDs...)).
		All(ctx)
	if err != nil {
		return nil, err
	}
	for _, row := range rows {
		out[row.VideoID] = true
	}
	return out, nil
}

// ── 关注 ──

// ExistsFollow 是否已关注
func (r *InteractionRepo) ExistsFollow(ctx context.Context, followerID, followeeID uint32) (bool, error) {
	return r.entClient.Client().UserFollow.Query().
		Where(userfollow.FollowerIDEQ(followerID), userfollow.FolloweeIDEQ(followeeID)).Exist(ctx)
}

// CreateFollow 关注入账
func (r *InteractionRepo) CreateFollow(ctx context.Context, followerID, followeeID uint32) (bool, error) {
	exist, err := r.ExistsFollow(ctx, followerID, followeeID)
	if err != nil {
		return false, err
	}
	if exist {
		return false, nil
	}
	builder := r.entClient.Client().UserFollow.Create().
		SetFollowerID(followerID).
		SetFolloweeID(followeeID).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	if _, err := builder.Save(ctx); err != nil {
		r.log.Errorf("create follow failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("create follow failed")
	}
	return true, nil
}

// DeleteFollow 取消关注
func (r *InteractionRepo) DeleteFollow(ctx context.Context, followerID, followeeID uint32) (bool, error) {
	n, err := r.entClient.Client().UserFollow.Delete().
		Where(userfollow.FollowerIDEQ(followerID), userfollow.FolloweeIDEQ(followeeID)).Exec(ctx)
	if err != nil {
		r.log.Errorf("delete follow failed: %s", err.Error())
		return false, interactionV1.ErrorInternalServerError("delete follow failed")
	}
	return n > 0, nil
}

// FollowCounts 双向计数（following 我关注的数量，followers 我的粉丝数量）
func (r *InteractionRepo) FollowCounts(ctx context.Context, userID uint32) (following, followers int, err error) {
	if following, err = r.entClient.Client().UserFollow.Query().Where(userfollow.FollowerIDEQ(userID)).Count(ctx); err != nil {
		return
	}
	followers, err = r.entClient.Client().UserFollow.Query().Where(userfollow.FolloweeIDEQ(userID)).Count(ctx)
	return
}

// FollowingAuthorIDs 关注作者 ID 列表（Feed 关注召回用）
func (r *InteractionRepo) FollowingAuthorIDs(ctx context.Context, followerID uint32, limit int) ([]uint32, error) {
	rows, err := r.entClient.Client().UserFollow.Query().
		Where(userfollow.FollowerIDEQ(followerID)).
		Order(ent.Desc(userfollow.FieldCreatedAt)).
		Limit(limit).All(ctx)
	if err != nil {
		return nil, err
	}
	ids := make([]uint32, 0, len(rows))
	for _, row := range rows {
		ids = append(ids, row.FolloweeID)
	}
	return ids, nil
}

// GetFollowStatus 批量关注状态（viewer → 作者）
func (r *InteractionRepo) GetFollowStatus(ctx context.Context, followerID uint32, userIDs []uint32) (map[uint32]bool, error) {
	out := make(map[uint32]bool, len(userIDs))
	if followerID == 0 || len(userIDs) == 0 {
		return out, nil
	}
	rows, err := r.entClient.Client().UserFollow.Query().
		Where(userfollow.FollowerIDEQ(followerID), userfollow.FolloweeIDIn(userIDs...)).
		All(ctx)
	if err != nil {
		return nil, err
	}
	for _, row := range rows {
		out[row.FolloweeID] = true
	}
	return out, nil
}

// ListFollowing 我的关注列表
func (r *InteractionRepo) ListFollowing(ctx context.Context, userID uint32, page, pageSize uint32) ([]*ent.UserFollow, int, error) {
	return r.listFollowSide(ctx, userfollow.FieldFollowerID, userID, page, pageSize)
}

// ListFollowers 我的粉丝列表
func (r *InteractionRepo) ListFollowers(ctx context.Context, userID uint32, page, pageSize uint32) ([]*ent.UserFollow, int, error) {
	return r.listFollowSide(ctx, userfollow.FieldFolloweeID, userID, page, pageSize)
}

func (r *InteractionRepo) listFollowSide(ctx context.Context, sideField string, userID uint32, page, pageSize uint32) ([]*ent.UserFollow, int, error) {
	if page < 1 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	if pageSize > 50 {
		pageSize = 50
	}
	q := r.entClient.Client().UserFollow.Query()
	if sideField == userfollow.FieldFollowerID {
		q.Where(userfollow.FollowerIDEQ(userID))
	} else {
		q.Where(userfollow.FolloweeIDEQ(userID))
	}
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Desc(userfollow.FieldCreatedAt)).
		Offset(int(page-1) * int(pageSize)).Limit(int(pageSize)).All(ctx)
	return items, total, err
}
