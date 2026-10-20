package data

import (
	"context"
	"encoding/json"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/go-utils/timeutil"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/predicate"
	"go-wind-shortplay/app/core/service/internal/data/ent/videocomment"
	"go-wind-shortplay/app/core/service/internal/data/ent/videoreport"

	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	reportV1 "go-wind-shortplay/api/gen/go/report/service/v1"
)

// ── 视频评论 ──

type VideoCommentRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewVideoCommentRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *VideoCommentRepo {
	return &VideoCommentRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("video-comment/repo/core-service"),
	}
}

func commentEntityToDTO(e *ent.VideoComment, user *identityV1.UserBrief) *interactionV1.Comment {
	if e == nil {
		return nil
	}
	return &interactionV1.Comment{
		Id:        trans.Ptr(e.ID),
		VideoId:   trans.Ptr(e.VideoID),
		UserId:    trans.Ptr(e.UserID),
		User:      user,
		Content:   trans.Ptr(e.Content),
		ParentId:  trans.Ptr(e.ParentID),
		LikeCount: trans.Ptr(e.LikeCount),
		ReplyCount: trans.Ptr(e.ReplyCount),
		CreatedAt: timeutil.TimeToTimestamppb(e.CreatedAt),
	}
}

func (r *VideoCommentRepo) Get(ctx context.Context, id uint32) (*ent.VideoComment, error) {
	e, err := r.entClient.Client().VideoComment.Query().Where(videocomment.IDEQ(id)).Only(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, interactionV1.ErrorCommentNotFound("comment not found")
		}
		r.log.Errorf("get comment failed: %s", err.Error())
		return nil, interactionV1.ErrorInternalServerError("get comment failed")
	}
	return e, nil
}

// ListByVideo 视频评论列表（分页；sort：HOT 按点赞/回复数加权倒序，否则时间倒序。
// parentID=nil 一级 / 非 nil 仅该父级回复 / sentinel 全部）
func (r *VideoCommentRepo) ListByVideo(ctx context.Context, videoID uint32, parentID *uint32, page, pageSize uint32, hotSort bool) ([]*ent.VideoComment, int, error) {
	if page < 1 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	if pageSize > 50 {
		pageSize = 50
	}
	ps := []predicate.VideoComment{videocomment.VideoIDEQ(videoID)}
	if parentID != nil {
		ps = append(ps, videocomment.ParentIDEQ(*parentID))
	}
	q := r.entClient.Client().VideoComment.Query().Where(ps...)
	total, err := q.Count(ctx)
	if err != nil {
		r.log.Errorf("count comments failed: %s", err.Error())
		return nil, 0, interactionV1.ErrorInternalServerError("count comments failed")
	}
	if hotSort {
		// 最热：点赞为主、回复数加权，id 兜底稳定序
		q.Order(ent.Desc(videocomment.FieldLikeCount), ent.Desc(videocomment.FieldReplyCount), ent.Desc(videocomment.FieldID))
	} else {
		q.Order(ent.Desc(videocomment.FieldCreatedAt), ent.Desc(videocomment.FieldID))
	}
	items, err := q.
		Offset(int(page-1) * int(pageSize)).Limit(int(pageSize)).All(ctx)
	if err != nil {
		r.log.Errorf("list comments failed: %s", err.Error())
		return nil, 0, interactionV1.ErrorInternalServerError("list comments failed")
	}
	return items, total, nil
}

// ListReplies 楼中楼回复列表
func (r *VideoCommentRepo) ListReplies(ctx context.Context, commentID uint32, page, pageSize uint32) ([]*ent.VideoComment, int, error) {
	pid := commentID
	q := r.entClient.Client().VideoComment.Query().Where(videocomment.ParentIDEQ(pid))
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, interactionV1.ErrorInternalServerError("count replies failed")
	}
	if page < 1 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	if pageSize > 50 {
		pageSize = 50
	}
	items, err := q.Order(ent.Asc(videocomment.FieldCreatedAt)).
		Offset(int(page-1) * int(pageSize)).Limit(int(pageSize)).All(ctx)
	if err != nil {
		return nil, 0, interactionV1.ErrorInternalServerError("list replies failed")
	}
	return items, total, nil
}

// spCommentAdminFilter admin 评论列表过滤
type spCommentAdminFilter struct {
	Content *string `json:"content___icontains"`
	VideoID *uint32 `json:"video_id"`
}

// ListAdmin 管理端全量评论列表
func (r *VideoCommentRepo) ListAdmin(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListCommentResponse, error) {
	page := int(req.GetPage())
	if page < 1 {
		page = 1
	}
	size := int(req.GetPageSize())
	if size <= 0 {
		size = 10
	}
	if size > 50 {
		size = 50
	}

	var ps []predicate.VideoComment
	if req.GetQuery() != "" {
		var f spCommentAdminFilter
		if err := json.Unmarshal([]byte(req.GetQuery()), &f); err == nil {
			if f.Content != nil && *f.Content != "" {
				ps = append(ps, videocomment.ContentContainsFold(*f.Content))
			}
			if f.VideoID != nil && *f.VideoID > 0 {
				ps = append(ps, videocomment.VideoIDEQ(*f.VideoID))
			}
		}
	}

	q := r.entClient.Client().VideoComment.Query()
	if len(ps) > 0 {
		q.Where(ps...)
	}
	total, err := q.Count(ctx)
	if err != nil {
		r.log.Errorf("count comments failed: %s", err.Error())
		return nil, interactionV1.ErrorInternalServerError("count comments failed")
	}
	items, err := q.Order(ent.Desc(videocomment.FieldCreatedAt)).
		Offset((page - 1) * size).Limit(size).All(ctx)
	if err != nil {
		r.log.Errorf("list comments failed: %s", err.Error())
		return nil, interactionV1.ErrorInternalServerError("list comments failed")
	}
	resp := &interactionV1.ListCommentResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		resp.Items = append(resp.Items, commentEntityToDTO(e, nil))
	}
	return resp, nil
}

func (r *VideoCommentRepo) Create(ctx context.Context, videoID, userID uint32, content string, parentID uint32) (*ent.VideoComment, error) {
	builder := r.entClient.Client().VideoComment.Create().
		SetVideoID(videoID).
		SetUserID(userID).
		SetContent(content).
		SetParentID(parentID).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	if userID > 0 {
		builder.SetCreatedBy(userID)
	}
	e, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("create comment failed: %s", err.Error())
		return nil, interactionV1.ErrorInternalServerError("create comment failed")
	}
	return e, nil
}

func (r *VideoCommentRepo) Delete(ctx context.Context, id uint32) error {
	err := r.entClient.Client().VideoComment.DeleteOneID(id).Exec(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return interactionV1.ErrorCommentNotFound("comment not found")
		}
		r.log.Errorf("delete comment failed: %s", err.Error())
		return interactionV1.ErrorInternalServerError("delete comment failed")
	}
	return nil
}

// IncReplyCount 一级评论回复数 +1
func (r *VideoCommentRepo) IncReplyCount(ctx context.Context, tx *ent.Tx, commentID uint32) error {
	return tx.VideoComment.UpdateOneID(commentID).AddReplyCount(1).Exec(ctx)
}

// CreateWithCounter 评论创建：评论行 + 视频评论计数 + 父评论回复数（同事务，铁律 5）。
func (r *VideoCommentRepo) CreateWithCounter(ctx context.Context, userID, videoID uint32, content string, parentID uint32) (e *ent.VideoComment, err error) {
	tx, terr := r.entClient.Client().Tx(ctx)
	if terr != nil {
		return nil, interactionV1.ErrorInternalServerError("start transaction failed")
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
			return
		}
		err = tx.Commit()
	}()

	builder := tx.VideoComment.Create().
		SetVideoID(videoID).
		SetUserID(userID).
		SetContent(content).
		SetParentID(parentID).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	if userID > 0 {
		builder.SetCreatedBy(userID)
	}
	e, err = builder.Save(ctx)
	if err != nil {
		r.log.Errorf("create comment failed: %s", err.Error())
		return nil, interactionV1.ErrorInternalServerError("create comment failed")
	}

	if err = tx.Video.UpdateOneID(videoID).AddCommentCount(1).Exec(ctx); err != nil {
		r.log.Errorf("inc comment count failed: %s", err.Error())
		return nil, interactionV1.ErrorInternalServerError("inc comment count failed")
	}
	if parentID > 0 {
		if err = tx.VideoComment.UpdateOneID(parentID).AddReplyCount(1).Exec(ctx); err != nil {
			r.log.Errorf("inc reply count failed: %s", err.Error())
			return nil, interactionV1.ErrorInternalServerError("inc reply count failed")
		}
	}
	return e, nil
}

// DeleteWithCounter 评论删除：删行 + 视频评论计数 -1 + 父评论回复数 -1（同事务）。
func (r *VideoCommentRepo) DeleteWithCounter(ctx context.Context, e *ent.VideoComment) (err error) {
	tx, terr := r.entClient.Client().Tx(ctx)
	if terr != nil {
		return interactionV1.ErrorInternalServerError("start transaction failed")
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
			return
		}
		err = tx.Commit()
	}()

	if err = tx.VideoComment.DeleteOneID(e.ID).Exec(ctx); err != nil {
		r.log.Errorf("delete comment failed: %s", err.Error())
		return interactionV1.ErrorInternalServerError("delete comment failed")
	}
	if err = tx.Video.UpdateOneID(e.VideoID).AddCommentCount(-1).Exec(ctx); err != nil {
		r.log.Errorf("dec comment count failed: %s", err.Error())
		return interactionV1.ErrorInternalServerError("dec comment count failed")
	}
	if e.ParentID > 0 {
		if err = tx.VideoComment.UpdateOneID(e.ParentID).AddReplyCount(-1).Exec(ctx); err != nil {
			r.log.Errorf("dec reply count failed: %s", err.Error())
			return interactionV1.ErrorInternalServerError("dec reply count failed")
		}
	}
	return nil
}

// ── 举报 ──

type ReportRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewReportRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *ReportRepo {
	return &ReportRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("report/repo/core-service"),
	}
}

func reportTargetEntity(t reportV1.ReportTargetType) videoreport.TargetType {
	switch t {
	case reportV1.ReportTargetType_REPORT_TARGET_TYPE_COMMENT:
		return videoreport.TargetTypeComment
	case reportV1.ReportTargetType_REPORT_TARGET_TYPE_USER:
		return videoreport.TargetTypeUser
	default:
		return videoreport.TargetTypeVideo
	}
}

func reportTargetDTO(t videoreport.TargetType) reportV1.ReportTargetType {
	switch t {
	case videoreport.TargetTypeComment:
		return reportV1.ReportTargetType_REPORT_TARGET_TYPE_COMMENT
	case videoreport.TargetTypeUser:
		return reportV1.ReportTargetType_REPORT_TARGET_TYPE_USER
	default:
		return reportV1.ReportTargetType_REPORT_TARGET_TYPE_VIDEO
	}
}

func reportStatusEntity(s reportV1.ReportStatus) videoreport.Status {
	switch s {
	case reportV1.ReportStatus_REPORT_STATUS_RESOLVED:
		return videoreport.StatusResolved
	case reportV1.ReportStatus_REPORT_STATUS_DISMISSED:
		return videoreport.StatusDismissed
	default:
		return videoreport.StatusPending
	}
}

func reportStatusDTO(s videoreport.Status) reportV1.ReportStatus {
	switch s {
	case videoreport.StatusResolved:
		return reportV1.ReportStatus_REPORT_STATUS_RESOLVED
	case videoreport.StatusDismissed:
		return reportV1.ReportStatus_REPORT_STATUS_DISMISSED
	default:
		return reportV1.ReportStatus_REPORT_STATUS_PENDING
	}
}

func reportEntityToDTO(e *ent.VideoReport, reporter *identityV1.UserBrief) *reportV1.Report {
	if e == nil {
		return nil
	}
	return &reportV1.Report{
		Id:          trans.Ptr(e.ID),
		ReporterId:  trans.Ptr(e.ReporterID),
		Reporter:    reporter,
		TargetType:  reportTargetDTO(e.TargetType).Enum(),
		TargetId:    trans.Ptr(e.TargetID),
		Reason:      trans.Ptr(e.Reason),
		Description: e.Description,
		Status:      reportStatusDTO(e.Status).Enum(),
		HandledBy:   trans.Ptr(e.HandledBy),
		HandleNote:  e.HandleNote,
		HandledAt:   timeutil.TimeToTimestamppb(e.HandledAt),
		CreatedAt:   timeutil.TimeToTimestamppb(e.CreatedAt),
	}
}

// spReportAdminFilter admin 举报列表过滤
type spReportAdminFilter struct {
	Status *string `json:"status"`
}

func (r *ReportRepo) adminFilter(req *paginationV1.PagingRequest) []predicate.VideoReport {
	if req.GetQuery() == "" {
		return nil
	}
	var f spReportAdminFilter
	if err := json.Unmarshal([]byte(req.GetQuery()), &f); err != nil {
		return nil
	}
	if f.Status != nil && *f.Status != "" {
		return []predicate.VideoReport{videoreport.StatusEQ(videoreport.Status(*f.Status))}
	}
	return nil
}

func (r *ReportRepo) Get(ctx context.Context, id uint32) (*ent.VideoReport, error) {
	e, err := r.entClient.Client().VideoReport.Query().Where(videoreport.IDEQ(id)).Only(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, reportV1.ErrorReportNotFound("report not found")
		}
		r.log.Errorf("get report failed: %s", err.Error())
		return nil, reportV1.ErrorInternalServerError("get report failed")
	}
	return e, nil
}

// List 管理端工单列表（分页 + 状态过滤）
func (r *ReportRepo) List(ctx context.Context, req *paginationV1.PagingRequest) (*reportV1.ListReportResponse, error) {
	page := int(req.GetPage())
	if page < 1 {
		page = 1
	}
	size := int(req.GetPageSize())
	if size <= 0 {
		size = 10
	}
	if size > 50 {
		size = 50
	}
	ps := r.adminFilter(req)
	q := r.entClient.Client().VideoReport.Query()
	if len(ps) > 0 {
		q.Where(ps...)
	}
	total, err := q.Count(ctx)
	if err != nil {
		r.log.Errorf("count reports failed: %s", err.Error())
		return nil, reportV1.ErrorInternalServerError("count reports failed")
	}
	items, err := q.Order(ent.Desc(videoreport.FieldCreatedAt)).
		Offset((page - 1) * size).Limit(size).All(ctx)
	if err != nil {
		r.log.Errorf("list reports failed: %s", err.Error())
		return nil, reportV1.ErrorInternalServerError("list reports failed")
	}
	resp := &reportV1.ListReportResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		resp.Items = append(resp.Items, reportEntityToDTO(e, nil))
	}
	return resp, nil
}

// HasPendingOfTarget 同目标同举报人的待处理工单是否已存在（防重复举报）
func (r *ReportRepo) HasPendingOfTarget(ctx context.Context, reporterID uint32, t reportV1.ReportTargetType, targetID uint32) (bool, error) {
	return r.entClient.Client().VideoReport.Query().
		Where(
			videoreport.ReporterIDEQ(reporterID),
			videoreport.TargetTypeEQ(reportTargetEntity(t)),
			videoreport.TargetIDEQ(targetID),
			videoreport.StatusEQ(videoreport.StatusPending),
		).Exist(ctx)
}

func (r *ReportRepo) Create(ctx context.Context, reporterID uint32, t reportV1.ReportTargetType, targetID uint32, reason, description string) (*ent.VideoReport, error) {
	builder := r.entClient.Client().VideoReport.Create().
		SetReporterID(reporterID).
		SetTargetType(reportTargetEntity(t)).
		SetTargetID(targetID).
		SetReason(reason).
		SetDescription(description).
		SetStatus(videoreport.StatusPending).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	if reporterID > 0 {
		builder.SetCreatedBy(reporterID)
	}
	e, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("create report failed: %s", err.Error())
		return nil, reportV1.ErrorInternalServerError("create report failed")
	}
	return e, nil
}

func (r *ReportRepo) UpdateHandle(ctx context.Context, id uint32, status reportV1.ReportStatus, handledBy uint32, note string) (*ent.VideoReport, error) {
	now := time.Now()
	builder := r.entClient.Client().VideoReport.UpdateOneID(id).
		SetStatus(reportStatusEntity(status)).
		SetHandledBy(handledBy).
		SetHandleNote(note).
		SetHandledAt(now).
		SetUpdatedAt(now)
	e, err := builder.Save(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, reportV1.ErrorReportNotFound("report not found")
		}
		r.log.Errorf("update report failed: %s", err.Error())
		return nil, reportV1.ErrorInternalServerError("update report failed")
	}
	return e, nil
}

// CountPending 待处理工单数
func (r *ReportRepo) CountPending(ctx context.Context) (int, error) {
	return r.entClient.Client().VideoReport.Query().Where(videoreport.StatusEQ(videoreport.StatusPending)).Count(ctx)
}
