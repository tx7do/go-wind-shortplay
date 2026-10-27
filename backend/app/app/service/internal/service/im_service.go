package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	appV1 "go-wind-shortplay/api/gen/go/app/service/v1"
	imV1 "go-wind-shortplay/api/gen/go/im/service/v1"
)

// ImService 私信（app BFF 薄转发；全部需登录，实时送达走 SSE 桥接，归属校验在 core）。
type ImService struct {
	appV1.ImServiceHTTPServer

	imClient imV1.ImServiceClient
	log      *log.Helper
}

func NewImService(ctx *bootstrap.Context, imClient imV1.ImServiceClient) *ImService {
	return &ImService{
		log:      ctx.NewLoggerHelper("im/service/app-service"),
		imClient: imClient,
	}
}

func (s *ImService) SendMessage(ctx context.Context, req *imV1.SendMessageRequest) (*imV1.Message, error) {
	return s.imClient.SendMessage(ctx, req)
}

func (s *ImService) ListConversations(ctx context.Context, req *paginationV1.PagingRequest) (*imV1.ListConversationsResponse, error) {
	return s.imClient.ListConversations(ctx, req)
}

func (s *ImService) EnsureConversation(ctx context.Context, req *imV1.EnsureConversationRequest) (*imV1.Conversation, error) {
	return s.imClient.EnsureConversation(ctx, req)
}

func (s *ImService) ListMessages(ctx context.Context, req *imV1.ListMessagesRequest) (*imV1.ListMessagesResponse, error) {
	return s.imClient.ListMessages(ctx, req)
}

func (s *ImService) MarkConversationRead(ctx context.Context, req *imV1.MarkConversationReadRequest) (*emptypb.Empty, error) {
	return s.imClient.MarkConversationRead(ctx, req)
}

func (s *ImService) CountUnread(ctx context.Context, req *emptypb.Empty) (*imV1.CountUnreadResponse, error) {
	return s.imClient.CountUnread(ctx, req)
}
