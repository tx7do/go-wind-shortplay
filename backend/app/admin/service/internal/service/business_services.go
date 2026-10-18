package service

import (
	"context"
	"encoding/json"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	adminV1 "go-wind-shortplay/api/gen/go/admin/service/v1"
	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	reportV1 "go-wind-shortplay/api/gen/go/report/service/v1"
	statsV1 "go-wind-shortplay/api/gen/go/stats/service/v1"
	sysconfV1 "go-wind-shortplay/api/gen/go/sysconf/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
)

// videoListResponseSP 视频列表响应别名
type videoListResponseSP = videoV1.ListVideoResponse

// ── 举报工单管理（admin BFF 薄转发）──

type ReportService struct {
	adminV1.ReportServiceHTTPServer

	reportClient reportV1.ReportServiceClient
	log          *log.Helper
}

func NewReportService(ctx *bootstrap.Context, reportClient reportV1.ReportServiceClient) *ReportService {
	return &ReportService{
		log:          ctx.NewLoggerHelper("report/service/admin-service"),
		reportClient: reportClient,
	}
}

// spReportStatusFilterValue 状态数字串 → ent 枚举名（1待处理/2已通过/3已驳回）
func spReportStatusFilterValue(filter string) string {
	switch filter {
	case "1":
		return "PENDING"
	case "2":
		return "RESOLVED"
	case "3":
		return "DISMISSED"
	default:
		return ""
	}
}

func (s *ReportService) List(ctx context.Context, req *paginationV1.PagingRequest) (*reportV1.ListReportResponse, error) {
	if req != nil && req.GetQuery() == "" {
		if sv := spReportStatusFilterValue(req.GetFilter()); sv != "" {
			if b, err := json.Marshal(map[string]any{"status": sv}); err == nil {
				setPagingQuerySP(req, string(b))
			}
		}
	}
	return s.reportClient.ListReport(ctx, req)
}

func (s *ReportService) Get(ctx context.Context, req *reportV1.GetReportRequest) (*reportV1.Report, error) {
	return s.reportClient.GetReport(ctx, req)
}

func (s *ReportService) Handle(ctx context.Context, req *reportV1.HandleReportRequest) (*reportV1.Report, error) {
	return s.reportClient.HandleReport(ctx, req)
}

// ── 数据看板（admin BFF 薄转发）──

type DashboardService struct {
	adminV1.DashboardServiceHTTPServer

	dashboardClient statsV1.DashboardServiceClient
	log             *log.Helper
}

func NewDashboardService(ctx *bootstrap.Context, dashboardClient statsV1.DashboardServiceClient) *DashboardService {
	return &DashboardService{
		log:             ctx.NewLoggerHelper("stats/service/admin-service"),
		dashboardClient: dashboardClient,
	}
}

func (s *DashboardService) GetOverview(ctx context.Context, req *statsV1.GetOverviewRequest) (*statsV1.Overview, error) {
	return s.dashboardClient.GetOverview(ctx, req)
}

func (s *DashboardService) ListTopVideos(ctx context.Context, req *statsV1.ListTopVideosRequest) (*videoListResponseSP, error) {
	return s.dashboardClient.ListTopVideos(ctx, req)
}

func (s *DashboardService) Trends(ctx context.Context, req *statsV1.ListTrendsRequest) (*statsV1.ListTrendsResponse, error) {
	return s.dashboardClient.ListTrends(ctx, req)
}

// ── 系统配置（admin BFF 薄转发）──

type SysConfService struct {
	adminV1.SysConfServiceHTTPServer

	sysConfClient sysconfV1.SysConfServiceClient
	log           *log.Helper
}

func NewSysConfService(ctx *bootstrap.Context, sysConfClient sysconfV1.SysConfServiceClient) *SysConfService {
	return &SysConfService{
		log:           ctx.NewLoggerHelper("sysconf/service/admin-service"),
		sysConfClient: sysConfClient,
	}
}

func (s *SysConfService) Get(ctx context.Context, req *emptypb.Empty) (*sysconfV1.SysConf, error) {
	return s.sysConfClient.GetSysConf(ctx, req)
}

func (s *SysConfService) Update(ctx context.Context, req *sysconfV1.UpdateSysConfRequest) (*sysconfV1.SysConf, error) {
	return s.sysConfClient.UpdateSysConf(ctx, req)
}

// ── 评论管理（admin BFF 薄转发，业务评论经 interaction 域）──

type CommentService struct {
	adminV1.CommentServiceHTTPServer

	commentClient interactionV1.CommentServiceClient
	log           *log.Helper
}

func NewCommentService(ctx *bootstrap.Context, commentClient interactionV1.CommentServiceClient) *CommentService {
	return &CommentService{
		log:           ctx.NewLoggerHelper("video-comment/service/admin-service"),
		commentClient: commentClient,
	}
}

func (s *CommentService) List(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListCommentResponse, error) {
	return s.commentClient.AdminList(ctx, req)
}

func (s *CommentService) Delete(ctx context.Context, req *interactionV1.DeleteCommentRequest) (*emptypb.Empty, error) {
	return s.commentClient.DeleteComment(ctx, req)
}
