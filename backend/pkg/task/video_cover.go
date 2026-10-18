package task

// shortplay 视频域 asynq 任务类型常量与载荷。
//
// 命名约束：任务类型互不为前缀（与通知域同一条铁律，见 notification.go）。

// VideoCoverExtractTaskType 封面抽帧任务：上传合并完成后从视频对象抽单帧封面。
// FFmpeg 不可用或抽帧失败时静默降级（发布不阻塞，封面留空）。
const VideoCoverExtractTaskType = "video.cover.extract"

// VideoCoverExtractTaskData 封面抽帧载荷。
type VideoCoverExtractTaskData struct {
	TaskID  string `json:"taskId"`            // 上传任务号
	Bucket  string `json:"bucket"`            // 视频对象所在桶
	Object  string `json:"object"`            // 视频对象键
	VideoID uint32 `json:"videoId,omitempty"` // 关联视频ID（直接发布时回填封面）
}
