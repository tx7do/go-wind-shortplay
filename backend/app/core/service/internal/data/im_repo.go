package data

import (
	"context"
	"encoding/json"
	"time"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/imconversation"
	"go-wind-shortplay/app/core/service/internal/data/ent/immessage"
	"go-wind-shortplay/app/core/service/internal/data/ent/predicate"

	imV1 "go-wind-shortplay/api/gen/go/im/service/v1"
)

// spImPreviewRunes 会话最近消息预览截断长度
const spImPreviewRunes = 50

type ImRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewImRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *ImRepo {
	return &ImRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("im/repo/core-service"),
	}
}

// imPair 会话参与方归一化：a 恒为较小 ID、b 恒为较大（成对唯一前提）
func imPair(uid, peer int64) (int64, int64) {
	if uid < peer {
		return uid, peer
	}
	return peer, uid
}

// imPreviewOf 列表预览（超长截断）
func imPreviewOf(content string) string {
	r := []rune(content)
	if len(r) > spImPreviewRunes {
		return string(r[:spImPreviewRunes]) + "…"
	}
	return content
}

// EnsureConversation 查或建 1:1 会话（幂等；并发建会话唯一键冲突回读）
func (r *ImRepo) EnsureConversation(ctx context.Context, uid, peer int64) (*ent.ImConversation, error) {
	a, b := imPair(uid, peer)
	e, err := r.entClient.Client().ImConversation.Query().
		Where(imconversation.ParticipantAIDEQ(a), imconversation.ParticipantBIDEQ(b)).
		First(ctx)
	if err == nil {
		return e, nil
	}
	if !ent.IsNotFound(err) {
		r.log.Errorf("query im conversation failed: %s", err.Error())
		return nil, imV1.ErrorInternalServerError("query conversation failed")
	}
	builder := r.entClient.Client().ImConversation.Create().
		SetParticipantAID(a).
		SetParticipantBID(b).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	e, err = builder.Save(ctx)
	if err != nil {
		if e, err = r.entClient.Client().ImConversation.Query().
			Where(imconversation.ParticipantAIDEQ(a), imconversation.ParticipantBIDEQ(b)).
			First(ctx); err == nil {
			return e, nil
		}
		r.log.Errorf("create im conversation failed: %s", err.Error())
		return nil, imV1.ErrorInternalServerError("create conversation failed")
	}
	return e, nil
}

// GetConversation 取单条（服务层参与方校验用）
func (r *ImRepo) GetConversation(ctx context.Context, id int64) (*ent.ImConversation, error) {
	e, err := r.entClient.Client().ImConversation.Query().
		Where(imconversation.IDEQ(id)).
		First(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, imV1.ErrorConversationNotFound("conversation not found")
		}
		r.log.Errorf("get im conversation failed: %s", err.Error())
		return nil, imV1.ErrorInternalServerError("get conversation failed")
	}
	return e, nil
}

// SendMessage 发消息：建消息行 + 收件侧未读台账自增 + 会话 last_* 回写
func (r *ImRepo) SendMessage(ctx context.Context, conv *ent.ImConversation, senderID int64, content string) (*ent.ImMessage, error) {
	receiverID := conv.ParticipantAID
	if senderID == receiverID {
		receiverID = conv.ParticipantBID
	}

	builder := r.entClient.Client().ImMessage.Create().
		SetConversationID(conv.ID).
		SetSenderID(senderID).
		SetReceiverID(receiverID).
		SetContent(content).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	msg, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("create im message failed: %s", err.Error())
		return nil, imV1.ErrorInternalServerError("send message failed")
	}

	now := time.Now()
	convUpdate := r.entClient.Client().ImConversation.UpdateOneID(conv.ID).
		SetLastMessagePreview(imPreviewOf(content)).
		SetNillableLastMessageAt(&now).
		SetUpdatedAt(now)
	if receiverID == conv.ParticipantAID {
		convUpdate = convUpdate.AddAUnreadCount(1)
	} else {
		convUpdate = convUpdate.AddBUnreadCount(1)
	}
	if _, err := convUpdate.Save(ctx); err != nil {
		r.log.Errorf("update im conversation after send failed: %s", err.Error())
		return nil, imV1.ErrorInternalServerError("send message failed")
	}
	return msg, nil
}

// ListConversationsPage viewer 视角会话列表（最近消息倒序，空会话按建会话时间兜底）
func (r *ImRepo) ListConversationsPage(ctx context.Context, uid int64, offset, limit int) ([]*ent.ImConversation, int, error) {
	ps := []predicate.ImConversation{
		imconversation.Or(
			imconversation.ParticipantAIDEQ(uid),
			imconversation.ParticipantBIDEQ(uid),
		),
	}
	q := r.entClient.Client().ImConversation.Query().Where(ps...)
	total, err := q.Count(ctx)
	if err != nil {
		r.log.Errorf("count im conversations failed: %s", err.Error())
		return nil, 0, imV1.ErrorInternalServerError("list conversations failed")
	}
	items, err := q.
		Order(ent.Desc(imconversation.FieldLastMessageAt), ent.Desc(imconversation.FieldID)).
		Offset(offset).Limit(limit).
		All(ctx)
	if err != nil {
		r.log.Errorf("list im conversations failed: %s", err.Error())
		return nil, 0, imV1.ErrorInternalServerError("list conversations failed")
	}
	return items, total, nil
}

// ListMessagesPage 会话消息（ID 倒序：最新一页在前，翻页取更早）
func (r *ImRepo) ListMessagesPage(ctx context.Context, convID int64, offset, limit int) ([]*ent.ImMessage, int, error) {
	q := r.entClient.Client().ImMessage.Query().Where(immessage.ConversationIDEQ(convID))
	total, err := q.Count(ctx)
	if err != nil {
		r.log.Errorf("count im messages failed: %s", err.Error())
		return nil, 0, imV1.ErrorInternalServerError("list messages failed")
	}
	items, err := q.
		Order(ent.Desc(immessage.FieldID)).
		Offset(offset).Limit(limit).
		All(ctx)
	if err != nil {
		r.log.Errorf("list im messages failed: %s", err.Error())
		return nil, 0, imV1.ErrorInternalServerError("list messages failed")
	}
	return items, total, nil
}

// spImAdminFilter 管理端私信列表过滤
type spImAdminFilter struct {
	Content    *string `json:"content___icontains"`
	SenderID   *int64  `json:"sender_id"`
	ReceiverID *int64  `json:"receiver_id"`
}

// ListAdmin 管理端全量私信列表（分页 + 内容/发送人/接收人过滤，ID 倒序）
func (r *ImRepo) ListAdmin(ctx context.Context, req *paginationV1.PagingRequest) ([]*ent.ImMessage, int, error) {
	page, pageSize := pageArgsOf(req)

	var ps []predicate.ImMessage
	if req.GetQuery() != "" {
		var f spImAdminFilter
		if err := json.Unmarshal([]byte(req.GetQuery()), &f); err == nil {
			if f.Content != nil && *f.Content != "" {
				ps = append(ps, immessage.ContentContainsFold(*f.Content))
			}
			if f.SenderID != nil && *f.SenderID > 0 {
				ps = append(ps, immessage.SenderIDEQ(*f.SenderID))
			}
			if f.ReceiverID != nil && *f.ReceiverID > 0 {
				ps = append(ps, immessage.ReceiverIDEQ(*f.ReceiverID))
			}
		}
	}

	q := r.entClient.Client().ImMessage.Query()
	if len(ps) > 0 {
		q.Where(ps...)
	}
	total, err := q.Count(ctx)
	if err != nil {
		r.log.Errorf("count im messages failed: %s", err.Error())
		return nil, 0, imV1.ErrorInternalServerError("count messages failed")
	}
	items, err := q.Order(ent.Desc(immessage.FieldID)).
		Offset(page).Limit(pageSize).All(ctx)
	if err != nil {
		r.log.Errorf("list im messages failed: %s", err.Error())
		return nil, 0, imV1.ErrorInternalServerError("list messages failed")
	}
	return items, total, nil
}

// MarkRead 清零 viewer 侧未读（幂等）
func (r *ImRepo) MarkRead(ctx context.Context, conv *ent.ImConversation, uid int64) error {
	update := r.entClient.Client().ImConversation.UpdateOneID(conv.ID).SetUpdatedAt(time.Now())
	if uid == conv.ParticipantAID {
		if conv.AUnreadCount == 0 {
			return nil
		}
		update = update.SetAUnreadCount(0)
	} else {
		if conv.BUnreadCount == 0 {
			return nil
		}
		update = update.SetBUnreadCount(0)
	}
	if _, err := update.Save(ctx); err != nil {
		r.log.Errorf("mark im conversation read failed: %s", err.Error())
		return imV1.ErrorInternalServerError("mark read failed")
	}
	return nil
}

// CountUnread viewer 全部会话未读总数
func (r *ImRepo) CountUnread(ctx context.Context, uid int64) (int64, error) {
	rows, err := r.entClient.Client().ImConversation.Query().
		Where(
			imconversation.Or(
				imconversation.ParticipantAIDEQ(uid),
				imconversation.ParticipantBIDEQ(uid),
			),
		).
		Select(imconversation.FieldAUnreadCount, imconversation.FieldBUnreadCount).
		All(ctx)
	if err != nil {
		r.log.Errorf("count im unread failed: %s", err.Error())
		return 0, imV1.ErrorInternalServerError("count unread failed")
	}
	var total int64
	for _, row := range rows {
		if row.ParticipantAID == uid {
			total += int64(row.AUnreadCount)
		} else {
			total += int64(row.BUnreadCount)
		}
	}
	return total, nil
}
