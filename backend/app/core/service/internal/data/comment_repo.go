package data

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/videocomment"
)

// CommentRepo 评论仓储
type CommentRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewCommentRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *CommentRepo {
	return &CommentRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("comment/repo/core-service"),
	}
}

func (r *CommentRepo) Client() *ent.Client {
	return r.entClient.Client()
}

func (r *CommentRepo) GetByID(ctx context.Context, id uint32) (*ent.VideoComment, error) {
	return r.Client().VideoComment.Query().Where(videocomment.ID(id)).Only(ctx)
}

func (r *CommentRepo) Create(ctx context.Context, videoID, userID uint32, content string, parentID uint32) (*ent.VideoComment, error) {
	c := r.Client().VideoComment.Create().
		SetVideoID(videoID).
		SetUserID(userID).
		SetContent(content).
		SetParentID(parentID)
	return c.Save(ctx)
}

func (r *CommentRepo) Delete(ctx context.Context, id uint32) error {
	return r.Client().VideoComment.DeleteOneID(id).Exec(ctx)
}

func (r *CommentRepo) ListByVideo(ctx context.Context, videoID uint32, offset, limit int) ([]*ent.VideoComment, int, error) {
	q := r.Client().VideoComment.Query().Where(videocomment.VideoID(videoID))
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Desc(videocomment.FieldCreatedAt)).Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

// ListAll 全量评论列表（管理端），videoID 为 0 表示不过滤
func (r *CommentRepo) ListAll(ctx context.Context, videoID uint32, offset, limit int) ([]*ent.VideoComment, int, error) {
	q := r.Client().VideoComment.Query()
	if videoID > 0 {
		q = q.Where(videocomment.VideoID(videoID))
	}
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Desc(videocomment.FieldID)).Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

// IncVideoCommentCount 评论数增减（事务外单行更新）
func (r *CommentRepo) IncVideoCommentCount(ctx context.Context, videoID uint32, delta int) error {
	_, err := r.Client().Video.UpdateOneID(videoID).AddCommentCount(int64(delta)).Save(ctx)
	return err
}

// ListReplies 一级评论的回复列表（楼中楼，按时间正序）
func (r *CommentRepo) ListReplies(ctx context.Context, commentID uint32, offset, limit int) ([]*ent.VideoComment, int, error) {
	q := r.Client().VideoComment.Query().Where(videocomment.ParentID(commentID))
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Asc(videocomment.FieldCreatedAt)).Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

// IncReplyCount 一级评论回复数增减
func (r *CommentRepo) IncReplyCount(ctx context.Context, commentID uint32, delta int) error {
	_, err := r.Client().VideoComment.UpdateOneID(commentID).AddReplyCount(int64(delta)).Save(ctx)
	return err
}
