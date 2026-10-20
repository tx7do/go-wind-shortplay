package data

import (
	"context"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/uploadtask"
	"go-wind-shortplay/app/core/service/internal/data/ent/videodraft"

	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
)

// ── 上传任务 ──

type UploadTaskRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewUploadTaskRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *UploadTaskRepo {
	return &UploadTaskRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("upload-task/repo/core-service"),
	}
}

func uploadTaskStatusEntity(s videoV1.UploadTaskStatus) uploadtask.Status {
	switch s {
	case videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_MERGING:
		return uploadtask.StatusMerging
	case videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_COMPLETED:
		return uploadtask.StatusCompleted
	case videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_FAILED:
		return uploadtask.StatusFailed
	default:
		return uploadtask.StatusUploading
	}
}

func (r *UploadTaskRepo) GetByTaskID(ctx context.Context, taskID string) (*ent.UploadTask, error) {
	e, err := r.entClient.Client().UploadTask.Query().Where(uploadtask.TaskIDEQ(taskID)).Only(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, videoV1.ErrorTaskNotFound("upload task not found")
		}
		r.log.Errorf("get upload task failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("get upload task failed")
	}
	return e, nil
}

func (r *UploadTaskRepo) Create(ctx context.Context, taskID, fileName string, fileSize uint64, chunkSize, totalChunks uint32) (*ent.UploadTask, error) {
	builder := r.entClient.Client().UploadTask.Create().
		SetTaskID(taskID).
		SetFileName(fileName).
		SetFileSize(fileSize).
		SetChunkSize(chunkSize).
		SetTotalChunks(totalChunks).
		SetStatus(uploadtask.StatusUploading).
		SetUploadedChunks([]uint32{}).
		SetCreatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	e, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("create upload task failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("create upload task failed")
	}
	return e, nil
}

// AppendUploadedChunk 追加已上传分片（幂等）
func (r *UploadTaskRepo) AppendUploadedChunk(ctx context.Context, taskID string, chunkIndex uint32) ([]uint32, error) {
	e, err := r.GetByTaskID(ctx, taskID)
	if err != nil {
		return nil, err
	}
	chunks := e.UploadedChunks
	for _, c := range chunks {
		if c == chunkIndex {
			return chunks, nil
		}
	}
	chunks = append(chunks, chunkIndex)
	_, err = r.entClient.Client().UploadTask.UpdateOneID(e.ID).SetUploadedChunks(chunks).Save(ctx)
	if err != nil {
		r.log.Errorf("append uploaded chunk failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("append uploaded chunk failed")
	}
	return chunks, nil
}

func (r *UploadTaskRepo) UpdateStatus(ctx context.Context, id uint32, status videoV1.UploadTaskStatus, extra func(*ent.UploadTaskUpdateOne)) error {
	builder := r.entClient.Client().UploadTask.UpdateOneID(id).SetStatus(uploadTaskStatusEntity(status))
	if extra != nil {
		extra(builder)
	}
	if _, err := builder.Save(ctx); err != nil {
		r.log.Errorf("update upload task status failed: %s", err.Error())
		return videoV1.ErrorInternalServerError("update upload task status failed")
	}
	return nil
}

func (r *UploadTaskRepo) SetVideoID(ctx context.Context, id, videoID uint32) error {
	_, err := r.entClient.Client().UploadTask.UpdateOneID(id).SetVideoID(videoID).Save(ctx)
	return err
}

// ── 草稿 ──

type VideoDraftRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewVideoDraftRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *VideoDraftRepo {
	return &VideoDraftRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("video-draft/repo/core-service"),
	}
}

func (r *VideoDraftRepo) Get(ctx context.Context, id uint32) (*ent.VideoDraft, error) {
	e, err := r.entClient.Client().VideoDraft.Query().Where(videodraft.IDEQ(id)).Only(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, videoV1.ErrorDraftNotFound("draft not found")
		}
		r.log.Errorf("get draft failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("get draft failed")
	}
	return e, nil
}

// ListByAuthor 我的草稿列表
func (r *VideoDraftRepo) ListByAuthor(ctx context.Context, authorID uint32, page, pageSize uint32) ([]*ent.VideoDraft, int, error) {
	if page < 1 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	if pageSize > 50 {
		pageSize = 50
	}
	q := r.entClient.Client().VideoDraft.Query().Where(videodraft.AuthorIDEQ(authorID))
	total, err := q.Count(ctx)
	if err != nil {
		r.log.Errorf("count drafts failed: %s", err.Error())
		return nil, 0, videoV1.ErrorInternalServerError("count drafts failed")
	}
	items, err := q.Order(ent.Desc(videodraft.FieldUpdatedAt), ent.Desc(videodraft.FieldID)).
		Offset(int(page-1) * int(pageSize)).Limit(int(pageSize)).All(ctx)
	if err != nil {
		r.log.Errorf("list drafts failed: %s", err.Error())
		return nil, 0, videoV1.ErrorInternalServerError("list drafts failed")
	}
	return items, total, nil
}

func (r *VideoDraftRepo) Create(ctx context.Context, dto *videoV1.VideoDraft) (*ent.VideoDraft, error) {
	builder := r.entClient.Client().VideoDraft.Create().
		SetTitle(dto.GetTitle()).
		SetDescription(dto.GetDescription()).
		SetTags(dto.GetTags()).
		SetCoverURL(dto.GetCoverUrl()).
		SetVideoURL(dto.GetVideoUrl()).
		SetDuration(dto.GetDuration()).
		SetWidth(dto.GetWidth()).
		SetHeight(dto.GetHeight()).
		SetUploadTaskID(dto.GetUploadTaskId()).
		SetAuthorID(dto.GetAuthorId()).
		SetSeriesID(dto.GetSeriesId()).
		SetEpisodeNumber(dto.GetEpisodeNumber()).
		SetCreatedAt(time.Now()).
		SetUpdatedAt(time.Now())
	if tid, hasTenant := businessTenantID(ctx, r.entClient.Client()); hasTenant {
		builder.SetTenantID(tid)
	}
	e, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("create draft failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("create draft failed")
	}
	return e, nil
}

func (r *VideoDraftRepo) Update(ctx context.Context, id uint32, dto *videoV1.VideoDraft) (*ent.VideoDraft, error) {
	builder := r.entClient.Client().VideoDraft.UpdateOneID(id).
		SetTitle(dto.GetTitle()).
		SetDescription(dto.GetDescription()).
		SetTags(dto.GetTags()).
		SetCoverURL(dto.GetCoverUrl()).
		SetVideoURL(dto.GetVideoUrl()).
		SetDuration(dto.GetDuration()).
		SetWidth(dto.GetWidth()).
		SetHeight(dto.GetHeight()).
		SetUploadTaskID(dto.GetUploadTaskId()).
		SetSeriesID(dto.GetSeriesId()).
		SetEpisodeNumber(dto.GetEpisodeNumber()).
		SetUpdatedAt(time.Now())
	e, err := builder.Save(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return nil, videoV1.ErrorDraftNotFound("draft not found")
		}
		r.log.Errorf("update draft failed: %s", err.Error())
		return nil, videoV1.ErrorInternalServerError("update draft failed")
	}
	return e, nil
}

func (r *VideoDraftRepo) Delete(ctx context.Context, id uint32) error {
	err := r.entClient.Client().VideoDraft.DeleteOneID(id).Exec(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return videoV1.ErrorDraftNotFound("draft not found")
		}
		r.log.Errorf("delete draft failed: %s", err.Error())
		return videoV1.ErrorInternalServerError("delete draft failed")
	}
	return nil
}
