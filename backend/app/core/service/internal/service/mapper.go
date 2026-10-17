package service

import (
	"time"

	"google.golang.org/protobuf/types/known/timestamppb"

	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	notifyV1 "go-wind-shortplay/api/gen/go/notify/service/v1"
	reportV1 "go-wind-shortplay/api/gen/go/report/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
	"go-wind-shortplay/app/core/service/internal/data/ent"
)

// ── 小工具 ──

func ptr[T any](v T) *T { return &v }

func tsPtr(t *time.Time) *timestamppb.Timestamp {
	if t == nil || t.IsZero() {
		return nil
	}
	return timestamppb.New(*t)
}

// ── identity ──

func toUser(e *ent.User) *identityV1.User {
	if e == nil {
		return nil
	}
	return &identityV1.User{
		Id:       ptr(e.ID),
		Username: ptr(e.Username),
		Nickname: ptr(e.Nickname),
		AvatarUrl: func() *string {
			if e.AvatarURL != nil {
				return e.AvatarURL
			}
			return nil
		}(),
		Bio:       e.Bio,
		Status: func() *identityV1.UserStatus {
			if e.Status != nil {
				st := identityV1.UserStatus(*e.Status)
				return &st
			}
			return nil
		}(),
		CreatedAt: tsPtr(e.CreatedAt),
		UpdatedAt: tsPtr(e.UpdatedAt),
	}
}

func toUserBrief(e *ent.User) *identityV1.UserBrief {
	if e == nil {
		return nil
	}
	return &identityV1.UserBrief{
		Id:        ptr(e.ID),
		Nickname:  ptr(e.Nickname),
		AvatarUrl: e.AvatarURL,
	}
}

// ── video ──

func videoStatusPtr(s *uint8) *videoV1.VideoStatus {
	if s == nil {
		return nil
	}
	v := videoV1.VideoStatus(*s)
	return &v
}

func toVideo(e *ent.Video, tags []string) *videoV1.Video {
	if e == nil {
		return nil
	}
	v := &videoV1.Video{
		Id:          ptr(e.ID),
		Title:       ptr(e.Title),
		Description: e.Description,
		CoverUrl:    e.CoverURL,
		VideoUrl:    ptr(e.VideoURL),
		Duration:    e.Duration,
		Width:       e.Width,
		Height:      e.Height,
		Status:      videoStatusPtr(e.Status),
		AuthorId:    e.AuthorID,
		Tags:        tags,
		RejectReason: e.RejectReason,
		PublishedAt: tsPtr(e.PublishedAt),
		CreatedAt:   tsPtr(e.CreatedAt),
		UpdatedAt:   tsPtr(e.UpdatedAt),
	}
	if e.LikeCount != nil {
		v.LikeCount = ptr(uint64(*e.LikeCount))
	}
	if e.CollectCount != nil {
		v.CollectCount = ptr(uint64(*e.CollectCount))
	}
	if e.CommentCount != nil {
		v.CommentCount = ptr(uint64(*e.CommentCount))
	}
	if e.ViewCount != nil {
		v.ViewCount = ptr(uint64(*e.ViewCount))
	}
	return v
}

func toVideoDraft(e *ent.VideoDraft) *videoV1.VideoDraft {
	if e == nil {
		return nil
	}
	return &videoV1.VideoDraft{
		Id:           ptr(e.ID),
		Title:        e.Title,
		Description:  e.Description,
		CoverUrl:     e.CoverURL,
		VideoUrl:     e.VideoURL,
		Duration:     e.Duration,
		Width:        e.Width,
		Height:       e.Height,
		UploadTaskId: e.UploadTaskID,
		AuthorId:     e.AuthorID,
		CreatedAt:    tsPtr(e.CreatedAt),
		UpdatedAt:    tsPtr(e.UpdatedAt),
	}
}

func toUploadTask(e *ent.UploadTask) *videoV1.UploadTask {
	if e == nil {
		return nil
	}
	status := videoV1.UploadTaskStatus_UPLOAD_TASK_STATUS_UNSPECIFIED
	if e.Status != nil {
		status = videoV1.UploadTaskStatus(*e.Status)
	}
	return &videoV1.UploadTask{
		TaskId:         ptr(e.TaskID),
		FileName:       ptr(e.FileName),
		FileSize: func() *uint64 {
			if e.FileSize != nil {
				return ptr(uint64(*e.FileSize))
			}
			return nil
		}(),
		ChunkSize:      e.ChunkSize,
		TotalChunks:    e.TotalChunks,
		UploadedChunks: e.UploadedChunks,
		Status:         ptr(status),
		FileKey:        e.FileKey,
		VideoId:        e.VideoID,
		CreatedAt:      tsPtr(e.CreatedAt),
	}
}

func toTag(e *ent.VideoTag) *videoV1.Tag {
	if e == nil {
		return nil
	}
	t := &videoV1.Tag{
		Id:   ptr(e.ID),
		Name: ptr(e.Name),
	}
	if e.VideoCount != nil {
		t.VideoCount = ptr(uint64(*e.VideoCount))
	}
	return t
}

// ── interaction ──

func toComment(e *ent.VideoComment, user *identityV1.UserBrief) *interactionV1.Comment {
	if e == nil {
		return nil
	}
	c := &interactionV1.Comment{
		Id:        ptr(e.ID),
		VideoId:   e.VideoID,
		UserId:    e.UserID,
		User:      user,
		Content:   ptr(e.Content),
		ParentId:  e.ParentID,
		CreatedAt: tsPtr(e.CreatedAt),
	}
	if e.LikeCount != nil {
		c.LikeCount = ptr(uint64(*e.LikeCount))
	}
	if e.ReplyCount != nil {
		c.ReplyCount = ptr(uint64(*e.ReplyCount))
	}
	return c
}

// ── report ──

func toReport(e *ent.VideoReport, reporter *identityV1.UserBrief) *reportV1.Report {
	if e == nil {
		return nil
	}
	status := reportV1.ReportStatus_REPORT_STATUS_UNSPECIFIED
	if e.Status != nil {
		status = reportV1.ReportStatus(*e.Status)
	}
	targetType := reportV1.ReportTargetType_REPORT_TARGET_TYPE_UNSPECIFIED
	if e.TargetType != nil {
		targetType = reportV1.ReportTargetType(*e.TargetType)
	}
	return &reportV1.Report{
		Id:          ptr(e.ID),
		ReporterId:  e.ReporterID,
		Reporter:    reporter,
		TargetType:  ptr(targetType),
		TargetId:    e.TargetID,
		Reason:      ptr(e.Reason),
		Description: e.Description,
		Status:      ptr(status),
		HandledBy:   e.HandledBy,
		HandleNote:  e.HandleNote,
		HandledAt:   tsPtr(e.HandledAt),
		CreatedAt:   tsPtr(e.CreatedAt),
	}
}

// ── notify ──

func toNotification(e *ent.Notification, sender *identityV1.UserBrief) *notifyV1.Notification {
	if e == nil {
		return nil
	}
	typ := notifyV1.NotifyType_NOTIFY_TYPE_UNSPECIFIED
	if e.Type != nil {
		typ = notifyV1.NotifyType(*e.Type)
	}
	return &notifyV1.Notification{
		Id:        ptr(e.ID),
		Type:      ptr(typ),
		Sender:    sender,
		VideoId:   e.VideoID,
		CommentId: e.CommentID,
		Content:   e.Content,
		IsRead:    func() *bool { if e.IsRead != nil { return e.IsRead }; return nil }(),
		CreatedAt: tsPtr(e.CreatedAt),
	}
}
