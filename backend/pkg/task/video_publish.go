package task

// VideoScheduledPublishTaskType 定时发布任务：到期将 DRAFT（含 scheduled_at）转 PUBLISHED。
const VideoScheduledPublishTaskType = "video.scheduled.publish"

// VideoScheduledPublishData 定时发布载荷。
type VideoScheduledPublishData struct {
	VideoID uint32 `json:"videoId"`
}
