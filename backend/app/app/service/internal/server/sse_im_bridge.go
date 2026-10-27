package server

import (
	"context"
	"encoding/json"

	"github.com/go-kratos/kratos/v2/log"
	sseLib "github.com/tx7do/kratos-transport/transport/sse"
	"github.com/redis/go-redis/v9"
	"github.com/tx7do/go-utils/id"

	authenticationV1 "go-wind-shortplay/api/gen/go/authentication/service/v1"

	"go-wind-shortplay/pkg/sseevent"
)

// StartImEventSubscriber 订阅 core 服务经 Redis Pub/Sub 发出的私信事件
//（落库在 core 侧完成），转成 SSE 定向推送给收件人全部在线 App 会话。
// 落库为准：本协程只管实时性，崩溃/丢失不影响到达（客户端 REST 拉取对账）。
//
// streamID 约定与 admin 面一致：以 access token 作为流 ID（连接时
// /events?streamId=<token>&token=<token>），一个 token 即一个在线端。
func StartImEventSubscriber(
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
	go func() {
		sub := redisClient.Subscribe(subCtx, sseevent.RedisChannelIm)
		defer func() { _ = sub.Close() }()
		for {
			select {
			case <-subCtx.Done():
				return
			case m := <-sub.Channel():
				var ev sseevent.ImEvent
				if err := json.Unmarshal([]byte(m.Payload), &ev); err != nil {
					l.Errorf("im subscriber: unmarshal event failed: %v", err)
					continue
				}
				pushImEventToUser(subCtx, srv, authenticationServiceClient, l, ev)
			}
		}
	}()

	return cancel
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
