package data

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/notification"
)

// NotificationRepo 站内通知仓储
type NotificationRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewNotificationRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *NotificationRepo {
	return &NotificationRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("notification/repo/core-service"),
	}
}

func (r *NotificationRepo) Client() *ent.Client {
	return r.entClient.Client()
}

func (r *NotificationRepo) Create(ctx context.Context, userID uint32, typ uint8, senderID, videoID, commentID uint32, content string) error {
	_, err := r.Client().Notification.Create().
		SetUserID(userID).
		SetType(typ).
		SetSenderID(senderID).
		SetVideoID(videoID).
		SetCommentID(commentID).
		SetNillableContent(&content).
		Save(ctx)
	return err
}

func (r *NotificationRepo) List(ctx context.Context, userID uint32, unreadOnly bool, offset, limit int) ([]*ent.Notification, int, error) {
	q := r.Client().Notification.Query().Where(notification.UserID(userID))
	if unreadOnly {
		q = q.Where(notification.IsRead(false))
	}
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Desc(notification.FieldID)).Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

func (r *NotificationRepo) MarkRead(ctx context.Context, userID uint32, ids []uint32) error {
	_, err := r.Client().Notification.Update().
		Where(notification.UserID(userID), notification.IDIn(ids...)).
		SetIsRead(true).
		Save(ctx)
	return err
}

func (r *NotificationRepo) MarkAllRead(ctx context.Context, userID uint32) error {
	_, err := r.Client().Notification.Update().
		Where(notification.UserID(userID), notification.IsRead(false)).
		SetIsRead(true).
		Save(ctx)
	return err
}

func (r *NotificationRepo) UnreadCount(ctx context.Context, userID uint32) (int, error) {
	return r.Client().Notification.Query().
		Where(notification.UserID(userID), notification.IsRead(false)).
		Count(ctx)
}
