package data

import (
	"context"
	"strings"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/uploadtask"
	"go-wind-shortplay/app/core/service/internal/data/ent/videodraft"
	"go-wind-shortplay/app/core/service/internal/data/ent/videotag"
	"go-wind-shortplay/app/core/service/internal/data/ent/videotagrel"
	"go-wind-shortplay/app/core/service/internal/data/ent/video"
)

// VideoRepo 视频主表 / 草稿 / 标签 / 上传任务仓储
type VideoRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewVideoRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *VideoRepo {
	return &VideoRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("video/repo/core-service"),
	}
}

func (r *VideoRepo) Client() *ent.Client {
	return r.entClient.Client()
}

// ── 视频 ──

func (r *VideoRepo) GetByID(ctx context.Context, id uint32) (*ent.Video, error) {
	return r.Client().Video.Query().Where(video.ID(id)).Only(ctx)
}

// List 视频列表；status/authorID 为 nil 表示不过滤；keyword 非空时标题模糊匹配
func (r *VideoRepo) List(ctx context.Context, offset, limit int, status *uint8, authorID *uint32, keyword, orderBy string) ([]*ent.Video, int, error) {
	q := r.Client().Video.Query()
	if status != nil {
		q = q.Where(video.Status(*status))
	}
	if authorID != nil {
		q = q.Where(video.AuthorID(*authorID))
	}
	if keyword != "" {
		q = q.Where(video.TitleContains(keyword))
	}
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	switch orderBy {
	case "like_count":
		q = q.Order(ent.Desc(video.FieldLikeCount))
	case "view_count":
		q = q.Order(ent.Desc(video.FieldViewCount))
	case "collect_count":
		q = q.Order(ent.Desc(video.FieldCollectCount))
	case "comment_count":
		q = q.Order(ent.Desc(video.FieldCommentCount))
	default:
		q = q.Order(ent.Desc(video.FieldID))
	}
	items, err := q.Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

// CreateVideo 创建视频记录
func (r *VideoRepo) CreateVideo(ctx context.Context, b *VideoBuilder) (*ent.Video, error) {
	c := r.Client().Video.Create().
		SetTitle(b.Title).
		SetVideoURL(b.VideoURL).
		SetNillableDescription(b.Description).
		SetNillableCoverURL(b.CoverURL).
		SetNillableDuration(b.Duration).
		SetNillableWidth(b.Width).
		SetNillableHeight(b.Height).
		SetStatus(b.Status).
		SetAuthorID(b.AuthorID).
		SetNillablePublishedAt(b.PublishedAt)
	return c.Save(ctx)
}

// VideoBuilder 视频写入参数（service 层组装，repo 不理解业务规则）
type VideoBuilder struct {
	Title       string
	Description *string
	CoverURL    *string
	VideoURL    string
	Duration    *uint32
	Width       *uint32
	Height      *uint32
	Status      uint8
	AuthorID    uint32
	PublishedAt *time.Time
}

func (r *VideoRepo) UpdateVideo(ctx context.Context, id uint32, title, description, coverURL *string) (*ent.Video, error) {
	return r.Client().Video.UpdateOneID(id).
		SetNillableTitle(title).
		SetNillableDescription(description).
		SetNillableCoverURL(coverURL).
		Save(ctx)
}

func (r *VideoRepo) Delete(ctx context.Context, id uint32) error {
	return r.Client().Video.DeleteOneID(id).Exec(ctx)
}

func (r *VideoRepo) ChangeStatus(ctx context.Context, id uint32, status uint8, rejectReason *string) (*ent.Video, error) {
	u := r.Client().Video.UpdateOneID(id).SetStatus(status)
	if rejectReason != nil {
		u.SetRejectReason(*rejectReason)
	}
	if status == uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED) {
		u.SetPublishedAt(time.Now())
	}
	return u.Save(ctx)
}

// ReplaceTags 重设视频标签关联（先删后建），并维护标签引用计数
func (r *VideoRepo) ReplaceTags(ctx context.Context, videoID uint32, tagNames []string) error {
	return r.withTx(ctx, func(tx *ent.Tx) error {
		olds, err := tx.VideoTagRel.Query().Where(videotagrel.VideoID(videoID)).All(ctx)
		if err != nil {
			return err
		}
		for _, old := range olds {
			if err := tx.VideoTagRel.DeleteOneID(old.ID).Exec(ctx); err != nil {
				return err
			}
			if old.TagID != nil {
				if err := decrTagCount(ctx, tx, *old.TagID); err != nil {
					return err
				}
			}
		}
		for _, name := range tagNames {
			name = strings.TrimSpace(name)
			if name == "" {
				continue
			}
			tagID, err := ensureTag(ctx, tx, name)
			if err != nil {
				return err
			}
			exist, err := tx.VideoTagRel.Query().
				Where(videotagrel.VideoID(videoID), videotagrel.TagID(tagID)).
				Exist(ctx)
			if err != nil {
				return err
			}
			if exist {
				continue
			}
			if _, err := tx.VideoTagRel.Create().SetVideoID(videoID).SetTagID(tagID).Save(ctx); err != nil {
				return err
			}
			if err := incrTagCount(ctx, tx, tagID); err != nil {
				return err
			}
		}
		return nil
	})
}

// TagsOfVideo 查询视频的标签名列表
func (r *VideoRepo) TagsOfVideo(ctx context.Context, videoID uint32) ([]string, error) {
	rels, err := r.Client().VideoTagRel.Query().Where(videotagrel.VideoID(videoID)).All(ctx)
	if err != nil {
		return nil, err
	}
	if len(rels) == 0 {
		return nil, nil
	}
	tagIDs := make([]uint32, 0, len(rels))
	for _, rel := range rels {
		if rel.TagID != nil {
			tagIDs = append(tagIDs, *rel.TagID)
		}
	}
	tags, err := r.Client().VideoTag.Query().Where(videotag.IDIn(tagIDs...)).All(ctx)
	if err != nil {
		return nil, err
	}
	names := make([]string, 0, len(tags))
	for _, t := range tags {
		names = append(names, t.Name)
	}
	return names, nil
}

func (r *VideoRepo) ListTags(ctx context.Context, offset, limit int) ([]*ent.VideoTag, int, error) {
	q := r.Client().VideoTag.Query()
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Desc(videotag.FieldVideoCount)).Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

func ensureTag(ctx context.Context, tx *ent.Tx, name string) (uint32, error) {
	t, err := tx.VideoTag.Query().Where(videotag.Name(name)).Only(ctx)
	if err == nil {
		return t.ID, nil
	}
	if ent.IsNotFound(err) {
		created, cErr := tx.VideoTag.Create().SetName(name).Save(ctx)
		if cErr != nil {
			// 并发创建撞唯一键：再查一次
			if again, aErr := tx.VideoTag.Query().Where(videotag.Name(name)).Only(ctx); aErr == nil {
				return again.ID, nil
			}
			return 0, cErr
		}
		return created.ID, nil
	}
	return 0, err
}

func incrTagCount(ctx context.Context, tx *ent.Tx, tagID uint32) error {
	_, err := tx.VideoTag.UpdateOneID(tagID).AddVideoCount(1).Save(ctx)
	return err
}

func decrTagCount(ctx context.Context, tx *ent.Tx, tagID uint32) error {
	_, err := tx.VideoTag.UpdateOneID(tagID).AddVideoCount(-1).Save(ctx)
	return err
}

// withTx 事务包装
func (r *VideoRepo) withTx(ctx context.Context, fn func(tx *ent.Tx) error) (err error) {
	tx, err := r.Client().Tx(ctx)
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
			return
		}
		err = tx.Commit()
	}()
	return fn(tx)
}

// ── 草稿 ──

func (r *VideoRepo) SaveDraft(ctx context.Context, id *uint32, authorID uint32, b *DraftBuilder) (*ent.VideoDraft, error) {
	if id != nil && *id > 0 {
		return r.Client().VideoDraft.UpdateOneID(*id).
			SetNillableTitle(b.Title).
			SetNillableDescription(b.Description).
			SetNillableCoverURL(b.CoverURL).
			SetNillableVideoURL(b.VideoURL).
			SetNillableDuration(b.Duration).
			SetNillableWidth(b.Width).
			SetNillableHeight(b.Height).
			SetNillableUploadTaskID(b.UploadTaskID).
			Save(ctx)
	}
	return r.Client().VideoDraft.Create().
		SetNillableTitle(b.Title).
		SetNillableDescription(b.Description).
		SetNillableCoverURL(b.CoverURL).
		SetNillableVideoURL(b.VideoURL).
		SetNillableDuration(b.Duration).
		SetNillableWidth(b.Width).
		SetNillableHeight(b.Height).
		SetNillableUploadTaskID(b.UploadTaskID).
		SetAuthorID(authorID).
		Save(ctx)
}

// DraftBuilder 草稿写入参数
type DraftBuilder struct {
	Title        *string
	Description  *string
	CoverURL     *string
	VideoURL     *string
	Duration     *uint32
	Width        *uint32
	Height       *uint32
	UploadTaskID *string
}

func (r *VideoRepo) GetDraft(ctx context.Context, id uint32) (*ent.VideoDraft, error) {
	return r.Client().VideoDraft.Query().Where(videodraft.ID(id)).Only(ctx)
}

func (r *VideoRepo) ListDrafts(ctx context.Context, authorID uint32, offset, limit int) ([]*ent.VideoDraft, int, error) {
	q := r.Client().VideoDraft.Query().Where(videodraft.AuthorID(authorID))
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Desc(videodraft.FieldUpdatedAt)).Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

func (r *VideoRepo) DeleteDraft(ctx context.Context, id uint32) error {
	return r.Client().VideoDraft.DeleteOneID(id).Exec(ctx)
}

// ── 上传任务 ──

func (r *VideoRepo) CreateUploadTask(ctx context.Context, taskID, fileName string, fileSize int64, chunkSize, totalChunks uint32, authorID uint32) (*ent.UploadTask, error) {
	return r.Client().UploadTask.Create().
		SetTaskID(taskID).
		SetFileName(fileName).
		SetFileSize(fileSize).
		SetChunkSize(chunkSize).
		SetTotalChunks(totalChunks).
		SetUploadedChunks([]uint32{}).
		SetStatus(uint8(videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_UPLOADING)).
		SetAuthorID(authorID).
		Save(ctx)
}

func (r *VideoRepo) GetUploadTask(ctx context.Context, taskID string) (*ent.UploadTask, error) {
	return r.Client().UploadTask.Query().Where(uploadtask.TaskID(taskID)).Only(ctx)
}

// AppendUploadChunk 记录已上传分片（幂等：重复分片忽略）
func (r *VideoRepo) AppendUploadChunk(ctx context.Context, taskID string, chunkIndex uint32) (*ent.UploadTask, error) {
	t, err := r.GetUploadTask(ctx, taskID)
	if err != nil {
		return nil, err
	}
	for _, idx := range t.UploadedChunks {
		if idx == chunkIndex {
			return t, nil
		}
	}
	chunks := append(t.UploadedChunks, chunkIndex)
	return r.Client().UploadTask.UpdateOneID(t.ID).
		SetUploadedChunks(chunks).
		Save(ctx)
}

func (r *VideoRepo) UpdateUploadTaskStatus(ctx context.Context, taskID string, status uint8, fileKey *string, videoID *uint32) (*ent.UploadTask, error) {
	t, err := r.GetUploadTask(ctx, taskID)
	if err != nil {
		return nil, err
	}
	u := r.Client().UploadTask.UpdateOneID(t.ID).SetStatus(status)
	if fileKey != nil {
		u.SetFileKey(*fileKey)
	}
	if videoID != nil {
		u.SetVideoID(*videoID)
	}
	return u.Save(ctx)
}

// SumLikeCountByAuthor 作者全部视频获赞求和
func (r *VideoRepo) SumLikeCountByAuthor(ctx context.Context, authorID uint32) (int64, error) {
	var sum int64
	if err := r.Client().Video.Query().Where(video.AuthorID(authorID)).Aggregate(ent.Sum(video.FieldLikeCount)).Scan(ctx, &sum); err != nil {
		return 0, err
	}
	return sum, nil
}

// ── Feed 召回查询 ──

// ListPublishedByAuthors 指定作者的已发布视频（关注召回），按发布时间倒序
func (r *VideoRepo) ListPublishedByAuthors(ctx context.Context, authorIDs []uint32, limit int) ([]*ent.Video, error) {
	if len(authorIDs) == 0 {
		return nil, nil
	}
	return r.Client().Video.Query().
		Where(video.Status(uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED)), video.AuthorIDIn(authorIDs...)).
		Order(ent.Desc(video.FieldPublishedAt)).
		Limit(limit).
		All(ctx)
}

// ListHot 热门召回：点赞加权排序（简单规则，无模型）
func (r *VideoRepo) ListHot(ctx context.Context, limit int) ([]*ent.Video, error) {
	return r.Client().Video.Query().
		Where(video.Status(uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED))).
		Order(ent.Desc(video.FieldLikeCount)).
		Order(ent.Desc(video.FieldViewCount)).
		Limit(limit).
		All(ctx)
}

// ListLatest 最新发布兜底召回
func (r *VideoRepo) ListLatest(ctx context.Context, limit int) ([]*ent.Video, error) {
	return r.Client().Video.Query().
		Where(video.Status(uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED))).
		Order(ent.Desc(video.FieldPublishedAt)).
		Limit(limit).
		All(ctx)
}

// ListPublishedByIDs 按 ID 集合取已发布视频（收藏列表 / 标签聚合 / 评论目标组装）
func (r *VideoRepo) ListPublishedByIDs(ctx context.Context, ids []uint32) ([]*ent.Video, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	return r.Client().Video.Query().
		Where(video.IDIn(ids...)).
		Order(ent.Desc(video.FieldID)).
		All(ctx)
}

// ListByAuthorAndStatuses 用户主页作品列表（本人含草稿/审核中，他人仅已发布）
func (r *VideoRepo) ListByAuthorAndStatuses(ctx context.Context, authorID uint32, statuses []uint8, offset, limit int) ([]*ent.Video, int, error) {
	q := r.Client().Video.Query().Where(video.AuthorID(authorID))
	if len(statuses) > 0 {
		q = q.Where(video.StatusIn(statuses...))
	}
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Desc(video.FieldID)).Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

// SearchByTitle 标题模糊搜索（已发布）
func (r *VideoRepo) SearchByTitle(ctx context.Context, keyword string, limit int) ([]*ent.Video, error) {
	return r.Client().Video.Query().
		Where(video.Status(uint8(videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED)), video.TitleContains(keyword)).
		Order(ent.Desc(video.FieldID)).
		Limit(limit).
		All(ctx)
}

// TagByName 按标签名取标签
func (r *VideoRepo) TagByName(ctx context.Context, name string) (*ent.VideoTag, error) {
	return r.Client().VideoTag.Query().Where(videotag.Name(name)).Only(ctx)
}

// VideoIDsByTag 标签下的视频ID集合
func (r *VideoRepo) VideoIDsByTag(ctx context.Context, tagID uint32, limit int) ([]uint32, error) {
	rels, err := r.Client().VideoTagRel.Query().Where(videotagrel.TagID(tagID)).Limit(limit).All(ctx)
	if err != nil {
		return nil, err
	}
	ids := make([]uint32, 0, len(rels))
	for _, rel := range rels {
		if rel.VideoID != nil {
			ids = append(ids, *rel.VideoID)
		}
	}
	return ids, nil
}

// IncViewCount 播放量自增（完播口径）
func (r *VideoRepo) IncViewCount(ctx context.Context, videoID uint32) error {
	_, err := r.Client().Video.UpdateOneID(videoID).AddViewCount(1).Save(ctx)
	return err
}
