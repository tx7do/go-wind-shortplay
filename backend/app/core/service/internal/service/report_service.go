package service

import (
	"context"
	"strconv"
	"strings"

	crudViewer "github.com/tx7do/go-crud/viewer"
	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/go-utils/timeutil"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"

	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/videoreport"

	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	reportV1 "go-wind-shortplay/api/gen/go/report/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"

	appViewer "go-wind-shortplay/pkg/entgo/viewer"
)

// InternalMessageNotifier 站内信系统能力（由 InternalMessageService 实现，装配期注入）。
type InternalMessageNotifier interface {
	// SendSystemNotification 系统事件通知（基座通知域投递缝，见 internal_message_service.go）。
	SendSystemNotification(ctx context.Context, title, content string, targetUserIDs []uint32) (uint32, error)
}

// SuperAdminResolver 超管用户 ID 解析（举报通知收件人，由 RoleService 实现）。
type SuperAdminResolver interface {
	ListSuperAdminUserIDs(ctx context.Context) ([]uint32, error)
}

type ReportService struct {
	reportV1.UnimplementedReportServiceServer

	log *log.Helper

	reportRepo  *data.ReportRepo
	userRepo    data.UserRepo
	videoRepo   *data.VideoRepo
	commentRepo *data.VideoCommentRepo

	internalMessage InternalMessageNotifier
	superAdmins     SuperAdminResolver
}

func NewReportService(
	ctx *bootstrap.Context,
	reportRepo *data.ReportRepo,
	userRepo data.UserRepo,
	videoRepo *data.VideoRepo,
	commentRepo *data.VideoCommentRepo,
) *ReportService {
	return &ReportService{
		log:         ctx.NewLoggerHelper("report/service/core-service"),
		reportRepo:  reportRepo,
		userRepo:    userRepo,
		videoRepo:   videoRepo,
		commentRepo: commentRepo,
	}
}

// RegisterNotifier 注入站内信通知能力。
func (s *ReportService) RegisterNotifier(n InternalMessageNotifier) {
	s.internalMessage = n
}

// RegisterSuperAdminResolver 注入超管解析。
func (s *ReportService) RegisterSuperAdminResolver(r SuperAdminResolver) {
	s.superAdmins = r
}

func (s *ReportService) CreateReport(ctx context.Context, req *reportV1.CreateReportRequest) (*reportV1.Report, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, reportV1.ErrorUnauthorized("login required")
	}
	if req.GetTargetId() == 0 || strings.TrimSpace(req.GetReason()) == "" {
		return nil, reportV1.ErrorBadRequest("invalid parameter")
	}
	if req.GetTargetType() == reportV1.ReportTargetType_REPORT_TARGET_TYPE_UNSPECIFIED {
		return nil, reportV1.ErrorBadRequest("invalid target type")
	}

	// 同目标同举报人的待处理工单视为重复
	dup, err := s.reportRepo.HasPendingOfTarget(ctx, uid, req.GetTargetType(), req.GetTargetId())
	if err != nil {
		return nil, err
	}
	if dup {
		return nil, reportV1.ErrorDuplicateReport("duplicate report")
	}

	e, err := s.reportRepo.Create(ctx, uid, req.GetTargetType(), req.GetTargetId(), req.GetReason(), req.GetDescription())
	if err != nil {
		return nil, err
	}

	// 通知所有超管（基座 internal_message 机制，尽力而为不阻塞）
	s.notifySuperAdmins(ctx, e.ID, req)

	dto := reportEntityToDTO(e)
	if u, uerr := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
		QueryBy: &identityV1.GetUserRequest_Id{Id: uid},
	}); uerr == nil {
		dto.Reporter = toUserBriefSP(u)
	}
	return dto, nil
}

// spBizMarkerPrefix 站内信 content 机器可读尾标记前缀（方案 A）：
// content 最后一行为独立一行 "sp-biz:{...}"，JSON 载荷按业务类型携带跳转
// 定位字段——视频类通知为 {"videoId":<id>}。客户端解析该行提取 videoId 实现
// 点击直达视频详情；无标记或解析失败一律视为普通文本通知（向后兼容）。
// 该行由展示端剔除，不影响人读文案。
const spBizMarkerPrefix = "\nsp-biz:"

// notifySuperAdmins 经基座通知域投递缝给全部超管发站内信。
// 整条链路固定以系统 viewer 执行：举报请求携带租户用户上下文，直接透传会让
// 消息/收件行被 TenantPrivacy 强注举报者租户（收件人租户归属失真），且超管角色
// 解析在租户过滤下命不中平台级 platform:admin。
func (s *ReportService) notifySuperAdmins(ctx context.Context, reportID uint32, req *reportV1.CreateReportRequest) {
	if s.internalMessage == nil || s.superAdmins == nil {
		return
	}
	ctx = appViewer.NewSystemViewerContext(ctx)
	adminIDs, err := s.superAdmins.ListSuperAdminUserIDs(ctx)
	if err != nil || len(adminIDs) == 0 {
		s.log.Warnf("report notify: no super admins resolved (err=%v)", err)
		return
	}
	title := "新举报工单待处理"
	content := "工单 #" + strconv.FormatUint(uint64(reportID), 10) +
		"：目标类型=" + req.GetTargetType().String() +
		"，目标ID=" + strconv.FormatUint(uint64(req.GetTargetId()), 10) +
		"，原因=" + req.GetReason()
	// 视频举报在 content 末尾追加机器可读尾标记（约定见 spBizMarkerPrefix），
	// 供客户端点击通知直达视频详情；其余目标类型不带标记。
	if req.GetTargetType() == reportV1.ReportTargetType_REPORT_TARGET_TYPE_VIDEO {
		content += spBizMarkerPrefix + `{"videoId":` + strconv.FormatUint(uint64(req.GetTargetId()), 10) + `}`
	}
	if _, err = s.internalMessage.SendSystemNotification(ctx, title, content, adminIDs); err != nil {
		s.log.Errorf("report notify super admins failed: %v", err)
	}
}

func (s *ReportService) GetReport(ctx context.Context, req *reportV1.GetReportRequest) (*reportV1.Report, error) {
	e, err := s.reportRepo.Get(ctx, req.GetId())
	if err != nil {
		return nil, err
	}
	dto := reportEntityToDTO(e)
	if e.ReporterID > 0 {
		if u, uerr := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
			QueryBy: &identityV1.GetUserRequest_Id{Id: e.ReporterID},
		}); uerr == nil {
			dto.Reporter = toUserBriefSP(u)
		}
	}
	dto.HandledAt = timeutil.TimeToTimestamppb(e.HandledAt)
	dto.CreatedAt = timeutil.TimeToTimestamppb(e.CreatedAt)
	return dto, nil
}

func (s *ReportService) ListReport(ctx context.Context, req *paginationV1.PagingRequest) (*reportV1.ListReportResponse, error) {
	resp, err := s.reportRepo.List(ctx, req)
	if err != nil {
		return nil, err
	}
	for _, item := range resp.GetItems() {
		if item.GetReporterId() == 0 {
			continue
		}
		if u, uerr := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
			QueryBy: &identityV1.GetUserRequest_Id{Id: item.GetReporterId()},
		}); uerr == nil {
			item.Reporter = toUserBriefSP(u)
		}
	}
	return resp, nil
}

// HandleReport 处理工单：RESOLVE 联动处置目标；DISMISS 仅关闭工单。
func (s *ReportService) HandleReport(ctx context.Context, req *reportV1.HandleReportRequest) (*reportV1.Report, error) {
	e, err := s.reportRepo.Get(ctx, req.GetId())
	if err != nil {
		return nil, err
	}
	if e.Status != videoreport.StatusPending {
		return nil, reportV1.ErrorReportAlreadyHandled("report already handled")
	}

	handlerID := spViewerUserID(ctx)
	status := reportV1.ReportStatus_REPORT_STATUS_DISMISSED
	if req.GetAction() == reportV1.HandleAction_HANDLE_ACTION_RESOLVE {
		status = reportV1.ReportStatus_REPORT_STATUS_RESOLVED
		// 联动处置目标（尽力而为，失败不阻塞工单关闭）
		s.disposeTarget(ctx, e)
	}

	e2, err := s.reportRepo.UpdateHandle(ctx, req.GetId(), status, handlerID, req.GetNote())
	if err != nil {
		return nil, err
	}
	dto := reportEntityToDTO(e2)
	if e.ReporterID > 0 {
		if u, uerr := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
			QueryBy: &identityV1.GetUserRequest_Id{Id: e.ReporterID},
		}); uerr == nil {
			dto.Reporter = toUserBriefSP(u)
		}
	}
	dto.HandledAt = timeutil.TimeToTimestamppb(e2.HandledAt)
	dto.CreatedAt = timeutil.TimeToTimestamppb(e2.CreatedAt)
	return dto, nil
}

// disposeTarget 处置举报目标：视频下架、评论删除；用户类目标交由管理员人工处理。
func (s *ReportService) disposeTarget(ctx context.Context, e *ent.VideoReport) {
	switch e.TargetType {
	case videoreport.TargetTypeVideo:
		offline := videoV1.VideoStatus_VIDEO_STATUS_OFFLINE
		if _, err := s.videoRepo.Update(ctx, e.TargetID, &videoV1.Video{Status: offline.Enum()}, nil); err != nil {
			s.log.Errorf("dispose report target video failed: %s", err.Error())
		}
	case videoreport.TargetTypeComment:
		if c, err := s.commentRepo.Get(ctx, e.TargetID); err == nil {
			_ = s.commentRepo.DeleteWithCounter(ctx, c)
		}
	}
}

// reportEntityToDTO 服务层 Report 实体 → DTO（枚举显式映射）
func reportEntityToDTO(e *ent.VideoReport) *reportV1.Report {
	if e == nil {
		return nil
	}
	var status reportV1.ReportStatus
	switch e.Status {
	case videoreport.StatusResolved:
		status = reportV1.ReportStatus_REPORT_STATUS_RESOLVED
	case videoreport.StatusDismissed:
		status = reportV1.ReportStatus_REPORT_STATUS_DISMISSED
	default:
		status = reportV1.ReportStatus_REPORT_STATUS_PENDING
	}
	var t reportV1.ReportTargetType
	switch e.TargetType {
	case videoreport.TargetTypeComment:
		t = reportV1.ReportTargetType_REPORT_TARGET_TYPE_COMMENT
	case videoreport.TargetTypeUser:
		t = reportV1.ReportTargetType_REPORT_TARGET_TYPE_USER
	default:
		t = reportV1.ReportTargetType_REPORT_TARGET_TYPE_VIDEO
	}
	return &reportV1.Report{
		Id:          trans.Ptr(e.ID),
		ReporterId:  trans.Ptr(e.ReporterID),
		TargetType:  t.Enum(),
		TargetId:    trans.Ptr(e.TargetID),
		Reason:      trans.Ptr(e.Reason),
		Description: e.Description,
		Status:      status.Enum(),
		HandledBy:   trans.Ptr(e.HandledBy),
		HandleNote:  e.HandleNote,
	}
}

// 保持 go-crud viewer 引用（与 base 服务同款上下文提取口径）
var _ = crudViewer.FromContext
