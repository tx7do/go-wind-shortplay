package data

import (
	"context"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/videoreport"
)

// ReportRepo 举报工单仓储
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

func (r *ReportRepo) Client() *ent.Client {
	return r.entClient.Client()
}

func (r *ReportRepo) GetByID(ctx context.Context, id uint32) (*ent.VideoReport, error) {
	return r.Client().VideoReport.Query().Where(videoreport.ID(id)).Only(ctx)
}

// HasPending 同一举报人对同一目标的待处理工单（防重复举报）
func (r *ReportRepo) HasPending(ctx context.Context, reporterID uint32, targetType uint8, targetID uint32) (bool, error) {
	return r.Client().VideoReport.Query().
		Where(
			videoreport.ReporterID(reporterID),
			videoreport.TargetType(targetType),
			videoreport.TargetID(targetID),
			videoreport.Status(1),
		).
		Exist(ctx)
}

func (r *ReportRepo) Create(ctx context.Context, reporterID uint32, targetType uint8, targetID uint32, reason, description *string) (*ent.VideoReport, error) {
	return r.Client().VideoReport.Create().
		SetReporterID(reporterID).
		SetTargetType(targetType).
		SetTargetID(targetID).
		SetReason(*reason).
		SetNillableDescription(description).
		SetStatus(1).
		Save(ctx)
}

func (r *ReportRepo) List(ctx context.Context, status *uint8, offset, limit int) ([]*ent.VideoReport, int, error) {
	q := r.Client().VideoReport.Query()
	if status != nil {
		q = q.Where(videoreport.Status(*status))
	}
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Desc(videoreport.FieldID)).Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

func (r *ReportRepo) Handle(ctx context.Context, id uint32, status uint8, handledBy uint32, note *string) (*ent.VideoReport, error) {
	return r.Client().VideoReport.UpdateOneID(id).
		SetStatus(status).
		SetHandledBy(handledBy).
		SetNillableHandleNote(note).
		SetHandledAt(time.Now()).
		Save(ctx)
}
