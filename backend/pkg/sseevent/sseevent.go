// Package sseevent SSE 事件名与跨服务事件载荷的注册表。
//
// 事件名是后端发布方与前端 sse event 注册表的双边约定：改名需两侧同步，
// 已发布的事件名不可复用为其他语义。
package sseevent

// EventNotification 站内信/系统通知事件（前端通知 Toast 消费）。
const EventNotification = "notification"

// RedisChannelNotify 系统通知事件的 Redis Pub/Sub 频道：
// core 服务（发布 worker 等后台链路）发出，admin 服务订阅后转 SSE 实时推送。
// 落库为准：频道丢失只影响实时性，不影响到达。
const RedisChannelNotify = "go-wind-shortplay:notify:v1"

// NotifyEvent 跨服务通知事件载荷（Redis 内 JSON 序列化）。
type NotifyEvent struct {
	UserID  uint32 `json:"user_id"`
	Title   string `json:"title"`
	Content string `json:"content"`
}

// EventImMessage 私信新消息事件（前端聊天页/会话列表消费）。
const EventImMessage = "im-message"

// RedisChannelIm 私信事件的 Redis Pub/Sub 频道：core 落库后发出，
// app 服务订阅后转 SSE 定向推送收件人全部在线会话。
// 落库为准：频道丢失只影响实时性，不影响到达（客户端 REST 拉取对账）。
const RedisChannelIm = "go-wind-shortplay:im:v1"

// ImEvent 跨服务私信事件载荷（Redis 内 JSON 序列化）。
// 只推 ID 与预览，客户端收到后按需 REST 拉全文（信封不随消息内容演进膨胀）。
type ImEvent struct {
	ReceiverUserID uint32 `json:"receiver_user_id"`
	SenderUserID   uint32 `json:"sender_user_id"`
	ConversationID uint32 `json:"conversation_id"`
	MessageID      uint32 `json:"message_id"`
	Preview        string `json:"preview"`
}
