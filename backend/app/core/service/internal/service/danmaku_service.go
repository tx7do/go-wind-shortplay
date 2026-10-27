package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	videopkg "go-wind-shortplay/app/core/service/internal/data/ent/video"

	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"

	danmakuV1 "go-wind-shortplay/api/gen/go/danmaku/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
)

// spDanmakuContentMaxRunes 弹幕内容上限（观演短评口径）
const spDanmakuContentMaxRunes = 100

// DanmakuService 弹幕服务（core 真实业务）。
// 发送需登录 + sysconf 开关 + 敏感词过滤；可见性跟随视频（仅已发布视频
// 的 VISIBLE 弹幕对公众可读）；管理端隐藏/删除。
type DanmakuService struct {
	danmakuV1.UnimplementedDanmakuServiceServer

	log         *log.Helper
	danmakuRepo *data.DanmakuRepo
	videoRepo   *data.VideoRepo
	userRepo    data.UserRepo
	sysConfRepo *data.SysConfRepo
}

func NewDanmakuService(
	ctx *bootstrap.Context,
	danmakuRepo *data.DanmakuRepo,
	videoRepo *data.VideoRepo,
	userRepo data.UserRepo,
	sysConfRepo *data.SysConfRepo,
) *DanmakuService {
	return &DanmakuService{
		log:         ctx.NewLoggerHelper("danmaku/service/core-service"),
		danmakuRepo: danmakuRepo,
		videoRepo:   videoRepo,
		userRepo:    userRepo,
		sysConfRepo: sysConfRepo,
	}
}

// videoVisibleTo 视频可见性（弹幕读写同 GetVideoDetail 口径：非已发布仅作者/管理端）
func (s *DanmakuService) videoVisibleTo(ctx context.Context, videoID uint32) (*ent.Video, error) {
	e, err := s.videoRepo.GetEntityRaw(ctx, videoID)
	if err != nil {
		return nil, danmakuV1.ErrorVideoNotFound("video not found")
	}
	if e.Status != videopkg.StatusPublished && !spIsAdminCaller(ctx) {
		return nil, danmakuV1.ErrorVideoNotFound("video not found")
	}
	return e, nil
}

// SendDanmaku 发送弹幕（登录 + 开关 + 敏感词过滤）
func (s *DanmakuService) SendDanmaku(ctx context.Context, req *danmakuV1.SendDanmakuRequest) (*danmakuV1.Danmaku, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, danmakuV1.ErrorUnauthorized("login required")
	}
	if req == nil || req.GetVideoId() == 0 || req.GetContent() == "" {
		return nil, danmakuV1.ErrorBadRequest("invalid parameter")
	}
	content := []rune(req.GetContent())
	if len(content) > spDanmakuContentMaxRunes {
		return nil, danmakuV1.ErrorBadRequest("content too long (max 100)")
	}

	conf, err := s.sysConfRepo.GetEnsure(ctx)
	if err != nil {
		return nil, err
	}
	if !conf.DanmakuEnabled {
		return nil, danmakuV1.ErrorDanmakuDisabled("danmaku disabled")
	}
	if _, err := s.videoVisibleTo(ctx, req.GetVideoId()); err != nil {
		return nil, err
	}
	// 敏感词过滤：命中直接拒绝（同评论口径）
	if spHitSensitiveWords(ctx, s.sysConfRepo, req.GetContent()) {
		return nil, danmakuV1.ErrorDanmakuSensitiveWordHit("danmaku rejected by content filter")
	}

	e, err := s.danmakuRepo.Create(ctx, req.GetVideoId(), uid, string(content), req.GetTimeOffsetMs())
	if err != nil {
		return nil, err
	}
	dto := data.DanmakuEntityToDTO(e, nil)
	// 补发送人（尽力而为）
	if u, uerr := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
		QueryBy: &identityV1.GetUserRequest_Id{Id: e.UserID},
	}); uerr == nil && u != nil {
		dto.User = toUserBriefSP(u)
	}
	return dto, nil
}

// ListVideoDanmaku 视频弹幕列表（游客可读；仅 VISIBLE；补发送人 UserBrief）
func (s *DanmakuService) ListVideoDanmaku(ctx context.Context, req *danmakuV1.ListVideoDanmakuRequest) (*danmakuV1.ListDanmakuResponse, error) {
	if req == nil || req.GetVideoId() == 0 {
		return nil, danmakuV1.ErrorBadRequest("invalid parameter")
	}
	if _, err := s.videoVisibleTo(ctx, req.GetVideoId()); err != nil {
		return nil, err
	}
	items, total, err := s.danmakuRepo.ListByVideo(ctx, req.GetVideoId(), req.GetLimit())
	if err != nil {
		return nil, err
	}
	resp := &danmakuV1.ListDanmakuResponse{Total: trans.Ptr(int64(total))}
	users := s.usersOf(ctx, items)
	for _, e := range items {
		dto := data.DanmakuEntityToDTO(e, nil)
		if dto != nil {
			dto.User = users[e.UserID]
		}
		resp.Items = append(resp.Items, dto)
	}
	return resp, nil
}

// usersOf 批量补全发送人 UserBrief（失败静默留空）
func (s *DanmakuService) usersOf(ctx context.Context, items []*ent.Danmaku) map[uint32]*identityV1.UserBrief {
	users := make(map[uint32]*identityV1.UserBrief, len(items))
	for _, uid := range s.danmakuRepo.UserIDsOf(items) {
		if u, err := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
			QueryBy: &identityV1.GetUserRequest_Id{Id: uid},
		}); err == nil && u != nil {
			users[uid] = toUserBriefSP(u)
		}
	}
	return users
}

// AdminList 管理端全量弹幕列表
func (s *DanmakuService) AdminList(ctx context.Context, req *paginationV1.PagingRequest) (*danmakuV1.ListDanmakuResponse, error) {
	return s.danmakuRepo.ListAdmin(ctx, req)
}

// DeleteDanmaku 管理端删除弹幕
func (s *DanmakuService) DeleteDanmaku(ctx context.Context, req *danmakuV1.DeleteDanmakuRequest) (*emptypb.Empty, error) {
	if req == nil || req.GetId() == 0 {
		return nil, danmakuV1.ErrorBadRequest("invalid parameter")
	}
	if err := s.danmakuRepo.Delete(ctx, req.GetId()); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// SetDanmakuStatus 管理端隐藏/恢复弹幕
func (s *DanmakuService) SetDanmakuStatus(ctx context.Context, req *danmakuV1.SetDanmakuStatusRequest) (*danmakuV1.Danmaku, error) {
	if req == nil || req.GetId() == 0 || req.GetStatus() == danmakuV1.DanmakuStatus_DANMAKU_STATUS_UNSPECIFIED {
		return nil, danmakuV1.ErrorBadRequest("invalid parameter")
	}
	e, err := s.danmakuRepo.SetStatus(ctx, req.GetId(), req.GetStatus())
	if err != nil {
		return nil, err
	}
	return data.DanmakuEntityToDTO(e, nil), nil
}
