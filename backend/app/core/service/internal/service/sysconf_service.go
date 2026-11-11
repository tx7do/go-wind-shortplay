package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/go-utils/timeutil"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"

	sysconfV1 "go-wind-shortplay/api/gen/go/sysconf/service/v1"
)

type SysConfService struct {
	sysconfV1.UnimplementedSysConfServiceServer

	log *log.Helper

	sysConfRepo *data.SysConfRepo
}

func NewSysConfService(ctx *bootstrap.Context, sysConfRepo *data.SysConfRepo) *SysConfService {
	return &SysConfService{
		log:         ctx.NewLoggerHelper("sysconf/service/core-service"),
		sysConfRepo: sysConfRepo,
	}
}

func sysconfEntityToDTO(e *ent.SysConfig) *sysconfV1.SysConf {
	if e == nil {
		return nil
	}
	if e.AllowedVideoTypes == nil {
		e.AllowedVideoTypes = []string{}
	}
	if e.SensitiveWords == nil {
		e.SensitiveWords = []string{}
	}
	return &sysconfV1.SysConf{
		MaxUploadSizeMb:        trans.Ptr(e.MaxUploadSizeMB),
		MaxDurationSeconds:     trans.Ptr(e.MaxDurationSeconds),
		ManualReviewEnabled:    trans.Ptr(e.ManualReviewEnabled),
		RegisterEnabled:        trans.Ptr(e.RegisterEnabled),
		AllowedVideoTypes:      e.AllowedVideoTypes,
		SensitiveFilterEnabled: trans.Ptr(e.SensitiveFilterEnabled),
		SensitiveWords:         e.SensitiveWords,
		AnnouncementEnabled:    trans.Ptr(e.AnnouncementEnabled),
		AnnouncementText:       e.AnnouncementText,
		AnnouncementLink:       trans.Ptr(e.AnnouncementLink),
		DanmakuEnabled:         trans.Ptr(e.DanmakuEnabled),
		ImEnabled:              trans.Ptr(e.ImEnabled),
		UpdatedAt:              timeutil.TimeToTimestamppb(e.UpdatedAt),
	}
}

// GetSysConf 获取系统配置（App 启动拉取；游客可读；首访懒播种默认行）。
func (s *SysConfService) GetSysConf(ctx context.Context, _ *emptypb.Empty) (*sysconfV1.SysConf, error) {
	e, err := s.sysConfRepo.GetEnsure(ctx)
	if err != nil {
		return nil, err
	}
	return sysconfEntityToDTO(e), nil
}

// UpdateSysConf 更新系统配置（管理端；部分字段语义，nil 不更新）。
func (s *SysConfService) UpdateSysConf(ctx context.Context, req *sysconfV1.UpdateSysConfRequest) (*sysconfV1.SysConf, error) {
	if req == nil {
		return nil, sysconfV1.ErrorBadRequest("invalid parameter")
	}
	e, err := s.sysConfRepo.Update(ctx, &data.SysConfUpdate{
		MaxUploadMB:         i64pFromU32(req.MaxUploadSizeMb),
		MaxDuration:         i64pFromU32(req.MaxDurationSeconds),
		ManualReview:        req.ManualReviewEnabled,
		Register:            req.RegisterEnabled,
		AllowedTypes:        req.AllowedVideoTypes,
		SensitiveEnabled:    req.SensitiveFilterEnabled,
		SensitiveWords:      req.SensitiveWords,
		AnnouncementEnabled: req.AnnouncementEnabled,
		AnnouncementText:    req.AnnouncementText,
		AnnouncementLink:    req.AnnouncementLink,
		DanmakuEnabled:      req.DanmakuEnabled,
		ImEnabled:           req.ImEnabled,
	})
	if err != nil {
		return nil, err
	}
	return sysconfEntityToDTO(e), nil
}

func i64pFromU32(v *uint32) *int64 {
	if v == nil {
		return nil
	}
	x := int64(*v)
	return &x
}
