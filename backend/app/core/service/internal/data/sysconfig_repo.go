package data

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/sysconfig"
)

// SysConfigRepo 系统配置仓储（单行，id=1，缺省自动初始化）
type SysConfigRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewSysConfigRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *SysConfigRepo {
	return &SysConfigRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("sysconfig/repo/core-service"),
	}
}

func (r *SysConfigRepo) Client() *ent.Client {
	return r.entClient.Client()
}

// Get 读取配置；首次访问自动落一行默认配置
func (r *SysConfigRepo) Get(ctx context.Context) (*ent.SysConfig, error) {
	cfg, err := r.Client().SysConfig.Query().Where(sysconfig.ID(1)).Only(ctx)
	if err == nil {
		return cfg, nil
	}
	if !ent.IsNotFound(err) {
		return nil, err
	}
	created, cErr := r.Client().SysConfig.Create().
		SetID(1).
		SetMaxUploadSizeMB(500).
		SetMaxDurationSeconds(600).
		SetManualReviewEnabled(false).
		SetRegisterEnabled(true).
		SetAllowedVideoTypes([]string{".mp4", ".mov", ".m4v", ".webm"}).
		Save(ctx)
	if cErr != nil {
		// 并发初始化撞主键：再读一次
		if again, aErr := r.Client().SysConfig.Query().Where(sysconfig.ID(1)).Only(ctx); aErr == nil {
			return again, nil
		}
		return nil, cErr
	}
	return created, nil
}

func (r *SysConfigRepo) Update(ctx context.Context, maxUploadMB, maxDuration *uint32, manualReview, register *bool, allowedTypes []string) (*ent.SysConfig, error) {
	if _, err := r.Get(ctx); err != nil {
		return nil, err
	}
	u := r.Client().SysConfig.UpdateOneID(1).
		SetNillableMaxUploadSizeMB(maxUploadMB).
		SetNillableMaxDurationSeconds(maxDuration).
		SetNillableManualReviewEnabled(manualReview).
		SetNillableRegisterEnabled(register)
	if allowedTypes != nil {
		u.SetAllowedVideoTypes(allowedTypes)
	}
	return u.Save(ctx)
}
