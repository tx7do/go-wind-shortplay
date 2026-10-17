package service

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"

	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/pkg/authctx"
	"go-wind-shortplay/pkg/oss"
)

type VideoService struct {
	videoV1.UnimplementedVideoServiceServer

	videoRepo    *data.VideoRepo
	sysConfigRepo *data.SysConfigRepo
	oss          *oss.MinIOClient
	log          *log.Helper

	// chunkRoot 分片暂存根目录
	chunkRoot string
}

func NewVideoService(ctx *bootstrap.Context, videoRepo *data.VideoRepo, sysConfigRepo *data.SysConfigRepo, minioClient *oss.MinIOClient) *VideoService {
	root := os.Getenv("UPLOAD_TEMP_DIR")
	if root == "" {
		root = filepath.Join(os.TempDir(), "shortplay-uploads")
	}
	return &VideoService{
		videoRepo:     videoRepo,
		sysConfigRepo: sysConfigRepo,
		oss:           minioClient,
		log:           ctx.NewLoggerHelper("video/service/core-service"),
		chunkRoot:     root,
	}
}

// ── 视频查询 / 编辑 ──

func (s *VideoService) GetVideo(ctx context.Context, req *videoV1.GetVideoRequest) (*videoV1.Video, error) {
	v, err := s.videoRepo.GetByID(ctx, req.GetId())
	if err != nil {
		return nil, videoV1.ErrorVideoNotFound("video not found")
	}
	tags, _ := s.videoRepo.TagsOfVideo(ctx, v.ID)
	return toVideo(v, tags), nil
}

func (s *VideoService) ListVideo(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListVideoResponse, error) {
	offset, limit := pageArgs(req.GetPage(), req.GetPageSize())
	// 管理端筛选约定：query=标题关键字；filter=状态数字（1草稿/2审核中/3已发布/4驳回/5下架）
	var status *uint8
	if f := parseUint8(req.GetFilter()); f > 0 {
		status = &f
	}
	items, total, err := s.videoRepo.List(ctx, offset, limit, status, nil, req.GetQuery(), req.GetOrderBy())
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("list videos failed")
	}
	return s.toVideoList(ctx, items, total)
}

// ListUserVideo 用户主页作品列表：本人含全部状态，他人仅已发布
func (s *VideoService) ListUserVideo(ctx context.Context, req *videoV1.ListUserVideoRequest) (*videoV1.ListVideoResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	viewer := req.GetUserId()
	statuses := []uint8{uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED)}
	if uid == viewer {
		// 本人：作品 + 审核中 + 驳回 + 下架（草稿走草稿列表，不混入作品 Tab）
		statuses = []uint8{
			uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED),
			uint8(videoV1.VideoStatus_VIDEO_STATUS_REVIEWING),
			uint8(videoV1.VideoStatus_VIDEO_STATUS_REJECTED),
			uint8(videoV1.VideoStatus_VIDEO_STATUS_OFFLINE),
		}
	}
	offset, limit := pageArgs(req.GetPageNum(), req.GetPageSize())
	items, total, err := s.videoRepo.ListByAuthorAndStatuses(ctx, viewer, statuses, offset, limit)
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("list user videos failed")
	}
	return s.toVideoList(ctx, items, total)
}

func (s *VideoService) UpdateVideo(ctx context.Context, req *videoV1.UpdateVideoRequest) (*videoV1.Video, error) {
	v, err := s.videoRepo.GetByID(ctx, req.GetId())
	if err != nil {
		return nil, videoV1.ErrorVideoNotFound("video not found")
	}
	if uid := authctx.UserIDFromContext(ctx); uid > 0 && v.AuthorID != nil && *v.AuthorID != uid {
		return nil, videoV1.ErrorNotVideoOwner("not video owner")
	}
	u, err := s.videoRepo.UpdateVideo(ctx, req.GetId(), req.Title, req.Description, req.CoverUrl)
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("update video failed")
	}
	if req.Tags != nil {
		if err := s.videoRepo.ReplaceTags(ctx, req.GetId(), req.Tags); err != nil {
			s.log.Warnf("replace tags failed: %s", err.Error())
		}
	}
	tags, _ := s.videoRepo.TagsOfVideo(ctx, u.ID)
	return toVideo(u, tags), nil
}

func (s *VideoService) DeleteVideo(ctx context.Context, req *videoV1.DeleteVideoRequest) (*emptypb.Empty, error) {
	v, err := s.videoRepo.GetByID(ctx, req.GetId())
	if err != nil {
		return nil, videoV1.ErrorVideoNotFound("video not found")
	}
	if uid := authctx.UserIDFromContext(ctx); uid > 0 && v.AuthorID != nil && *v.AuthorID != uid {
		return nil, videoV1.ErrorNotVideoOwner("not video owner")
	}
	if err := s.videoRepo.Delete(ctx, req.GetId()); err != nil {
		return nil, videoV1.ErrorInternalServerError("delete video failed")
	}
	return &emptypb.Empty{}, nil
}

// ChangeVideoStatus 状态流转（审核通过 / 驳回 / 下架）
func (s *VideoService) ChangeVideoStatus(ctx context.Context, req *videoV1.ChangeVideoStatusRequest) (*videoV1.Video, error) {
	v, err := s.videoRepo.GetByID(ctx, req.GetId())
	if err != nil {
		return nil, videoV1.ErrorVideoNotFound("video not found")
	}
	fromStatus := uint8(0)
	if v.Status != nil {
		fromStatus = *v.Status
	}
	if err := validateTransition(fromStatus, uint8(req.GetStatus())); err != nil {
		return nil, err
	}
	var reason *string
	if req.Reason != nil {
		reason = req.Reason
	}
	u, err := s.videoRepo.ChangeStatus(ctx, req.GetId(), uint8(req.GetStatus()), reason)
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("change status failed")
	}
	tags, _ := s.videoRepo.TagsOfVideo(ctx, u.ID)
	return toVideo(u, tags), nil
}

// validateTransition 合法状态流转校验
//
//	DRAFT→REVIEWING→PUBLISHED；REVIEWING→REJECTED；PUBLISHED→OFFLINE；
//	REJECTED→REVIEWING(重新提交)；OFFLINE→PUBLISHED(恢复)
func validateTransition(from, to uint8) error {
	allowed := map[uint8][]uint8{
		uint8(videoV1.VideoStatus_VIDEO_STATUS_DRAFT): {
			uint8(videoV1.VideoStatus_VIDEO_STATUS_REVIEWING),
			uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED),
		},
		uint8(videoV1.VideoStatus_VIDEO_STATUS_REVIEWING): {
			uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED),
			uint8(videoV1.VideoStatus_VIDEO_STATUS_REJECTED),
		},
		uint8(videoV1.VideoStatus_VIDEO_STATUS_REJECTED): {
			uint8(videoV1.VideoStatus_VIDEO_STATUS_REVIEWING),
			uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED),
		},
		uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED): {
			uint8(videoV1.VideoStatus_VIDEO_STATUS_OFFLINE),
		},
		uint8(videoV1.VideoStatus_VIDEO_STATUS_OFFLINE): {
			uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED),
		},
	}
	for _, a := range allowed[from] {
		if a == to {
			return nil
		}
	}
	return videoV1.ErrorInvalidStatusTransition("invalid status transition")
}

func (s *VideoService) toVideoList(ctx context.Context, items []*ent.Video, total int) (*videoV1.ListVideoResponse, error) {
	out := make([]*videoV1.Video, 0, len(items))
	for _, it := range items {
		tags, _ := s.videoRepo.TagsOfVideo(ctx, it.ID)
		out = append(out, toVideo(it, tags))
	}
	return &videoV1.ListVideoResponse{Items: out, Total: ptr(int64(total))}, nil
}

// ── 分片上传 ──

func (s *VideoService) CreateUploadTask(ctx context.Context, req *videoV1.CreateUploadTaskRequest) (*videoV1.UploadTask, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, videoV1.ErrorUnauthorized("login required")
	}
	cfg, err := s.sysConfigRepo.Get(ctx)
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("load sysconf failed")
	}
	ext := videoExtOf(req.GetFileName())
	if !allowedVideoExt(ext, cfg.AllowedVideoTypes) {
		return nil, videoV1.ErrorFileTypeNotAllowed("file type not allowed: %s", ext)
	}
	maxMB := uint32(500)
	if cfg.MaxUploadSizeMB != nil {
		maxMB = *cfg.MaxUploadSizeMB
	}
	maxBytes := int64(maxMB) << 20
	if int64(req.GetFileSize()) > maxBytes {
		return nil, videoV1.ErrorFileTooLarge("file exceeds max upload size")
	}
	chunkSize := req.ChunkSize
	if chunkSize == nil || *chunkSize == 0 {
		cs := uint32(4 << 20) // 缺省 4MB
		chunkSize = &cs
	}
	totalChunks := uint32((int64(req.GetFileSize()) + int64(*chunkSize) - 1) / int64(*chunkSize))
	if totalChunks < 1 {
		totalChunks = 1
	}
	taskID := newTaskID()
	t, err := s.videoRepo.CreateUploadTask(ctx, taskID, req.GetFileName(), int64(req.GetFileSize()), *chunkSize, totalChunks, uid)
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("create upload task failed")
	}
	_ = os.MkdirAll(chunkTempDir(s.chunkRoot, taskID), 0o755)
	return toUploadTask(t), nil
}

func (s *VideoService) UploadChunk(ctx context.Context, req *videoV1.UploadChunkRequest) (*videoV1.UploadChunkResponse, error) {
	t, err := s.videoRepo.GetUploadTask(ctx, req.GetTaskId())
	if err != nil {
		return nil, videoV1.ErrorTaskNotFound("upload task not found")
	}
	if t.AuthorID == nil || authctx.UserIDFromContext(ctx) != *t.AuthorID {
		return nil, videoV1.ErrorForbidden("not task owner")
	}
	dir := chunkTempDir(s.chunkRoot, req.GetTaskId())
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, videoV1.ErrorInternalServerError("prepare chunk dir failed")
	}
	if err := os.WriteFile(chunkFilePath(s.chunkRoot, req.GetTaskId(), req.GetChunkIndex()), req.GetData(), 0o644); err != nil {
		return nil, videoV1.ErrorInternalServerError("write chunk failed")
	}
	t, err = s.videoRepo.AppendUploadChunk(ctx, req.GetTaskId(), req.GetChunkIndex())
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("record chunk failed")
	}
	return &videoV1.UploadChunkResponse{UploadedChunks: t.UploadedChunks}, nil
}

// CompleteUpload 校验分片完整性 → 合并 → 上传 MinIO → 抽帧封面 → 落视频或草稿
func (s *VideoService) CompleteUpload(ctx context.Context, req *videoV1.CompleteUploadRequest) (*videoV1.UploadTask, error) {
	t, err := s.videoRepo.GetUploadTask(ctx, req.GetTaskId())
	if err != nil {
		return nil, videoV1.ErrorTaskNotFound("upload task not found")
	}
	if t.AuthorID == nil || authctx.UserIDFromContext(ctx) != *t.AuthorID {
		return nil, videoV1.ErrorForbidden("not task owner")
	}
	totalChunks := uint32(0)
	if t.TotalChunks != nil {
		totalChunks = *t.TotalChunks
	}
	if len(t.UploadedChunks) < int(totalChunks) {
		return nil, videoV1.ErrorChunkMissing("chunks incomplete")
	}

	cfg, _ := s.sysConfigRepo.Get(ctx)
	ext := videoExtOf(t.FileName)

	// 1. 合并分片
	taskDir := chunkTempDir(s.chunkRoot, t.TaskID)
	mergedPath := filepath.Join(taskDir, "merged"+ext)
	if err := mergeChunks(s.chunkRoot, t.TaskID, mergedPath, totalChunks); err != nil {
		return nil, videoV1.ErrorFileMergeFailed("merge chunks failed")
	}

	// 2. 上传 MinIO
	objectKey := fmt.Sprintf("videos/%s/%s%s", time.Now().Format("2006/01"), t.TaskID, ext)
	var videoURL string
	if s.oss != nil {
		f, err := os.Open(mergedPath)
		if err != nil {
			return nil, videoV1.ErrorInternalServerError("open merged file failed")
		}
		contentType := "video/mp4"
		if ext == ".webm" {
			contentType = "video/webm"
		} else if ext == ".mov" {
			contentType = "video/quicktime"
		}
		videoURL, err = s.oss.PutObject(ctx, objectKey, f, contentType)
		f.Close()
		if err != nil {
			return nil, videoV1.ErrorInternalServerError("upload to storage failed")
		}
	} else {
		videoURL = objectKey // MinIO 未配置：仅记对象键（开发态）
	}

	// 3. 抽帧封面（尽力而为）并上传
	coverURL := req.GetCoverUrl()
	if coverURL == "" {
		if coverPath := extractCoverLocal(mergedPath, taskDir); coverPath != "" && s.oss != nil {
			cf, err := os.Open(coverPath)
			if err == nil {
				coverKey := fmt.Sprintf("covers/%s/%s.jpg", time.Now().Format("2006/01"), t.TaskID)
				if url, err := s.oss.PutObject(ctx, coverKey, cf, "image/jpeg"); err == nil {
					coverURL = url
				}
				cf.Close()
			}
		}
	}

	// 4. 落库：草稿 or 视频（按人工审核开关决定初始状态）
	var created *ent.Video
	if req.GetAsDraft() {
		_, err = s.videoRepo.SaveDraft(ctx, nil, *t.AuthorID, &data.DraftBuilder{
			Title:        req.Title,
			Description:  req.Description,
			CoverURL:     strPtrOrNil(coverURL),
			VideoURL:     strPtrOrNil(videoURL),
			Duration:     req.Duration,
			Width:        req.Width,
			Height:       req.Height,
			UploadTaskID: ptr(t.TaskID),
		})
		if err != nil {
			return nil, videoV1.ErrorInternalServerError("save draft failed")
		}
	} else {
		authorID := *t.AuthorID
		title := req.GetTitle()
		if title == "" {
			title = t.FileName
		}
		status := uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED)
		if cfg != nil && cfg.ManualReviewEnabled != nil && *cfg.ManualReviewEnabled {
			status = uint8(videoV1.VideoStatus_VIDEO_STATUS_REVIEWING)
		}
		now := time.Now()
		created, err = s.videoRepo.CreateVideo(ctx, &data.VideoBuilder{
			Title:       title,
			Description: req.Description,
			CoverURL:    strPtrOrNil(coverURL),
			VideoURL:    videoURL,
			Duration:    req.Duration,
			Width:       req.Width,
			Height:      req.Height,
			Status:      status,
			AuthorID:    authorID,
			PublishedAt: &now,
		})
		if err != nil {
			return nil, videoV1.ErrorInternalServerError("create video failed")
		}
		if len(req.Tags) > 0 {
			if err := s.videoRepo.ReplaceTags(ctx, created.ID, req.Tags); err != nil {
				s.log.Warnf("replace tags failed: %s", err.Error())
			}
		}
	}

	// 5. 清理本地分片 + 更新任务状态
	_ = os.RemoveAll(taskDir)
	var videoID *uint32
	status := uint8(videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_COMPLETED)
	if created != nil {
		videoID = ptr(created.ID)
	}
	t, err = s.videoRepo.UpdateUploadTaskStatus(ctx, t.TaskID, status, ptr(objectKey), videoID)
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("finalize upload task failed")
	}
	return toUploadTask(t), nil
}

func (s *VideoService) GetUploadTask(ctx context.Context, req *videoV1.GetUploadTaskRequest) (*videoV1.UploadTask, error) {
	t, err := s.videoRepo.GetUploadTask(ctx, req.GetTaskId())
	if err != nil {
		return nil, videoV1.ErrorTaskNotFound("upload task not found")
	}
	return toUploadTask(t), nil
}

// ── 草稿 ──

func (s *VideoService) SaveDraft(ctx context.Context, req *videoV1.SaveDraftRequest) (*videoV1.VideoDraft, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, videoV1.ErrorUnauthorized("login required")
	}
	d, err := s.videoRepo.SaveDraft(ctx, req.Id, uid, &data.DraftBuilder{
		Title:        req.Title,
		Description:  req.Description,
		CoverURL:     req.CoverUrl,
		VideoURL:     req.VideoUrl,
		Duration:     req.Duration,
		Width:        req.Width,
		Height:       req.Height,
		UploadTaskID: req.UploadTaskId,
	})
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("save draft failed")
	}
	return toVideoDraft(d), nil
}

func (s *VideoService) GetDraft(ctx context.Context, req *videoV1.GetDraftRequest) (*videoV1.VideoDraft, error) {
	d, err := s.videoRepo.GetDraft(ctx, req.GetId())
	if err != nil {
		return nil, videoV1.ErrorDraftNotFound("draft not found")
	}
	if d.AuthorID == nil || authctx.UserIDFromContext(ctx) != *d.AuthorID {
		return nil, videoV1.ErrorForbidden("not draft owner")
	}
	return toVideoDraft(d), nil
}

func (s *VideoService) ListDraft(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListDraftResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, videoV1.ErrorUnauthorized("login required")
	}
	offset, limit := pageArgs(req.GetPage(), req.GetPageSize())
	items, total, err := s.videoRepo.ListDrafts(ctx, uid, offset, limit)
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("list drafts failed")
	}
	out := make([]*videoV1.VideoDraft, 0, len(items))
	for _, it := range items {
		out = append(out, toVideoDraft(it))
	}
	return &videoV1.ListDraftResponse{Items: out, Total: ptr(int64(total))}, nil
}

func (s *VideoService) DeleteDraft(ctx context.Context, req *videoV1.DeleteDraftRequest) (*emptypb.Empty, error) {
	d, err := s.videoRepo.GetDraft(ctx, req.GetId())
	if err != nil {
		return nil, videoV1.ErrorDraftNotFound("draft not found")
	}
	if d.AuthorID == nil || authctx.UserIDFromContext(ctx) != *d.AuthorID {
		return nil, videoV1.ErrorForbidden("not draft owner")
	}
	if err := s.videoRepo.DeleteDraft(ctx, req.GetId()); err != nil {
		return nil, videoV1.ErrorInternalServerError("delete draft failed")
	}
	return &emptypb.Empty{}, nil
}

// SubmitDraft 草稿提交发布（进入审核队列或直接发布）
func (s *VideoService) SubmitDraft(ctx context.Context, req *videoV1.SubmitDraftRequest) (*videoV1.Video, error) {
	d, err := s.videoRepo.GetDraft(ctx, req.GetId())
	if err != nil {
		return nil, videoV1.ErrorDraftNotFound("draft not found")
	}
	if d.AuthorID == nil || authctx.UserIDFromContext(ctx) != *d.AuthorID {
		return nil, videoV1.ErrorForbidden("not draft owner")
	}
	if d.VideoURL == nil || *d.VideoURL == "" {
		return nil, videoV1.ErrorBadRequest("draft has no video attached")
	}

	cfg, _ := s.sysConfigRepo.Get(ctx)
	status := uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED)
	if cfg != nil && cfg.ManualReviewEnabled != nil && *cfg.ManualReviewEnabled {
		status = uint8(videoV1.VideoStatus_VIDEO_STATUS_REVIEWING)
	}
	now := time.Now()
	title := ""
	if d.Title != nil {
		title = *d.Title
	}
	v, err := s.videoRepo.CreateVideo(ctx, &data.VideoBuilder{
		Title:       title,
		Description: d.Description,
		CoverURL:    d.CoverURL,
		VideoURL:    *d.VideoURL,
		Duration:    d.Duration,
		Width:       d.Width,
		Height:      d.Height,
		Status:      status,
		AuthorID:    *d.AuthorID,
		PublishedAt: &now,
	})
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("create video failed")
	}

	// 草稿提交即消费：删除草稿，保留视频可继续编辑
	_ = s.videoRepo.DeleteDraft(ctx, d.ID)

	tags, _ := s.videoRepo.TagsOfVideo(ctx, v.ID)
	return toVideo(v, tags), nil
}

func (s *VideoService) ListTag(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListTagResponse, error) {
	offset, limit := pageArgs(req.GetPage(), req.GetPageSize())
	items, total, err := s.videoRepo.ListTags(ctx, offset, limit)
	if err != nil {
		return nil, videoV1.ErrorInternalServerError("list tags failed")
	}
	out := make([]*videoV1.Tag, 0, len(items))
	for _, it := range items {
		out = append(out, toTag(it))
	}
	return &videoV1.ListTagResponse{Items: out, Total: ptr(int64(total))}, nil
}

func strPtrOrNil(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

