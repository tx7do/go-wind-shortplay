package service

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/redis/go-redis/v9"
	"github.com/tx7do/go-utils/timeutil"
	"github.com/tx7do/go-utils/trans"
	"google.golang.org/protobuf/types/known/emptypb"

	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"

	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"

	"go-wind-shortplay/pkg/sseevent"

	imV1 "go-wind-shortplay/api/gen/go/im/service/v1"
)

// spImContentMaxRunes 私信内容上限
const spImContentMaxRunes = 500

// ImService 私信服务（core 真实业务）。
// 落库为准：发送即持久化 + Redis 发布实时事件（app BFF 桥接 SSE 定向推送）；
// 事件尽力而为，丢失只影响实时性，客户端 REST 拉取对账。
type ImService struct {
	imV1.UnimplementedImServiceServer

	log      *log.Helper
	imRepo   *data.ImRepo
	userRepo data.UserRepo
	sysConf  *data.SysConfRepo
	redis    *redis.Client
}

func NewImService(
	ctx *bootstrap.Context,
	imRepo *data.ImRepo,
	userRepo data.UserRepo,
	sysConf *data.SysConfRepo,
	rdb *redis.Client,
) *ImService {
	return &ImService{
		log:      ctx.NewLoggerHelper("im/service/core-service"),
		imRepo:   imRepo,
		userRepo: userRepo,
		sysConf:  sysConf,
		redis:    rdb,
	}
}

// userBriefOf 取用户简况（失败返回空简况，展示兜底）
func (s *ImService) userBriefOf(ctx context.Context, userID uint32) *identityV1.UserBrief {
	if userID == 0 {
		return &identityV1.UserBrief{Id: trans.Ptr(uint32(0))}
	}
	if u, err := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
		QueryBy: &identityV1.GetUserRequest_Id{Id: userID},
	}); err == nil && u != nil {
		return toUserBriefSP(u)
	}
	return &identityV1.UserBrief{Id: trans.Ptr(userID)}
}

// peerOfViewer 会话对端 = 非 viewer 一侧
func peerOfViewer(e *ent.ImConversation, uid uint32) uint32 {
	if uid == e.ParticipantAID {
		return e.ParticipantBID
	}
	return e.ParticipantAID
}

// conversationUnread viewer 侧未读数
func conversationUnread(e *ent.ImConversation, uid uint32) uint64 {
	if uid == e.ParticipantAID {
		return e.AUnreadCount
	}
	return e.BUnreadCount
}

// conversationToDTO ent 会话 → proto（peer 简况由调用方传入）
func conversationToDTO(e *ent.ImConversation, uid uint32, peer *identityV1.UserBrief) *imV1.Conversation {
	return &imV1.Conversation{
		Id:                 trans.Ptr(e.ID),
		PeerId:             trans.Ptr(peerOfViewer(e, uid)),
		Peer:               peer,
		LastMessagePreview: trans.Ptr(e.LastMessagePreview),
		LastMessageAt:      timeutil.TimeToTimestamppb(e.LastMessageAt),
		UnreadCount:        trans.Ptr(conversationUnread(e, uid)),
		CreatedAt:          timeutil.TimeToTimestamppb(e.CreatedAt),
	}
}

// messageToDTO ent 消息 → proto
func messageToDTO(e *ent.ImMessage, sender *identityV1.UserBrief) *imV1.Message {
	return &imV1.Message{
		Id:             trans.Ptr(e.ID),
		ConversationId: trans.Ptr(e.ConversationID),
		SenderId:       trans.Ptr(e.SenderID),
		ReceiverId:     trans.Ptr(e.ReceiverID),
		Sender:         sender,
		Content:        trans.Ptr(e.Content),
		CreatedAt:      timeutil.TimeToTimestamppb(e.CreatedAt),
	}
}

// checkImEnabled 私信开关（关闭拒绝发送；存量会话仍可读）
func (s *ImService) checkImEnabled(ctx context.Context) error {
	conf, err := s.sysConf.GetEnsure(ctx)
	if err != nil {
		return err
	}
	if !conf.ImEnabled {
		return imV1.ErrorImDisabled("im disabled")
	}
	return nil
}

// SendMessage 发送私信（登录 + 开关 + 校验 + 事务落库 + Redis 实时事件）
func (s *ImService) SendMessage(ctx context.Context, req *imV1.SendMessageRequest) (*imV1.Message, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, imV1.ErrorUnauthorized("login required")
	}
	if req == nil || req.GetReceiverId() == 0 {
		return nil, imV1.ErrorBadRequest("invalid parameter")
	}
	if req.GetReceiverId() == uid {
		return nil, imV1.ErrorCannotMessageSelf("cannot message yourself")
	}
	content := strings.TrimSpace(req.GetContent())
	if content == "" {
		return nil, imV1.ErrorBadRequest("content is required")
	}
	if len([]rune(content)) > spImContentMaxRunes {
		return nil, imV1.ErrorContentTooLong("content too long (max 500)")
	}
	if err := s.checkImEnabled(ctx); err != nil {
		return nil, err
	}
	// 收件人须存在（跨租户写越权由 TenantPrivacy 行级谓词兜底）
	if u, err := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
		QueryBy: &identityV1.GetUserRequest_Id{Id: req.GetReceiverId()},
	}); err != nil || u == nil {
		return nil, imV1.ErrorUserNotFound("user not found")
	}

	conv, err := s.imRepo.EnsureConversation(ctx, uid, req.GetReceiverId())
	if err != nil {
		return nil, err
	}
	msg, err := s.imRepo.SendMessage(ctx, conv, uid, content)
	if err != nil {
		return nil, err
	}

	// 实时事件（尽力而为）：app BFF 桥接 SSE 定向推送收件人全部在线会话
	s.publishImEvent(ctx, uid, req.GetReceiverId(), conv.ID, msg.ID, content)

	return messageToDTO(msg, s.userBriefOf(ctx, uid)), nil
}

// publishImEvent 发布私信实时事件（尽力而为，失败仅记日志）
func (s *ImService) publishImEvent(ctx context.Context, senderID, receiverID, convID, msgID uint32, content string) {
	if s.redis == nil {
		return
	}
	payload, err := json.Marshal(sseevent.ImEvent{
		ReceiverUserID: receiverID,
		SenderUserID:   senderID,
		ConversationID: convID,
		MessageID:      msgID,
		Preview:        imPreviewOfSP(content),
	})
	if err != nil {
		return
	}
	if err := s.redis.Publish(ctx, sseevent.RedisChannelIm, payload).Err(); err != nil {
		s.log.Errorf("publish im event failed: %s", err.Error())
	}
}

// imPageArgs im 请求分页参数（缺省 1/20，上限 50）
func imPageArgs(pageNum, pageSize uint32) (uint32, uint32) {
	if pageNum < 1 {
		pageNum = 1
	}
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 50 {
		pageSize = 50
	}
	return pageNum, pageSize
}

// imPreviewOfSP 服务层预览截断（与 repo 口径一致）
func imPreviewOfSP(content string) string {
	r := []rune(content)
	if len(r) > 50 {
		return string(r[:50]) + "…"
	}
	return content
}

// ListConversations 会话列表（viewer 视角，最近消息倒序；peer 批量解析）
func (s *ImService) ListConversations(ctx context.Context, req *paginationV1.PagingRequest) (*imV1.ListConversationsResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, imV1.ErrorUnauthorized("login required")
	}
	pageNum, pageSize := pageArgsOfSeries(req)
	items, total, err := s.imRepo.ListConversationsPage(ctx, uid, int(pageNum-1)*int(pageSize), int(pageSize))
	if err != nil {
		return nil, err
	}
	peerIDs := make([]uint32, 0, len(items))
	for _, e := range items {
		peerIDs = append(peerIDs, peerOfViewer(e, uid))
	}
	peers := s.userBriefsOf(ctx, peerIDs)
	resp := &imV1.ListConversationsResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		resp.Items = append(resp.Items, conversationToDTO(e, uid, peers[peerOfViewer(e, uid)]))
	}
	return resp, nil
}

// userBriefsOf 批量用户简况（失败留空简况）
func (s *ImService) userBriefsOf(ctx context.Context, userIDs []uint32) map[uint32]*identityV1.UserBrief {
	out := make(map[uint32]*identityV1.UserBrief, len(userIDs))
	for _, id := range userIDs {
		if id == 0 {
			continue
		}
		out[id] = s.userBriefOf(ctx, id)
	}
	return out
}

// ListMessages 会话消息（参与方校验；ID 倒序分页）
func (s *ImService) ListMessages(ctx context.Context, req *imV1.ListMessagesRequest) (*imV1.ListMessagesResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, imV1.ErrorUnauthorized("login required")
	}
	if req == nil || req.GetConversationId() == 0 {
		return nil, imV1.ErrorBadRequest("invalid parameter")
	}
	conv, err := s.imRepo.GetConversation(ctx, req.GetConversationId())
	if err != nil {
		return nil, err
	}
	if uid != conv.ParticipantAID && uid != conv.ParticipantBID {
		return nil, imV1.ErrorNotConversationParticipant("not conversation participant")
	}
	pageNum, pageSize := imPageArgs(req.GetPageNum(), req.GetPageSize())
	if pageSize < 20 {
		pageSize = 20
	}
	items, total, err := s.imRepo.ListMessagesPage(ctx, conv.ID, int(pageNum-1)*int(pageSize), int(pageSize))
	if err != nil {
		return nil, err
	}
	senderIDs := make([]uint32, 0, len(items))
	for _, e := range items {
		senderIDs = append(senderIDs, e.SenderID)
	}
	senders := s.userBriefsOf(ctx, senderIDs)
	resp := &imV1.ListMessagesResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		resp.Items = append(resp.Items, messageToDTO(e, senders[e.SenderID]))
	}
	return resp, nil
}

// MarkConversationRead 标记会话已读（清零 viewer 侧未读）
func (s *ImService) MarkConversationRead(ctx context.Context, req *imV1.MarkConversationReadRequest) (*emptypb.Empty, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, imV1.ErrorUnauthorized("login required")
	}
	if req == nil || req.GetConversationId() == 0 {
		return nil, imV1.ErrorBadRequest("invalid parameter")
	}
	conv, err := s.imRepo.GetConversation(ctx, req.GetConversationId())
	if err != nil {
		return nil, err
	}
	if uid != conv.ParticipantAID && uid != conv.ParticipantBID {
		return nil, imV1.ErrorNotConversationParticipant("not conversation participant")
	}
	if err := s.imRepo.MarkRead(ctx, conv, uid); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// EnsureConversation 与指定用户建会话（存在即返回既有）
func (s *ImService) EnsureConversation(ctx context.Context, req *imV1.EnsureConversationRequest) (*imV1.Conversation, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, imV1.ErrorUnauthorized("login required")
	}
	if req == nil || req.GetPeerUserId() == 0 {
		return nil, imV1.ErrorBadRequest("invalid parameter")
	}
	if req.GetPeerUserId() == uid {
		return nil, imV1.ErrorCannotMessageSelf("cannot message yourself")
	}
	if u, err := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
		QueryBy: &identityV1.GetUserRequest_Id{Id: req.GetPeerUserId()},
	}); err != nil || u == nil {
		return nil, imV1.ErrorUserNotFound("user not found")
	}
	conv, err := s.imRepo.EnsureConversation(ctx, uid, req.GetPeerUserId())
	if err != nil {
		return nil, err
	}
	return conversationToDTO(conv, uid, s.userBriefOf(ctx, req.GetPeerUserId())), nil
}

// CountUnread viewer 全部会话未读总数
func (s *ImService) CountUnread(ctx context.Context, _ *emptypb.Empty) (*imV1.CountUnreadResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, imV1.ErrorUnauthorized("login required")
	}
	total, err := s.imRepo.CountUnread(ctx, uid)
	if err != nil {
		return nil, err
	}
	return &imV1.CountUnreadResponse{Count: trans.Ptr(uint64(total))}, nil
}
