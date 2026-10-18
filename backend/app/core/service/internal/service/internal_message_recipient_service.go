package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	"go-wind-shortplay/app/core/service/internal/data"

	internalMessageV1 "go-wind-shortplay/api/gen/go/internal_message/service/v1"
)

type InternalMessageRecipientService struct {
	internalMessageV1.UnimplementedInternalMessageRecipientServiceServer

	log *log.Helper

	internalMessageRepo          *data.InternalMessageRepo
	internalMessageRecipientRepo *data.InternalMessageRecipientRepo
}

func NewInternalMessageRecipientService(
	ctx *bootstrap.Context,
	internalMessageRepo *data.InternalMessageRepo,
	internalMessageRecipientRepo *data.InternalMessageRecipientRepo,
) *InternalMessageRecipientService {
	return &InternalMessageRecipientService{
		log:                          ctx.NewLoggerHelper("internal-message-recipient/service/core-service"),
		internalMessageRepo:          internalMessageRepo,
		internalMessageRecipientRepo: internalMessageRecipientRepo,
	}
}

// ListUserInbox 获取用户的收件箱列表 (通知类)
func (s *InternalMessageRecipientService) ListUserInbox(ctx context.Context, req *paginationV1.PagingRequest) (*internalMessageV1.ListUserInboxResponse, error) {
	resp, err := s.internalMessageRecipientRepo.List(ctx, req)
	if err != nil {
		return nil, err
	}

	for _, d := range resp.Items {
		if d.MessageId == nil {
			continue
		}

		msg, err := s.internalMessageRepo.Get(ctx, &internalMessageV1.GetInternalMessageRequest{
			QueryBy: &internalMessageV1.GetInternalMessageRequest_Id{
				Id: d.GetMessageId(),
			},
		})
		if err != nil {
			s.log.Errorf("list user inbox failed, get message failed: %s", err)
			continue
		}

		d.Title = msg.Title
		d.Content = msg.Content
	}

	return resp, nil
}

// Create 创建收件行：admin BFF 发送站内信（SendMessage 扇出）时经 gRPC 逐人落地
// 收件记录。收件行落库只能发生在 core（BFF 不碰数据库）；该 RPC 在 proto 契约中
// 已声明，此前未实现导致 admin 发送链路收件行静默丢失（gRPC Unimplemented）。
func (s *InternalMessageRecipientService) Create(ctx context.Context, req *internalMessageV1.CreateInternalMessageRecipientRequest) (*internalMessageV1.InternalMessageRecipient, error) {
	if req == nil || req.Data == nil {
		return nil, internalMessageV1.ErrorBadRequest("invalid parameter")
	}
	return s.internalMessageRecipientRepo.Create(ctx, req.Data)
}

func (s *InternalMessageRecipientService) DeleteNotificationFromInbox(ctx context.Context, req *internalMessageV1.DeleteNotificationFromInboxRequest) (*emptypb.Empty, error) {
	err := s.internalMessageRecipientRepo.DeleteNotificationFromInbox(ctx, req)
	return &emptypb.Empty{}, err
}

// MarkNotificationAsRead 将通知标记为已读
func (s *InternalMessageRecipientService) MarkNotificationAsRead(ctx context.Context, req *internalMessageV1.MarkNotificationAsReadRequest) (*emptypb.Empty, error) {
	err := s.internalMessageRecipientRepo.MarkNotificationAsRead(ctx, req)
	return &emptypb.Empty{}, err
}

// MarkNotificationsStatus 标记特定用户的某些或所有通知的状态
func (s *InternalMessageRecipientService) MarkNotificationsStatus(ctx context.Context, req *internalMessageV1.MarkNotificationsStatusRequest) (*emptypb.Empty, error) {
	err := s.internalMessageRecipientRepo.MarkNotificationsStatus(ctx, req)
	return &emptypb.Empty{}, err
}
