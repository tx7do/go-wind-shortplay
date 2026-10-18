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
	minio "github.com/minio/minio-go/v7"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/tx7do/go-utils/timeutil"
	"github.com/tx7do/go-utils/trans"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/uploadtask"
	crudViewer "github.com/tx7do/go-crud/viewer"
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
	defaultChunkSize uint32 = 4 * 1024 * 1024
	// 单个上传任务的并发分片写入不做限制（顺序上传）

	videoBucket = "videos"
)

// spUploadTempRootDef 分片暂存缺省根目录
var spUploadTempRootDef = os.TempDir()

type VideoService struct {
	videoV1.UnimplementedVideoServiceServer

	log *log.Helper

	videoRepo     *data.VideoRepo
	draftRepo     *data.VideoDraftRepo
	uploadTaskRepo *data.UploadTaskRepo
	sysConfRepo   *data.SysConfRepo

	minio *oss.MinIOClient

	taskEnqueuer TaskEnqueuer
}

func NewVideoService(
	ctx *bootstrap.Context,
	videoRepo *data.VideoRepo,
	draftRepo *data.VideoDraftRepo,
	uploadTaskRepo *data.UploadTaskRepo,
	sysConfRepo *data.SysConfRepo,
	minio *oss.MinIOClient,
) *VideoService {
	return &VideoService{
		log:            ctx.NewLoggerHelper("video/service/core-service"),
		videoRepo:      videoRepo,
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
		TotalChunks:    trans.Ptr(e.TotalChunks),
		UploadedChunks: e.UploadedChunks,
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
	return &videoV1.VideoDraft{
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
}

// ── viewer 助手 ──

// spViewerUserID 取当前登录用户 ID（未登录返回 0）
func spViewerUserID(ctx context.Context) uint32 {
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
	return s.videoRepo.ListByAuthor(ctx, req.GetUserId(), isSelf, req.GetPageNum(), req.GetPageSize())
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
	}
	if to == videoV1.VideoStatus_VIDEO_STATUS_REJECTED || to == videoV1.VideoStatus_VIDEO_STATUS_OFFLINE {
		reason := req.GetReason()
		if strings.TrimSpace(reason) == "" {
			return nil, videoV1.ErrorBadRequest("reason is required")
		}
		dto.RejectReason = &reason
	}

	// 管理端操作者记录为更新者（viewer 注入由 ent middleware 负责）
	return s.videoRepo.Update(ctx, req.GetId(), dto, nil)
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

func spChunkFilePath(root, taskID string, chunkIndex uint32) string {
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

	maxBytes := uint64(conf.MaxUploadSizeMB) * 1024 * 1024
	if maxBytes > 0 && req.GetFileSize() > maxBytes {
		return nil, videoV1.ErrorFileTooLarge("file exceeds max size %dMB", conf.MaxUploadSizeMB)
	}

	chunkSize := req.GetChunkSize()
	if chunkSize <= 0 {
		chunkSize = defaultChunkSize
	}
	totalChunks := uint32((req.GetFileSize() + uint64(chunkSize) - 1) / uint64(chunkSize))
	if totalChunks == 0 {
		totalChunks = 1
	}

	taskID := newShortplayTaskID()
	e, err := s.uploadTaskRepo.Create(ctx, taskID, req.GetFileName(), req.GetFileSize(), chunkSize, totalChunks)
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

	path := spChunkFilePath(spUploadTempRoot(), e.TaskID, req.GetChunkIndex())
	if err = os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		s.log.Errorf("mkdir chunk dir failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("write chunk failed")
	}
	if err = os.WriteFile(path, req.GetData(), 0o644); err != nil {
		s.log.Errorf("write chunk failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("write chunk failed")
	}

	chunks, err := s.uploadTaskRepo.AppendUploadedChunk(ctx, e.TaskID, req.GetChunkIndex())
	if err != nil {
		return nil, err
	}
	return &videoV1.UploadChunkResponse{UploadedChunks: chunks}, nil
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
	if uint32(len(e.UploadedChunks)) < e.TotalChunks {
		return nil, videoV1.ErrorChunkMissing("chunks missing: %d/%d", len(e.UploadedChunks), e.TotalChunks)
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

	video, err := s.videoRepo.Create(ctx, dto, req.GetTags())
	if err != nil {
		_ = s.uploadTaskRepo.UpdateStatus(ctx, e.ID, videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_FAILED, nil)
		return nil, err
	}
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
			Bucket:  videoBucket,
			Object:  objectKey,
			VideoID: video.GetId(),
		}); err != nil {
			s.log.Errorf("enqueue cover extract failed: %v", err)
		}
	}

	if req.GetAsDraft() {
		// 存草稿：建草稿行并回填任务
		_, _ = s.draftRepo.Create(ctx, &videoV1.VideoDraft{
			Title:        dto.Title,
			Description:  dto.Description,
			Tags:         req.GetTags(),
			CoverUrl:     req.CoverUrl,
			VideoUrl:     trans.Ptr(objectKey),
			Duration:     req.Duration,
			Width:        req.Width,
			Height:       req.Height,
			UploadTaskId: trans.Ptr(e.TaskID),
			AuthorId:     trans.Ptr(uid),
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
	if err = mergeChunksSP(root, e.TaskID, mergedPath, e.TotalChunks); err != nil {
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
	if _, _, _, uerr := s.minio.UploadFile(ctx, videoBucket, objectKey, mimeOfVideoExt(ext), f, int64(e.FileSize)); uerr != nil {
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
func mergeChunksSP(root, taskID, targetPath string, totalChunks uint32) error {
	if err := os.MkdirAll(filepath.Dir(targetPath), 0o755); err != nil {
		return err
	}
	target, err := os.OpenFile(targetPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return err
	}
	defer func() { _ = target.Close() }()

	for i := uint32(0); i < totalChunks; i++ {
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
	_, _, _, err = s.minio.UploadFile(ctx, videoBucket, coverKey, "image/jpeg", f, st.Size())
	if err != nil {
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

// publicURLOfSP 拼对象公网地址（与基座 JoinObjectUrl 口径一致：下载域名/桶/键）。
func publicURLOfSP(objectKey string) string {
	host := os.Getenv("OSS_DOWNLOAD_HOST")
	if host == "" {
		host = "http://127.0.0.1:9000"
	}
	return strings.TrimRight(host, "/") + "/" + videoBucket + "/" + objectKey
}

// ── 草稿 ──

func (s *VideoService) SaveDraft(ctx context.Context, req *videoV1.SaveDraftRequest) (*videoV1.VideoDraft, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, videoV1.ErrorUnauthorized("login required")
	}
	dto := &videoV1.VideoDraft{
		Title:        req.Title,
		Description:  req.Description,
		Tags:         req.GetTags(),
		CoverUrl:     req.CoverUrl,
		VideoUrl:     req.VideoUrl,
		Duration:     req.Duration,
		Width:        req.Width,
		Height:       req.Height,
		UploadTaskId: req.UploadTaskId,
		AuthorId:     trans.Ptr(uid),
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
	items, total, err := s.draftRepo.ListByAuthor(ctx, uid, req.GetPage(), req.GetPageSize())
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
	video, err := s.videoRepo.Create(ctx, dto, e.Tags)
	if err != nil {
		return nil, err
	}
	if err = s.draftRepo.Delete(ctx, e.ID); err != nil {
		s.log.Errorf("delete draft after submit failed: %s", err.Error())
	}
	return video, nil
}

// ── 标签 ──

func (s *VideoService) ListTag(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListTagResponse, error) {
	return s.videoRepo.ListTags(ctx, req)
}
