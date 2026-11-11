package service

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/google/uuid"
	"github.com/hibiken/asynq"
	minio "github.com/minio/minio-go/v7"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/go-utils/timeutil"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	crudViewer "github.com/tx7do/go-crud/viewer"
	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/uploadtask"
	videopkg "go-wind-shortplay/app/core/service/internal/data/ent/video"
	appViewer "go-wind-shortplay/pkg/entgo/viewer"
	"go-wind-shortplay/pkg/oss"
	"go-wind-shortplay/pkg/task"

	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
)

// nowTimestamppbSP 当前时间戳
func nowTimestamppbSP() *timestamppb.Timestamp {
	now := time.Now()
	return timestamppb.New(now)
}

// newShortplayTaskID 上传任务号
func newShortplayTaskID() string {
	return uuid.NewString()
}

// spSystemContext 异步 worker 的系统上下文
func spSystemContext() context.Context {
	return appViewer.NewSystemViewerContext(context.Background())
}

const (
	// 上传分片暂存根目录（可经环境变量覆盖）
	spUploadTempRootEnv = "SP_UPLOAD_TEMP_DIR"

	// 缺省分片 4MB
	defaultChunkSize int64 = 4 * 1024 * 1024
	// 单个上传任务的并发分片写入不做限制（顺序上传）
)

// spUploadTempRootDef 分片暂存缺省根目录
var spUploadTempRootDef = os.TempDir()

type VideoService struct {
	videoV1.UnimplementedVideoServiceServer

	log *log.Helper

	videoRepo      *data.VideoRepo
	draftRepo      *data.VideoDraftRepo
	uploadTaskRepo *data.UploadTaskRepo
	sysConfRepo    *data.SysConfRepo

	seriesSvc *SeriesService

	internalMessage InternalMessageNotifier

	minio *oss.MinIOClient

	taskEnqueuer TaskEnqueuer
}

func NewVideoService(
	ctx *bootstrap.Context,
	videoRepo *data.VideoRepo,
	seriesSvc *SeriesService,
	draftRepo *data.VideoDraftRepo,
	uploadTaskRepo *data.UploadTaskRepo,
	sysConfRepo *data.SysConfRepo,
	minio *oss.MinIOClient,
) *VideoService {
	return &VideoService{
		log:            ctx.NewLoggerHelper("video/service/core-service"),
		videoRepo:      videoRepo,
		seriesSvc:      seriesSvc,
		draftRepo:      draftRepo,
		uploadTaskRepo: uploadTaskRepo,
		sysConfRepo:    sysConfRepo,
		minio:          minio,
	}
}

// RegisterTaskEnqueuer 注入 asynq 入队能力（封面抽帧任务）。
func (s *VideoService) RegisterTaskEnqueuer(enqueuer TaskEnqueuer) {
	s.taskEnqueuer = enqueuer
}

// uploadTaskEntityToDTO ent.UploadTask → proto UploadTask（服务内映射）
func uploadTaskEntityToDTO(e *ent.UploadTask) *videoV1.UploadTask {
	if e == nil {
		return nil
	}
	var status videoV1.UploadTaskStatus
	switch e.Status {
	case uploadtask.StatusMerging:
		status = videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_MERGING
	case uploadtask.StatusCompleted:
		status = videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_COMPLETED
	case uploadtask.StatusFailed:
		status = videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_FAILED
	default:
		status = videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_UPLOADING
	}
	return &videoV1.UploadTask{
		TaskId:         trans.Ptr(e.TaskID),
		FileName:       trans.Ptr(e.FileName),
		FileSize:       trans.Ptr(e.FileSize),
		ChunkSize:      trans.Ptr(e.ChunkSize),
		TotalChunks:    trans.Ptr(uint32(e.TotalChunks)),
		UploadedChunks: u32sFromI64s(e.UploadedChunks),
		Status:         status.Enum(),
		FileKey:        e.FileKey,
		VideoId:        trans.Ptr(e.VideoID),
		CreatedAt:      timeutil.TimeToTimestamppb(e.CreatedAt),
	}
}

// draftEntityToDTO ent.VideoDraft → proto VideoDraft（服务内映射）
func draftEntityToDTO(e *ent.VideoDraft) *videoV1.VideoDraft {
	if e == nil {
		return nil
	}
	dto := &videoV1.VideoDraft{
		Id:           trans.Ptr(e.ID),
		Title:        trans.Ptr(e.Title),
		Description:  e.Description,
		Tags:         e.Tags,
		CoverUrl:     e.CoverURL,
		VideoUrl:     e.VideoURL,
		Duration:     trans.Ptr(e.Duration),
		Width:        trans.Ptr(e.Width),
		Height:       trans.Ptr(e.Height),
		UploadTaskId: e.UploadTaskID,
		AuthorId:     trans.Ptr(e.AuthorID),
		CreatedAt:    timeutil.TimeToTimestamppb(e.CreatedAt),
		UpdatedAt:    timeutil.TimeToTimestamppb(e.UpdatedAt),
	}
	if e.SeriesID > 0 {
		dto.SeriesId = trans.Ptr(e.SeriesID)
		dto.EpisodeNumber = trans.Ptr(uint32(e.EpisodeNumber))
	}
	return dto
}

// ── viewer 助手 ──

// spViewerUserID 取当前登录用户 ID（未登录返回 0）
func spViewerUserID(ctx context.Context) int64 {
	uid, _ := viewerUserIDFromContext(ctx)
	return uid
}

// spIsAdminCaller 是否管理端调用（平台 viewer/系统上下文）
func spIsAdminCaller(ctx context.Context) bool {
	vc, exist := crudViewer.FromContext(ctx)
	if !exist || vc == nil {
		return false
	}
	return vc.IsPlatformContext() || vc.IsSystemContext()
}

// ── 视频元数据 ──

func (s *VideoService) GetVideo(ctx context.Context, req *videoV1.GetVideoRequest) (*videoV1.Video, error) {
	return s.videoRepo.Get(ctx, req.GetId())
}

func (s *VideoService) ListVideo(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListVideoResponse, error) {
	return s.videoRepo.List(ctx, req)
}

func (s *VideoService) ListUserVideo(ctx context.Context, req *videoV1.ListUserVideoRequest) (*videoV1.ListVideoResponse, error) {
	uid := spViewerUserID(ctx)
	isSelf := uid > 0 && uid == req.GetUserId()
	return s.videoRepo.ListByAuthor(ctx, req.GetUserId(), isSelf, int64(req.GetPageNum()), int64(req.GetPageSize()))
}

func (s *VideoService) UpdateVideo(ctx context.Context, req *videoV1.UpdateVideoRequest) (*videoV1.Video, error) {
	if req == nil || req.GetId() == 0 {
		return nil, videoV1.ErrorBadRequest("invalid parameter")
	}
	// 非管理端只能编辑自己的视频
	if !spIsAdminCaller(ctx) {
		v, err := s.videoRepo.Get(ctx, req.GetId())
		if err != nil {
			return nil, err
		}
		if v.GetAuthorId() != spViewerUserID(ctx) {
			return nil, videoV1.ErrorNotVideoOwner("not video owner")
		}
	}
	dto := &videoV1.Video{
		Title:       req.Title,
		Description: req.Description,
		CoverUrl:    req.CoverUrl,
	}
	// 挂靠剧集：>0 挂靠（校验剧归属）、=0 解挂、缺省不变
	if req.SeriesId != nil {
		if req.GetSeriesId() > 0 {
			seriesID, episodeNo, err := s.seriesSvc.ResolveSeriesAttach(ctx, spViewerUserID(ctx), req.GetSeriesId(), int64(req.GetEpisodeNumber()))
			if err != nil {
				return nil, err
			}
			dto.SeriesId = trans.Ptr(seriesID)
			dto.EpisodeNumber = trans.Ptr(uint32(episodeNo))
		} else {
			dto.SeriesId = trans.Ptr(int64(0))
		}
	}
	return s.videoRepo.Update(ctx, req.GetId(), dto, req.GetTags())
}

func (s *VideoService) DeleteVideo(ctx context.Context, req *videoV1.DeleteVideoRequest) (*emptypb.Empty, error) {
	if !spIsAdminCaller(ctx) {
		v, err := s.videoRepo.Get(ctx, req.GetId())
		if err != nil {
			return nil, err
		}
		if v.GetAuthorId() != spViewerUserID(ctx) {
			return nil, videoV1.ErrorNotVideoOwner("not video owner")
		}
	}
	if err := s.videoRepo.Delete(ctx, req.GetId()); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// validateVideoStatusTransition 发布状态机白名单（全仓铁律 5）
func validateVideoStatusTransition(from, to videoV1.VideoStatus) bool {
	switch to {
	case videoV1.VideoStatus_VIDEO_STATUS_REVIEWING:
		// 重新送审：草稿 / 驳回 / 已下架均可回到审核队列（管理端重审口径）
		return from == videoV1.VideoStatus_VIDEO_STATUS_DRAFT ||
			from == videoV1.VideoStatus_VIDEO_STATUS_REJECTED ||
			from == videoV1.VideoStatus_VIDEO_STATUS_OFFLINE
	case videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED:
		return from == videoV1.VideoStatus_VIDEO_STATUS_REVIEWING ||
			from == videoV1.VideoStatus_VIDEO_STATUS_DRAFT // 审核关闭直发
	case videoV1.VideoStatus_VIDEO_STATUS_REJECTED:
		return from == videoV1.VideoStatus_VIDEO_STATUS_REVIEWING
	case videoV1.VideoStatus_VIDEO_STATUS_OFFLINE:
		return from == videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED
	}
	return false
}

func (s *VideoService) ChangeVideoStatus(ctx context.Context, req *videoV1.ChangeVideoStatusRequest) (*videoV1.Video, error) {
	cur, err := s.videoRepo.Get(ctx, req.GetId())
	if err != nil {
		return nil, err
	}
	from := cur.GetStatus()
	to := req.GetStatus()
	if !validateVideoStatusTransition(from, to) {
		return nil, videoV1.ErrorInvalidStatusTransition("invalid status transition %s -> %s", from, to)
	}

	dto := &videoV1.Video{Status: to.Enum()}
	if to == videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED {
		dto.PublishedAt = nowTimestamppbSP()
		// 定时视频经审核/管理员直发时清空计划时间，避免遗留过期排程
		if cur.GetScheduledAt() != nil {
			if _, serr := s.videoRepo.SetScheduledAt(ctx, req.GetId(), nil); serr != nil {
				s.log.Errorf("clear scheduled_at on publish failed: %s", serr.Error())
			}
		}
	}
	if to == videoV1.VideoStatus_VIDEO_STATUS_OFFLINE && cur.GetScheduledOffAt() != nil {
		// 已手工下架：清空定时下架排程
		if _, serr := s.videoRepo.SetScheduledOffAt(ctx, req.GetId(), nil); serr != nil {
			s.log.Errorf("clear scheduled_off_at on offline failed: %s", serr.Error())
		}
	}
	if to == videoV1.VideoStatus_VIDEO_STATUS_REJECTED || to == videoV1.VideoStatus_VIDEO_STATUS_OFFLINE {
		reason := req.GetReason()
		if strings.TrimSpace(reason) == "" {
			return nil, videoV1.ErrorBadRequest("reason is required")
		}
		dto.RejectReason = &reason
	}

	updated, uerr := s.videoRepo.Update(ctx, req.GetId(), dto, nil)
	if uerr != nil {
		return nil, uerr
	}

	// 审核结果通知作者（系统口径；作者名以 updated 回带，避免二次查询）
	outcome := reviewNone
	reason := req.GetReason()
	switch to {
	case videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED:
		outcome = reviewPassed
	case videoV1.VideoStatus_VIDEO_STATUS_REJECTED:
		outcome = reviewRejected
	case videoV1.VideoStatus_VIDEO_STATUS_OFFLINE:
		outcome = reviewOffline
	}
	if outcome != reviewNone {
		s.notifyVideoReviewed(ctx, updated.GetAuthorId(), updated.GetId(), updated.GetTitle(), reason, outcome)
	}

	// 剧集更新通知：挂靠剧集的视频新发布，fan-out 给追剧者（尽力而为）
	if to == videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED && updated.GetSeriesId() > 0 && s.seriesSvc != nil {
		s.seriesSvc.NotifyFollowersNewEpisode(ctx, updated.GetSeriesId(), updated.GetId(), int64(updated.GetEpisodeNumber()), updated.GetTitle(), updated.GetAuthorId())
	}
	return updated, nil
}

// ScheduleVideo 设置/取消定时发布与定时下架（作者本人或管理端）。
// scheduledAt 仅 DRAFT（到期转 PUBLISHED）；scheduledOffAt 仅 PUBLISHED
// （到期转 OFFLINE）；各自缺省=取消对应排程。
func (s *VideoService) ScheduleVideo(ctx context.Context, req *videoV1.ScheduleVideoRequest) (*videoV1.Video, error) {
	if req == nil || req.GetId() == 0 {
		return nil, videoV1.ErrorBadRequest("invalid parameter")
	}
	cur, err := s.videoRepo.Get(ctx, req.GetId())
	if err != nil {
		return nil, err
	}
	uid := spViewerUserID(ctx)
	if !spIsAdminCaller(ctx) && cur.GetAuthorId() != uid {
		return nil, videoV1.ErrorForbidden("not video owner")
	}

	// 定时发布（仅 DRAFT）
	if req.ScheduledAt != nil {
		if cur.GetStatus() != videoV1.VideoStatus_VIDEO_STATUS_DRAFT {
			return nil, videoV1.ErrorInvalidStatusTransition("only draft videos can be scheduled to publish, current: %s", cur.GetStatus())
		}
		t := req.GetScheduledAt().AsTime()
		if !t.After(time.Now()) {
			return nil, videoV1.ErrorBadRequest("scheduled time must be in the future")
		}
		if _, err := s.videoRepo.SetScheduledAt(ctx, req.GetId(), &t); err != nil {
			return nil, err
		}
		s.schedulePublishTask(ctx, req.GetId(), &t)
	}

	// 定时下架（仅 PUBLISHED）
	if req.ScheduledOffAt != nil {
		if cur.GetStatus() != videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED {
			return nil, videoV1.ErrorInvalidStatusTransition("only published videos can be scheduled to offline, current: %s", cur.GetStatus())
		}
		off := req.GetScheduledOffAt().AsTime()
		if !off.After(time.Now()) {
			return nil, videoV1.ErrorBadRequest("scheduled off time must be in the future")
		}
		if _, err := s.videoRepo.SetScheduledOffAt(ctx, req.GetId(), &off); err != nil {
			return nil, err
		}
		s.scheduleUnpublishTask(ctx, req.GetId(), &off)
	}

	return s.videoRepo.Get(ctx, req.GetId())
}

// spScheduledFuture 请求里的计划时间是否有效（非空且在未来）
func spScheduledFuture(ts *timestamppb.Timestamp) bool {
	return ts != nil && ts.AsTime().After(time.Now())
}

// schedulePublishTask 定时发布入队（asynq ProcessAt；取消定时则尽力撤销任务）。
// 入队失败仅记日志：到期任务属尽力而为，另有补偿扫描兜底（spScheduledSweep）。
func (s *VideoService) schedulePublishTask(ctx context.Context, videoID int64, at *time.Time) {
	if s.taskEnqueuer == nil {
		return
	}
	if at == nil {
		// 取消定时：asynq 无按载荷撤销，任务到期后自校验状态（非 DRAFT 直接跳过）
		return
	}
	if err := s.taskEnqueuer.NewTask(
		task.VideoScheduledPublishTaskType,
		&task.VideoScheduledPublishData{VideoID: videoID},
		asynq.ProcessAt(*at),
	); err != nil {
		s.log.Errorf("enqueue scheduled publish failed: %v", err)
	}
}

// afterVideoCreated 视频创建后的发布副作用统一入口：
// 已发布 → 追更 fan-out；DRAFT+定时 → 排程入队。
func (s *VideoService) afterVideoCreated(ctx context.Context, video *videoV1.Video) {
	if video == nil {
		return
	}
	if video.GetStatus() == videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED {
		if video.GetSeriesId() > 0 && s.seriesSvc != nil {
			s.seriesSvc.NotifyFollowersNewEpisode(ctx, video.GetSeriesId(), video.GetId(), int64(video.GetEpisodeNumber()), video.GetTitle(), video.GetAuthorId())
		}
		return
	}
	if video.GetStatus() == videoV1.VideoStatus_VIDEO_STATUS_DRAFT && video.GetScheduledAt() != nil {
		at := video.GetScheduledAt().AsTime()
		s.schedulePublishTask(ctx, video.GetId(), &at)
	}
}

// scheduleUnpublishTask 定时下架入队（取消定时无需撤销：到期回调自校验状态）
func (s *VideoService) scheduleUnpublishTask(ctx context.Context, videoID int64, at *time.Time) {
	if s.taskEnqueuer == nil {
		return
	}
	if err := s.taskEnqueuer.NewTask(
		task.VideoScheduledUnpublishTaskType,
		&task.VideoScheduledUnpublishData{VideoID: videoID},
		asynq.ProcessAt(*at),
	); err != nil {
		s.log.Errorf("enqueue scheduled unpublish failed: %v", err)
	}
}

// AsyncScheduledUnpublish asynq 订阅者：到期把 PUBLISHED+定时下架视频转 OFFLINE。
func (s *VideoService) AsyncScheduledUnpublish(_ string, payload *task.VideoScheduledUnpublishData) error {
	if payload == nil || payload.VideoID == 0 {
		return nil
	}
	ctx := spSystemContext()
	e, err := s.videoRepo.GetEntityRaw(ctx, payload.VideoID)
	if err != nil {
		return nil // 已删除：不重试
	}
	if e.Status != videopkg.StatusPublished || e.ScheduledOffAt == nil {
		return nil // 状态已变（提前下架/取消排程）：跳过
	}
	// 先清排程再下架，保证两步任一失败可见
	if _, err := s.videoRepo.SetScheduledOffAt(ctx, payload.VideoID, nil); err != nil {
		s.log.Errorf("clear scheduled_off_at before offline failed: %s", err.Error())
		return nil
	}
	updated, err := s.videoRepo.Update(ctx, payload.VideoID, &videoV1.Video{
		Status:       videoV1.VideoStatus_VIDEO_STATUS_OFFLINE.Enum(),
		RejectReason: trans.Ptr("定时下架"),
	}, nil)
	if err != nil {
		s.log.Errorf("scheduled unpublish failed: %s", err.Error())
		return nil
	}
	// 作者通知（系统口径）
	s.notifyVideoReviewed(ctx, updated.GetAuthorId(), updated.GetId(), updated.GetTitle(), "定时下架", reviewOffline)
	s.log.Infof("scheduled video %d offline (planned at %s)", payload.VideoID, e.ScheduledOffAt.Format(time.RFC3339))
	return nil
}

// AsyncScheduledPublish asynq 订阅者：到期把 DRAFT+定时视频转 PUBLISHED。
// 系统上下文执行；状态自校验（已发布/已删除/已改期则跳过）。
func (s *VideoService) AsyncScheduledPublish(_ string, payload *task.VideoScheduledPublishData) error {
	if payload == nil || payload.VideoID == 0 {
		return nil
	}
	ctx := spSystemContext()
	e, err := s.videoRepo.GetEntityRaw(ctx, payload.VideoID)
	if err != nil {
		return nil // 已删除：不重试
	}
	if e.Status != videopkg.StatusDraft || e.ScheduledAt == nil {
		return nil // 状态已变（取消定时/管理员提前发布）：跳过
	}
	s.publishScheduledNow(ctx, e.ID, e.ScheduledAt)
	return nil
}

// publishScheduledNow 执行定时转发布（清计划时间 → 状态机内流转 → 追更 fan-out）
func (s *VideoService) publishScheduledNow(ctx context.Context, videoID int64, scheduledAt *time.Time) {
	// 先清计划时间再走 Update 状态流转，保证两步任一失败可见
	if _, err := s.videoRepo.SetScheduledAt(ctx, videoID, nil); err != nil {
		s.log.Errorf("clear scheduled_at before publish failed: %s", err.Error())
		return
	}
	dto := &videoV1.Video{
		Status:      videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED.Enum(),
		PublishedAt: nowTimestamppbSP(),
	}
	updated, err := s.videoRepo.Update(ctx, videoID, dto, nil)
	if err != nil {
		s.log.Errorf("scheduled publish failed: %s", err.Error())
		return
	}
	// 敏感词兜底复检：定时内容若命中词表转审核而非直接可见
	if spHitSensitiveWords(ctx, s.sysConfRepo, updated.GetTitle(), updated.GetDescription()) {
		if _, err := s.videoRepo.Update(ctx, videoID, &videoV1.Video{
			Status: videoV1.VideoStatus_VIDEO_STATUS_REVIEWING.Enum(),
		}, nil); err != nil {
			s.log.Errorf("scheduled publish sensitive fallback failed: %s", err.Error())
		}
		return
	}
	if updated.GetSeriesId() > 0 && s.seriesSvc != nil {
		s.seriesSvc.NotifyFollowersNewEpisode(ctx, updated.GetSeriesId(), updated.GetId(), int64(updated.GetEpisodeNumber()), updated.GetTitle(), updated.GetAuthorId())
	}
	s.log.Infof("scheduled video %d published (planned at %s)", videoID, scheduledAt.Format(time.RFC3339))
}

// ── 分片上传 ──

func spUploadTempRoot() string {
	if v := os.Getenv(spUploadTempRootEnv); v != "" {
		return v
	}
	return spUploadTempRootDef
}

func spChunkTempDir(root, taskID string) string {
	return filepath.Join(root, taskID)
}

func spChunkFilePath(root, taskID string, chunkIndex int64) string {
	return filepath.Join(spChunkTempDir(root, taskID), fmt.Sprintf("%06d.part", chunkIndex))
}

func spVideoExtOf(fileName string) string {
	idx := strings.LastIndex(fileName, ".")
	if idx < 0 {
		return ""
	}
	return strings.ToLower(fileName[idx:])
}

// CreateUploadTask 创建上传任务：校验类型/大小上限，返回分片参数。
func (s *VideoService) CreateUploadTask(ctx context.Context, req *videoV1.CreateUploadTaskRequest) (*videoV1.UploadTask, error) {
	if req == nil || req.GetFileName() == "" || req.GetFileSize() <= 0 {
		return nil, videoV1.ErrorBadRequest("invalid parameter")
	}

	conf, err := s.sysConfRepo.GetEnsure(ctx)
	if err != nil {
		return nil, err
	}

	ext := spVideoExtOf(req.GetFileName())
	allowed := false
	for _, t := range conf.AllowedVideoTypes {
		if t == ext {
			allowed = true
			break
		}
	}
	if !allowed {
		return nil, videoV1.ErrorFileTypeNotAllowed("file type not allowed: %s", ext)
	}

	maxBytes := int64(conf.MaxUploadSizeMB) * 1024 * 1024
	if maxBytes > 0 && int64(req.GetFileSize()) > maxBytes {
		return nil, videoV1.ErrorFileTooLarge("file exceeds max size %dMB", conf.MaxUploadSizeMB)
	}

	chunkSize := req.GetChunkSize()
	if chunkSize <= 0 {
		chunkSize = uint32(defaultChunkSize)
	}
	totalChunks := int64((int64(req.GetFileSize()) + int64(chunkSize) - 1) / int64(chunkSize))
	if totalChunks == 0 {
		totalChunks = 1
	}

	taskID := newShortplayTaskID()
	e, err := s.uploadTaskRepo.Create(ctx, taskID, req.GetFileName(), int64(req.GetFileSize()), int64(chunkSize), int64(totalChunks))
	if err != nil {
		return nil, err
	}
	return uploadTaskEntityToDTO(e), nil
}

// UploadChunk 上传单个分片（顺序落本地暂存）。
func (s *VideoService) UploadChunk(ctx context.Context, req *videoV1.UploadChunkRequest) (*videoV1.UploadChunkResponse, error) {
	if req == nil || req.GetTaskId() == "" {
		return nil, videoV1.ErrorBadRequest("invalid parameter")
	}
	e, err := s.uploadTaskRepo.GetByTaskID(ctx, req.GetTaskId())
	if err != nil {
		return nil, err
	}
	if e.Status != uploadtask.StatusUploading {
		return nil, videoV1.ErrorConflict("task not uploading")
	}
	if req.GetChunkIndex() >= e.TotalChunks {
		return nil, videoV1.ErrorBadRequest("chunk index out of range")
	}
	if len(req.GetData()) == 0 {
		return nil, videoV1.ErrorBadRequest("empty chunk data")
	}

	path := spChunkFilePath(spUploadTempRoot(), e.TaskID, int64(req.GetChunkIndex()))
	if err = os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		s.log.Errorf("mkdir chunk dir failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("write chunk failed")
	}
	if err = os.WriteFile(path, req.GetData(), 0o644); err != nil {
		s.log.Errorf("write chunk failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("write chunk failed")
	}

	chunks, err := s.uploadTaskRepo.AppendUploadedChunk(ctx, e.TaskID, int64(req.GetChunkIndex()))
	if err != nil {
		return nil, err
	}
	return &videoV1.UploadChunkResponse{UploadedChunks: u32sFromI64s(chunks)}, nil
}

// CompleteUpload 完成上传：校验分片完整性 → 合并 → MinIO → 建视频/草稿 → 异步抽帧封面。
func (s *VideoService) CompleteUpload(ctx context.Context, req *videoV1.CompleteUploadRequest) (*videoV1.UploadTask, error) {
	if req == nil || req.GetTaskId() == "" {
		return nil, videoV1.ErrorBadRequest("invalid parameter")
	}
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, videoV1.ErrorUnauthorized("login required")
	}

	e, err := s.uploadTaskRepo.GetByTaskID(ctx, req.GetTaskId())
	if err != nil {
		return nil, err
	}
	if e.Status == uploadtask.StatusCompleted {
		return uploadTaskEntityToDTO(e), nil
	}
	if e.Status != uploadtask.StatusUploading {
		return nil, videoV1.ErrorConflict("task not uploading")
	}

	// 分片完整性
	if int64(len(e.UploadedChunks)) < int64(e.TotalChunks) {
		return nil, videoV1.ErrorChunkMissing("chunks missing: %d/%d", len(e.UploadedChunks), int64(e.TotalChunks))
	}

	// 转合并中
	if err = s.uploadTaskRepo.UpdateStatus(ctx, e.ID, videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_MERGING, nil); err != nil {
		return nil, err
	}

	// 合并 → 上传 MinIO → 清理暂存
	root := spUploadTempRoot()
	objectKey, mergedPath, err := s.mergeAndUpload(ctx, e, root)
	if err != nil {
		_ = s.uploadTaskRepo.UpdateStatus(ctx, e.ID, videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_FAILED, nil)
		return nil, err
	}
	_ = os.RemoveAll(spChunkTempDir(root, e.TaskID))
	_ = os.Remove(mergedPath)

	// 建视频 / 草稿
	videoStatus := videoV1.VideoStatus_VIDEO_STATUS_DRAFT
	conf, _ := s.sysConfRepo.GetEnsure(ctx)
	if !req.GetAsDraft() {
		if conf.ManualReviewEnabled {
			videoStatus = videoV1.VideoStatus_VIDEO_STATUS_REVIEWING
		} else if spScheduledFuture(req.ScheduledAt) {
			// 定时发布：直发路径先存 DRAFT，到期任务自动转 PUBLISHED
			videoStatus = videoV1.VideoStatus_VIDEO_STATUS_DRAFT
		} else {
			videoStatus = videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED
		}
	}

	dto := &videoV1.Video{
		Title:       req.Title,
		Description: req.Description,
		VideoUrl:    trans.Ptr(objectKey),
		Duration:    req.Duration,
		Width:       req.Width,
		Height:      req.Height,
		Status:      videoStatus.Enum(),
		AuthorId:    trans.Ptr(uid),
	}
	if !req.GetAsDraft() && videoStatus == videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED {
		dto.PublishedAt = nowTimestamppbSP()
	}
	if strings.TrimSpace(req.GetTitle()) == "" {
		dto.Title = trans.Ptr(strings.TrimSuffix(e.FileName, filepath.Ext(e.FileName)))
	}
	// 直发+定时：计划时间随行落库（状态已在上文决策为 DRAFT，见排程入队）
	if !req.GetAsDraft() && spScheduledFuture(req.ScheduledAt) {
		dto.ScheduledAt = req.ScheduledAt
	}

	// 挂靠剧集：剧须为本人所有；集号缺省自动排到当前最大 +1
	if req.GetSeriesId() > 0 {
		seriesID, episodeNo, aerr := s.seriesSvc.ResolveSeriesAttach(ctx, uid, req.GetSeriesId(), int64(req.GetEpisodeNumber()))
		if aerr != nil {
			_ = s.uploadTaskRepo.UpdateStatus(ctx, e.ID, videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_FAILED, nil)
			return nil, aerr
		}
		dto.SeriesId = trans.Ptr(seriesID)
		dto.EpisodeNumber = trans.Ptr(uint32(episodeNo))
	}

	// 敏感词过滤：非草稿命中（标题/简介）强制转审核中，即使人工审核关
	if videoStatus == videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED &&
		spHitSensitiveWords(ctx, s.sysConfRepo, dto.GetTitle(), dto.GetDescription()) {
		videoStatus = videoV1.VideoStatus_VIDEO_STATUS_REVIEWING
		dto.Status = videoStatus.Enum()
		dto.PublishedAt = nil
	}

	video, err := s.videoRepo.Create(ctx, dto, req.GetTags())
	if err != nil {
		_ = s.uploadTaskRepo.UpdateStatus(ctx, e.ID, videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_FAILED, nil)
		return nil, err
	}

	// 发布副作用（追更 fan-out）与定时排程
	s.afterVideoCreated(ctx, video)
	_ = s.uploadTaskRepo.UpdateStatus(ctx, e.ID, videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_COMPLETED, func(b *ent.UploadTaskUpdateOne) {
		b.SetFileKey(objectKey)
		b.SetVideoID(video.GetId())
	})

	// 封面：自定义封面直接回填；否则 asynq 异步抽帧（尽力而为）
	if strings.TrimSpace(req.GetCoverUrl()) != "" {
		_, _ = s.videoRepo.Update(ctx, video.GetId(), &videoV1.Video{CoverUrl: req.CoverUrl}, nil)
	} else if s.taskEnqueuer != nil {
		if err = s.taskEnqueuer.NewTask(task.VideoCoverExtractTaskType, &task.VideoCoverExtractTaskData{
			TaskID:  e.TaskID,
			Bucket:  oss.DefaultBucketName(),
			Object:  objectKey,
			VideoID: video.GetId(),
		}); err != nil {
			s.log.Errorf("enqueue cover extract failed: %v", err)
		}
	}

	if req.GetAsDraft() {
		// 存草稿：建草稿行并回填任务（挂靠信息随行，提交发布时生效）
		_, _ = s.draftRepo.Create(ctx, &videoV1.VideoDraft{
			Title:         dto.Title,
			Description:   dto.Description,
			Tags:          req.GetTags(),
			CoverUrl:      req.CoverUrl,
			VideoUrl:      trans.Ptr(objectKey),
			Duration:      req.Duration,
			Width:         req.Width,
			Height:        req.Height,
			UploadTaskId:  trans.Ptr(e.TaskID),
			AuthorId:      trans.Ptr(uid),
			SeriesId:      dto.SeriesId,
			EpisodeNumber: dto.EpisodeNumber,
		})
	}

	fresh, err := s.uploadTaskRepo.GetByTaskID(ctx, e.TaskID)
	if err != nil {
		return nil, err
	}
	return uploadTaskEntityToDTO(fresh), nil
}

func (s *VideoService) GetUploadTask(ctx context.Context, req *videoV1.GetUploadTaskRequest) (*videoV1.UploadTask, error) {
	e, err := s.uploadTaskRepo.GetByTaskID(ctx, req.GetTaskId())
	if err != nil {
		return nil, err
	}
	return uploadTaskEntityToDTO(e), nil
}

// mergeAndUpload 顺序合并分片并上传 MinIO。
func (s *VideoService) mergeAndUpload(ctx context.Context, e *ent.UploadTask, root string) (objectKey, mergedPath string, err error) {
	mergedPath = filepath.Join(spChunkTempDir(root, e.TaskID), "merged"+spVideoExtOf(e.FileName))
	if err = mergeChunksSP(root, e.TaskID, mergedPath, int64(e.TotalChunks)); err != nil {
		s.log.Errorf("merge chunks failed: %s", err.Error())
		return "", "", videoV1.ErrorFileMergeFailed("merge chunks failed")
	}

	f, ferr := os.Open(mergedPath)
	if ferr != nil {
		s.log.Errorf("open merged file failed: %s", ferr.Error())
		return "", "", videoV1.ErrorFileMergeFailed("open merged file failed")
	}
	defer func() { _ = f.Close() }()

	ext := spVideoExtOf(e.FileName)
	objectKey = fmt.Sprintf("sp/%s%s", e.TaskID, ext)
	// 统一媒体桶（OSS_BUCKET，缺省 shortplay，懒建+匿名只读）：
	// DB video_url 存对象键，前端按 MEDIA_BASE（<host>/<桶>）+ 键拼播放地址。
	if _, _, uerr := s.minio.PutObject(ctx, objectKey, mimeOfVideoExt(ext), f, int64(e.FileSize)); uerr != nil {
		s.log.Errorf("upload merged object failed: %s", uerr.Error())
		return "", "", videoV1.ErrorFileMergeFailed("upload merged object failed")
	}
	return objectKey, mergedPath, nil
}

func mimeOfVideoExt(ext string) string {
	switch ext {
	case ".mp4":
		return "video/mp4"
	case ".mov":
		return "video/quicktime"
	case ".m4v":
		return "video/x-m4v"
	case ".webm":
		return "video/webm"
	default:
		return "video/mp4"
	}
}

// mergeChunksSP 顺序合并分片到目标文件
func mergeChunksSP(root, taskID, targetPath string, totalChunks int64) error {
	if err := os.MkdirAll(filepath.Dir(targetPath), 0o755); err != nil {
		return err
	}
	target, err := os.OpenFile(targetPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return err
	}
	defer func() { _ = target.Close() }()

	for i := int64(0); i < totalChunks; i++ {
		part, err := os.Open(spChunkFilePath(root, taskID, i))
		if err != nil {
			return fmt.Errorf("chunk %d missing: %w", i, err)
		}
		if _, err = target.ReadFrom(part); err != nil {
			_ = part.Close()
			return err
		}
		_ = part.Close()
	}
	return nil
}

// AsyncCoverExtract asynq 订阅者：FFmpeg 单帧抽图并回填视频封面（尽力而为）。
func (s *VideoService) AsyncCoverExtract(_ string, payload *task.VideoCoverExtractTaskData) error {
	if payload == nil || payload.Object == "" {
		return nil
	}
	// 下载对象 → 抽帧 → 上传封面（系统上下文：异步任务无请求 viewer）
	ctx := spSystemContext()
	tmpDir, err := os.MkdirTemp("", "sp-cover-*")
	if err != nil {
		s.log.Errorf("create temp dir failed: %s", err.Error())
		return nil // 尽力而为：不入队重试
	}
	defer func() { _ = os.RemoveAll(tmpDir) }()

	videoPath := filepath.Join(tmpDir, "video"+filepath.Ext(payload.Object))
	if err = s.minio.GetClient().FGetObject(ctx, payload.Bucket, payload.Object, videoPath, minio.GetObjectOptions{}); err != nil {
		s.log.Errorf("download object for cover extract failed: %s", err.Error())
		return nil
	}

	coverPath := filepath.Join(tmpDir, "cover.jpg")
	if !extractCoverFFmpeg(videoPath, coverPath) {
		s.log.Warnf("cover extract skipped (ffmpeg unavailable or failed), task=%s", payload.TaskID)
		return nil
	}

	f, err := os.Open(coverPath)
	if err != nil {
		s.log.Errorf("open cover failed: %s", err.Error())
		return nil
	}
	defer func() { _ = f.Close() }()
	st, _ := f.Stat()

	coverKey := fmt.Sprintf("sp/covers/%s.jpg", payload.TaskID)
	// 封面与视频同桶（统一媒体桶），DB 存公网直取地址。
	if _, _, err = s.minio.PutObject(ctx, coverKey, "image/jpeg", f, st.Size()); err != nil {
		s.log.Errorf("upload cover failed: %s", err.Error())
		return nil
	}
	if payload.VideoID > 0 {
		coverURL := publicURLOfSP(coverKey)
		if _, uerr := s.videoRepo.Update(ctx, payload.VideoID, &videoV1.Video{CoverUrl: &coverURL}, nil); uerr != nil {
			s.log.Errorf("backfill cover url failed: %s", uerr.Error())
		}
	}
	return nil
}

// extractCoverFFmpeg 抽单帧封面（第 1 秒）；FFmpeg 不可用返回 false。
func extractCoverFFmpeg(videoPath, coverPath string) bool {
	ffmpegPath, lookErr := exec.LookPath("ffmpeg")
	if lookErr != nil {
		return false
	}
	cmd := exec.Command(ffmpegPath,
		"-y", "-ss", "1", "-i", videoPath,
		"-vframes", "1", "-q:v", "3", coverPath)
	if err := cmd.Run(); err != nil {
		return false
	}
	st, err := os.Stat(coverPath)
	return err == nil && st.Size() > 0
}

// publicURLOfSP 拼对象公网地址（统一媒体桶 + 对象键）。
// Host 取值顺序：OSS_DOWNLOAD_HOST → OSS_PUBLIC_ENDPOINT（与 configs/oss.yaml
// 的 download_host 同源）→ 本地缺省。
func publicURLOfSP(objectKey string) string {
	host := os.Getenv("OSS_DOWNLOAD_HOST")
	if host == "" {
		host = os.Getenv("OSS_PUBLIC_ENDPOINT")
	}
	if host == "" {
		host = "http://127.0.0.1:9000"
	}
	return strings.TrimRight(host, "/") + "/" + oss.DefaultBucketName() + "/" + objectKey
}

// ── 草稿 ──

func (s *VideoService) SaveDraft(ctx context.Context, req *videoV1.SaveDraftRequest) (*videoV1.VideoDraft, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, videoV1.ErrorUnauthorized("login required")
	}
	// 挂靠剧集：先校验归属（草稿保存即校验，提交发布时免二次失败）
	if req.GetSeriesId() > 0 {
		if _, _, err := s.seriesSvc.ResolveSeriesAttach(ctx, uid, req.GetSeriesId(), int64(req.GetEpisodeNumber())); err != nil {
			return nil, err
		}
	}
	dto := &videoV1.VideoDraft{
		Title:         req.Title,
		Description:   req.Description,
		Tags:          req.GetTags(),
		CoverUrl:      req.CoverUrl,
		VideoUrl:      req.VideoUrl,
		Duration:      req.Duration,
		Width:         req.Width,
		Height:        req.Height,
		UploadTaskId:  req.UploadTaskId,
		AuthorId:      trans.Ptr(uid),
		SeriesId:      req.SeriesId,
		EpisodeNumber: req.EpisodeNumber,
	}
	if req.GetId() > 0 {
		e, err := s.draftRepo.Get(ctx, req.GetId())
		if err != nil {
			return nil, err
		}
		if e.AuthorID != uid {
			return nil, videoV1.ErrorForbidden("not draft owner")
		}
		e2, err := s.draftRepo.Update(ctx, req.GetId(), dto)
		if err != nil {
			return nil, err
		}
		return draftEntityToDTO(e2), nil
	}
	e, err := s.draftRepo.Create(ctx, dto)
	if err != nil {
		return nil, err
	}
	return draftEntityToDTO(e), nil
}

func (s *VideoService) GetDraft(ctx context.Context, req *videoV1.GetDraftRequest) (*videoV1.VideoDraft, error) {
	e, err := s.draftRepo.Get(ctx, req.GetId())
	if err != nil {
		return nil, err
	}
	uid := spViewerUserID(ctx)
	if !spIsAdminCaller(ctx) && e.AuthorID != uid {
		return nil, videoV1.ErrorForbidden("not draft owner")
	}
	return draftEntityToDTO(e), nil
}

func (s *VideoService) ListDraft(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListDraftResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, videoV1.ErrorUnauthorized("login required")
	}
	items, total, err := s.draftRepo.ListByAuthor(ctx, uid, int64(req.GetPage()), int64(req.GetPageSize()))
	if err != nil {
		return nil, err
	}
	resp := &videoV1.ListDraftResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		resp.Items = append(resp.Items, draftEntityToDTO(e))
	}
	return resp, nil
}

func (s *VideoService) DeleteDraft(ctx context.Context, req *videoV1.DeleteDraftRequest) (*emptypb.Empty, error) {
	e, err := s.draftRepo.Get(ctx, req.GetId())
	if err != nil {
		return nil, err
	}
	uid := spViewerUserID(ctx)
	if !spIsAdminCaller(ctx) && e.AuthorID != uid {
		return nil, videoV1.ErrorForbidden("not draft owner")
	}
	if err = s.draftRepo.Delete(ctx, req.GetId()); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// SubmitDraft 提交草稿发布：人工审核开 → REVIEWING；关 → 直接 PUBLISHED。
func (s *VideoService) SubmitDraft(ctx context.Context, req *videoV1.SubmitDraftRequest) (*videoV1.Video, error) {
	e, err := s.draftRepo.Get(ctx, req.GetId())
	if err != nil {
		return nil, err
	}
	uid := spViewerUserID(ctx)
	if e.AuthorID != uid {
		return nil, videoV1.ErrorForbidden("not draft owner")
	}

	conf, err := s.sysConfRepo.GetEnsure(ctx)
	if err != nil {
		return nil, err
	}
	status := videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED
	if conf.ManualReviewEnabled {
		status = videoV1.VideoStatus_VIDEO_STATUS_REVIEWING
	} else if spScheduledFuture(req.ScheduledAt) {
		// 定时发布：直发路径先存 DRAFT，到期任务自动转 PUBLISHED
		status = videoV1.VideoStatus_VIDEO_STATUS_DRAFT
	}
	// 敏感词过滤：命中（标题/简介）强制转审核中，即使人工审核关
	if status == videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED {
		var draftDesc string
		if e.Description != nil {
			draftDesc = *e.Description
		}
		if spHitSensitiveWords(ctx, s.sysConfRepo, e.Title, draftDesc) {
			status = videoV1.VideoStatus_VIDEO_STATUS_REVIEWING
		}
	}

	// 草稿 → 视频正式行
	dto := &videoV1.Video{
		Title:       trans.Ptr(e.Title),
		Description: e.Description,
		CoverUrl:    e.CoverURL,
		VideoUrl:    e.VideoURL,
		Duration:    trans.Ptr(e.Duration),
		Width:       trans.Ptr(e.Width),
		Height:      trans.Ptr(e.Height),
		Status:      status.Enum(),
		AuthorId:    trans.Ptr(uid),
	}
	if status == videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED {
		dto.PublishedAt = nowTimestamppbSP()
	}
	if status == videoV1.VideoStatus_VIDEO_STATUS_DRAFT && spScheduledFuture(req.ScheduledAt) {
		dto.ScheduledAt = req.ScheduledAt
	}
	// 草稿携带的挂靠信息随提交生效（剧归属已在保存草稿时校验；集号 0 = 此刻自动排号）
	if e.SeriesID > 0 {
		seriesID, episodeNo, aerr := s.seriesSvc.ResolveSeriesAttach(ctx, uid, e.SeriesID, int64(e.EpisodeNumber))
		if aerr != nil {
			return nil, aerr
		}
		dto.SeriesId = trans.Ptr(seriesID)
		dto.EpisodeNumber = trans.Ptr(uint32(episodeNo))
	}
	video, err := s.videoRepo.Create(ctx, dto, e.Tags)
	if err != nil {
		return nil, err
	}
	// 发布副作用（追更 fan-out）与定时排程
	s.afterVideoCreated(ctx, video)
	if err = s.draftRepo.Delete(ctx, e.ID); err != nil {
		s.log.Errorf("delete draft after submit failed: %s", err.Error())
	}
	return video, nil
}

// ── 标签 ──

func (s *VideoService) ListTag(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListTagResponse, error) {
	return s.videoRepo.ListTags(ctx, req)
}

// ListHotVideos 热榜（热度分召回，App 端游客可访问）。
func (s *VideoService) ListHotVideos(ctx context.Context, req *videoV1.ListHotVideosRequest) (*videoV1.ListVideoResponse, error) {
	limit := int(req.GetLimit())
	if limit <= 0 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}
	videos, err := s.videoRepo.ListHot(ctx, limit)
	if err != nil {
		return nil, err
	}
	resp := &videoV1.ListVideoResponse{Total: trans.Ptr(int64(len(videos)))}
	for _, v := range videos {
		dto, derr := s.videoRepo.ToDTO(ctx, v)
		if derr != nil {
			continue
		}
		resp.Items = append(resp.Items, dto)
	}
	return resp, nil
}

// ModerateOffline 管理处置下架（举报处置联动入口）：走状态机白名单 + 落驳回原因 +
// 通知作者（reviewOffline 口径）。非已发布状态返回明确错误，由调用方尽力而为消化。
func (s *VideoService) ModerateOffline(ctx context.Context, videoID int64, reason string) error {
	cur, err := s.videoRepo.Get(ctx, videoID)
	if err != nil {
		return err
	}
	from := cur.GetStatus()
	if !validateVideoStatusTransition(from, videoV1.VideoStatus_VIDEO_STATUS_OFFLINE) {
		return videoV1.ErrorInvalidStatusTransition("invalid status transition %s -> %s", from, videoV1.VideoStatus_VIDEO_STATUS_OFFLINE)
	}
	updated, uerr := s.videoRepo.Update(ctx, videoID, &videoV1.Video{
		Status:       videoV1.VideoStatus_VIDEO_STATUS_OFFLINE.Enum(),
		RejectReason: &reason,
	}, nil)
	if uerr != nil {
		return uerr
	}
	s.notifyVideoReviewed(ctx, updated.GetAuthorId(), updated.GetId(), updated.GetTitle(), reason, reviewOffline)
	return nil
}

func u32sFromI64s(in []int64) []uint32 {
	out := make([]uint32, 0, len(in))
	for _, v := range in {
		out = append(out, uint32(v))
	}
	return out
}
