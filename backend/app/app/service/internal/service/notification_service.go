package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	appV1 "go-wind-shortplay/api/gen/go/app/service/v1"
	internalMessageV1 "go-wind-shortplay/api/gen/go/internal_message/service/v1"
)

// unreadStatusFilter 收件状态过滤表达式：未读 = 状态不是 READ。
// 收件记录只会处于 SENT/RECEIVED/READ（REVOKED/DELETED 在 core 即物理删除），
// 故 neq READ 即覆盖全部未读形态；经 go-crud 通用 query 过滤落到收件表 status 列。
const unreadStatusFilter = `{"status___neq":"READ"}`

// withUnreadFilter 组装带未读过滤的查询（PagingRequest 的 query 为 oneof 字段）
func withUnreadFilter() *paginationV1.PagingRequest {
	return &paginationV1.PagingRequest{
		FilteringType: &paginationV1.PagingRequest_Query{Query: unreadStatusFilter},
	}
}

// ── 消息通知（基座 internal_message 域收件箱的 App 端薄转发）──
//
// 数据归属由 core 收件箱仓储强制（recipient_user_id 恒取鉴权上下文调用者，
// 请求体传入的 user_id 一律被忽略），本服务只做参数整形与转发。

type NotificationService struct {
	appV1.NotificationServiceHTTPServer

	log *log.Helper

	messageRecipientServiceClient internalMessageV1.InternalMessageRecipientServiceClient
}

func NewNotificationService(
	ctx *bootstrap.Context,
	messageRecipientServiceClient internalMessageV1.InternalMessageRecipientServiceClient,
) *NotificationService {
	return &NotificationService{
		log:                           ctx.NewLoggerHelper("notification/service/app-service"),
		messageRecipientServiceClient: messageRecipientServiceClient,
	}
}

// ListNotifications 消息通知列表（当前用户收件箱）
func (s *NotificationService) ListNotifications(ctx context.Context, req *appV1.ListNotificationsRequest) (*internalMessageV1.ListUserInboxResponse, error) {
	pageReq := &paginationV1.PagingRequest{
		Page:     req.Page,
		PageSize: req.PageSize,
	}
	if req.GetUnreadOnly() {
		pageReq.FilteringType = &paginationV1.PagingRequest_Query{Query: unreadStatusFilter}
	}
	return s.messageRecipientServiceClient.ListUserInbox(ctx, pageReq)
}

// GetUnreadCount 未读消息数（取未读过滤列表的 total，独立 COUNT 语义）
func (s *NotificationService) GetUnreadCount(ctx context.Context, req *emptypb.Empty) (*appV1.GetUnreadCountResponse, error) {
	pageReq := withUnreadFilter()
	pageReq.Page = trans.Ptr(uint32(1))
	pageReq.PageSize = trans.Ptr(uint32(1))
	resp, err := s.messageRecipientServiceClient.ListUserInbox(ctx, pageReq)
	if err != nil {
		return nil, err
	}
	return &appV1.GetUnreadCountResponse{Count: resp.GetTotal()}, nil
}

// MarkNotificationsRead 将指定收件记录标记为已读
func (s *NotificationService) MarkNotificationsRead(ctx context.Context, req *appV1.MarkNotificationsReadRequest) (*emptypb.Empty, error) {
	if req == nil || len(req.GetRecipientIds()) == 0 {
		return nil, appV1.ErrorBadRequest("recipientIds is required")
	}
	_, err := s.messageRecipientServiceClient.MarkNotificationAsRead(ctx, &internalMessageV1.MarkNotificationAsReadRequest{
		RecipientIds: req.GetRecipientIds(),
	})
	if err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// MarkAllNotificationsRead 全部标记为已读。
// core 的 MarkNotificationAsRead 约定 recipientIds 为空 = 调用者全部未读置已读，
// 直接转发空列表即可，无需先拉未读 ID。
func (s *NotificationService) MarkAllNotificationsRead(ctx context.Context, req *emptypb.Empty) (*emptypb.Empty, error) {
	_, err := s.messageRecipientServiceClient.MarkNotificationAsRead(ctx, &internalMessageV1.MarkNotificationAsReadRequest{})
	if err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}
