package task

// VideoScheduledPublishTaskType 定时发布任务：到期将 DRAFT（含 scheduled_at）转 PUBLISHED。
const VideoScheduledPublishTaskType = "video.scheduled.publish"

// VideoScheduledPublishData 定时发布载荷。
type VideoScheduledPublishData struct {
	VideoID int64 `json:"videoId"`
}

// VideoScheduledUnpublishTaskType 定时下架任务：到期将 PUBLISHED（含
// scheduled_off_at）转 OFFLINE（reason=定时下架）。
const VideoScheduledUnpublishTaskType = "video.scheduled.unpublish"

// VideoScheduledUnpublishData 定时下架载荷。
type VideoScheduledUnpublishData struct {
	VideoID int64 `json:"videoId"`
}
