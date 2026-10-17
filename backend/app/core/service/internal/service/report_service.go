package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"

	notifyV1 "go-wind-shortplay/api/gen/go/notify/service/v1"
	reportV1 "go-wind-shortplay/api/gen/go/report/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/pkg/authctx"
)

type ReportService struct {
	reportV1.UnimplementedReportServiceServer

	reportRepo  *data.ReportRepo
	userRepo    *data.UserRepo
	videoRepo   *data.VideoRepo
	commentRepo *data.CommentRepo
	log         *log.Helper
}

func NewReportService(ctx *bootstrap.Context, reportRepo *data.ReportRepo, userRepo *data.UserRepo, videoRepo *data.VideoRepo, commentRepo *data.CommentRepo) *ReportService {
	return &ReportService{
		reportRepo:  reportRepo,
		userRepo:    userRepo,
		videoRepo:   videoRepo,
		commentRepo: commentRepo,
		log:         ctx.NewLoggerHelper("report/service/core-service"),
	}
}

func (s *ReportService) CreateReport(ctx context.Context, req *reportV1.CreateReportRequest) (*reportV1.Report, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, reportV1.ErrorUnauthorized("login required")
	}
	// 同目标待处理工单去重
	pending, err := s.reportRepo.HasPending(ctx, uid, uint8(req.GetTargetType()), req.GetTargetId())
	if err != nil {
		return nil, reportV1.ErrorInternalServerError("query report failed")
	}
	if pending {
		return nil, reportV1.ErrorDuplicateReport("duplicate report")
	}
	r, err := s.reportRepo.Create(ctx, uid, uint8(req.GetTargetType()), req.GetTargetId(), ptr(req.GetReason()), req.Description)
	if err != nil {
		return nil, reportV1.ErrorInternalServerError("create report failed")
	}
	u, _ := s.userRepo.GetByID(ctx, uid)
	return toReport(r, toUserBrief(u)), nil
}

func (s *ReportService) GetReport(ctx context.Context, req *reportV1.GetReportRequest) (*reportV1.Report, error) {
	r, err := s.reportRepo.GetByID(ctx, req.GetId())
	if err != nil {
		return nil, reportV1.ErrorReportNotFound("report not found")
	}
	return s.toReportWithUser(ctx, r), nil
}

func (s *ReportService) ListReport(ctx context.Context, req *paginationV1.PagingRequest) (*reportV1.ListReportResponse, error) {
	offset, limit := pageArgs(req.GetPage(), req.GetPageSize())
	var status *uint8
	if req.GetFilter() != "" {
		// 约定：filter 传状态数字（1 待处理 / 2 已通过 / 3 已驳回）
		v := parseUint8(req.GetFilter())
		status = &v
	}
	items, total, err := s.reportRepo.List(ctx, status, offset, limit)
	if err != nil {
		return nil, reportV1.ErrorInternalServerError("list reports failed")
	}
	out := make([]*reportV1.Report, 0, len(items))
	for _, it := range items {
		out = append(out, s.toReportWithUser(ctx, it))
	}
	return &reportV1.ListReportResponse{Items: out, Total: ptr(int64(total))}, nil
}

// HandleReport 处理工单：通过 → 联动处置目标（视频下架 / 评论删除）；驳回 → 仅关闭
func (s *ReportService) HandleReport(ctx context.Context, req *reportV1.HandleReportRequest) (*reportV1.Report, error) {
	r, err := s.reportRepo.GetByID(ctx, req.GetId())
	if err != nil {
		return nil, reportV1.ErrorReportNotFound("report not found")
	}
	if r.Status != nil && *r.Status != 1 {
		return nil, reportV1.ErrorReportAlreadyHandled("report already handled")
	}

	newStatus := uint8(3) // dismissed
	if req.GetAction() == reportV1.HandleAction_HANDLE_ACTION_RESOLVE {
		newStatus = uint8(2) // resolved
		if err := s.resolveTarget(ctx, r); err != nil {
			return nil, err
		}
	}

	handledBy := authctx.UserIDFromContext(ctx)
	var note *string
	if req.Note != nil {
		note = req.Note
	}
	updated, err := s.reportRepo.Handle(ctx, req.GetId(), newStatus, handledBy, note)
	if err != nil {
		return nil, reportV1.ErrorInternalServerError("handle report failed")
	}
	return s.toReportWithUser(ctx, updated), nil
}

// resolveTarget 处置举报目标
func (s *ReportService) resolveTarget(ctx context.Context, r *ent.VideoReport) error {
	if r.TargetType == nil || r.TargetID == nil {
		return nil
	}
	switch *r.TargetType {
	case 1: // 视频 → 下架
		if _, err := s.videoRepo.ChangeStatus(ctx, *r.TargetID, uint8(videoV1.VideoStatus_VIDEO_STATUS_OFFLINE), ptr("举报处置下架")); err != nil {
			return reportV1.ErrorInternalServerError("offline video failed")
		}
	case 2: // 评论 → 删除
		if err := s.commentRepo.Delete(ctx, *r.TargetID); err != nil {
			return reportV1.ErrorInternalServerError("delete comment failed")
		}
	}
	return nil
}

func (s *ReportService) toReportWithUser(ctx context.Context, r *ent.VideoReport) *reportV1.Report {
	var reporter *ent.User
	if r.ReporterID != nil {
		reporter, _ = s.userRepo.GetByID(ctx, *r.ReporterID)
	}
	return toReport(r, toUserBrief(reporter))
}

func parseUint8(s string) uint8 {
	var v uint64
	for i := 0; i < len(s); i++ {
		if s[i] < '0' || s[i] > '9' {
			return 0
		}
		v = v*10 + uint64(s[i]-'0')
	}
	return uint8(v)
}

// ── NotificationService ──

type NotificationService struct {
	notifyV1.UnimplementedNotifyServiceServer

	notifyRepo *data.NotificationRepo
	userRepo   *data.UserRepo
	log        *log.Helper
}

func NewNotificationService(ctx *bootstrap.Context, notifyRepo *data.NotificationRepo, userRepo *data.UserRepo) *NotificationService {
	return &NotificationService{
		notifyRepo: notifyRepo,
		userRepo:   userRepo,
		log:        ctx.NewLoggerHelper("notify/service/core-service"),
	}
}

func (s *NotificationService) ListNotification(ctx context.Context, req *notifyV1.ListNotificationRequest) (*notifyV1.ListNotificationResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, notifyV1.ErrorUnauthorized("login required")
	}
	offset, limit := pageArgs(req.GetPageNum(), req.GetPageSize())
	items, total, err := s.notifyRepo.List(ctx, uid, req.GetUnreadOnly(), offset, limit)
	if err != nil {
		return nil, notifyV1.ErrorInternalServerError("list notifications failed")
	}
	unread, _ := s.notifyRepo.UnreadCount(ctx, uid)

	out := make([]*notifyV1.Notification, 0, len(items))
	for _, it := range items {
		var sender *ent.User
		if it.SenderID != nil && *it.SenderID > 0 {
			sender, _ = s.userRepo.GetByID(ctx, *it.SenderID)
		}
		out = append(out, toNotification(it, toUserBrief(sender)))
	}
	return &notifyV1.ListNotificationResponse{
		Items:       out,
		Total:       ptr(int64(total)),
		UnreadCount: ptr(int64(unread)),
	}, nil
}

func (s *NotificationService) MarkRead(ctx context.Context, req *notifyV1.MarkReadRequest) (*emptypb.Empty, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, notifyV1.ErrorUnauthorized("login required")
	}
	if err := s.notifyRepo.MarkRead(ctx, uid, req.GetIds()); err != nil {
		return nil, notifyV1.ErrorInternalServerError("mark read failed")
	}
	return &emptypb.Empty{}, nil
}

func (s *NotificationService) MarkAllRead(ctx context.Context, _ *emptypb.Empty) (*emptypb.Empty, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, notifyV1.ErrorUnauthorized("login required")
	}
	if err := s.notifyRepo.MarkAllRead(ctx, uid); err != nil {
		return nil, notifyV1.ErrorInternalServerError("mark all read failed")
	}
	return &emptypb.Empty{}, nil
}

func (s *NotificationService) GetUnreadCount(ctx context.Context, _ *emptypb.Empty) (*notifyV1.GetUnreadCountResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, notifyV1.ErrorUnauthorized("login required")
	}
	n, err := s.notifyRepo.UnreadCount(ctx, uid)
	if err != nil {
		return nil, notifyV1.ErrorInternalServerError("query unread count failed")
	}
	return &notifyV1.GetUnreadCountResponse{Count: int64(n)}, nil
}
