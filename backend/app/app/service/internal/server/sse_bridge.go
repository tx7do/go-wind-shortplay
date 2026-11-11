package server

import (
	"context"
	"encoding/json"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/redis/go-redis/v9"
	"github.com/tx7do/go-utils/id"
	sseLib "github.com/tx7do/kratos-transport/transport/sse"

	authenticationV1 "go-wind-shortplay/api/gen/go/authentication/service/v1"

	"go-wind-shortplay/pkg/sseevent"
)

// StartSseEventBridge 订阅 core 服务经 Redis Pub/Sub 发出的实时事件
// （私信 + 系统通知；落库均在 core 侧完成），转成 SSE 定向推送给目标用户
// 全部在线 App 会话。落库为准：本协程只管实时性，崩溃/丢失不影响到达
// （客户端 REST 拉取对账）。
//
// streamID 约定与 admin 面一致：以 access token 作为流 ID（连接时
// /events?streamId=<token>&token=<token>），一个 token 即一个在线端。
func StartSseEventBridge(
	ctx context.Context,
	redisClient *redis.Client,
	srv *sseLib.Server,
	authenticationServiceClient authenticationV1.AuthenticationServiceClient,
	l *log.Helper,
) (stop func()) {
	if redisClient == nil || srv == nil {
		return func() {}
	}

	subCtx, cancel := context.WithCancel(ctx)
	bridge := func(channel string, onEvent func(ctx context.Context, payload []byte)) {
		go func() {
			sub := redisClient.Subscribe(subCtx, channel)
			defer func() { _ = sub.Close() }()
			for {
				select {
				case <-subCtx.Done():
					return
				case m := <-sub.Channel():
					onEvent(subCtx, []byte(m.Payload))
				}
			}
		}()
	}

	bridge(sseevent.RedisChannelIm, func(ctx context.Context, payload []byte) {
		var ev sseevent.ImEvent
		if err := json.Unmarshal(payload, &ev); err != nil {
			l.Errorf("sse bridge(im): unmarshal event failed: %v", err)
			return
		}
		pushImEventToUser(ctx, srv, authenticationServiceClient, l, ev)
	})
	bridge(sseevent.RedisChannelNotify, func(ctx context.Context, payload []byte) {
		var ev sseevent.NotifyEvent
		if err := json.Unmarshal(payload, &ev); err != nil {
			l.Errorf("sse bridge(notify): unmarshal event failed: %v", err)
			return
		}
		pushNotifyEventToUser(ctx, srv, authenticationServiceClient, l, ev)
	})

	return cancel
}

// pushNotifyEventToUser 把一条系统通知推给目标用户全部在线 App 会话
// （载荷对齐 admin 面 "notification" 事件的收件行 JSON 形态，前端双边约定）。
func pushNotifyEventToUser(
	ctx context.Context,
	srv *sseLib.Server,
	authenticationServiceClient authenticationV1.AuthenticationServiceClient,
	l *log.Helper,
	ev sseevent.NotifyEvent,
) {
	streamIds, err := authenticationServiceClient.GetAccessTokens(ctx, &authenticationV1.GetAccessTokensRequest{
		UserId:     ev.UserID,
		ClientType: authenticationV1.ClientType_app,
	})
	if err != nil {
		l.Errorf("sse bridge(notify): get access tokens failed (user=%d): %v", ev.UserID, err)
		return
	}
	if len(streamIds.GetAccessTokens()) == 0 {
		return
	}
	payload, merr := json.Marshal(map[string]any{
		"messageId":       0,
		"recipientUserId": ev.UserID,
		"status":          "SENT",
		"title":           ev.Title,
		"content":         ev.Content,
		"createdAt":       time.Now().Format(time.RFC3339),
	})
	if merr != nil {
		return
	}
	for _, streamId := range streamIds.GetAccessTokens() {
		srv.Publish(ctx, sseLib.StreamID(streamId), &sseLib.Event{
			ID:    []byte(id.NewGUIDv7(false)),
			Data:  payload,
			Event: []byte(sseevent.EventNotification),
		})
	}
}

// pushImEventToUser 推给收件人全部在线 App 会话（尽力而为：取 token 失败静默跳过）
func pushImEventToUser(
	ctx context.Context,
	srv *sseLib.Server,
	authenticationServiceClient authenticationV1.AuthenticationServiceClient,
	l *log.Helper,
	ev sseevent.ImEvent,
) {
	streamIds, err := authenticationServiceClient.GetAccessTokens(ctx, &authenticationV1.GetAccessTokensRequest{
		UserId:     ev.ReceiverUserID,
		ClientType: authenticationV1.ClientType_app,
	})
	if err != nil {
		l.Errorf("im subscriber: get access tokens failed (user=%d): %v", ev.ReceiverUserID, err)
		return
	}
	if len(streamIds.GetAccessTokens()) == 0 {
		return // 收件人不在线：落库为准，上线后 REST 拉取
	}
	payload, merr := json.Marshal(map[string]any{
		"conversationId": ev.ConversationID,
		"messageId":      ev.MessageID,
		"senderUserId":   ev.SenderUserID,
		"preview":        ev.Preview,
	})
	if merr != nil {
		return
	}
	for _, streamId := range streamIds.GetAccessTokens() {
		srv.Publish(ctx, sseLib.StreamID(streamId), &sseLib.Event{
			ID:    []byte(id.NewGUIDv7(false)),
			Data:  payload,
			Event: []byte(sseevent.EventImMessage),
		})
	}
}
