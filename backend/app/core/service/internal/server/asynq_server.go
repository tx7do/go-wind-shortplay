package server

import (
	"github.com/go-kratos/kratos/v2/log"

	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/tx7do/kratos-transport/transport/asynq"

	"go-wind-shortplay/app/core/service/internal/service"

	appViewer "go-wind-shortplay/pkg/entgo/viewer"
	"go-wind-shortplay/pkg/task"
)

// NewAsynqServer creates a new asynq server.
func NewAsynqServer(ctx *bootstrap.Context, taskService *service.TaskService, internalMessageService *service.InternalMessageService, notificationService *service.NotificationService, videoService *service.VideoService) *asynq.Server {
	cfg := ctx.GetConfig()

	if cfg == nil || cfg.Server == nil || cfg.Server.Asynq == nil {
		return nil
	}

	srv := asynq.NewServer(
		asynq.WithCodec(cfg.Server.Asynq.GetCodec()),
		asynq.WithRedisURI(cfg.Server.Asynq.GetUri()),
		asynq.WithLocation(cfg.Server.Asynq.GetLocation()),
		asynq.WithGracefullyShutdown(cfg.Server.Asynq.GetEnableGracefullyShutdown()),
		asynq.WithShutdownTimeout(cfg.Server.Asynq.GetShutdownTimeout().AsDuration()),
	)

	taskService.RegisterTaskScheduler(srv)

	var err error

	// 注册任务
	if err = asynq.RegisterSubscriber(srv, task.BackupTaskType, taskService.AsyncBackup); err != nil {
		log.Error(err)
	}

	// 注册邮件通知投递任务：系统通知的附加邮件触达（SMTP 未配置时 worker 内跳过）。
	if err = asynq.RegisterSubscriber(srv, task.NotifyEmailTaskType, internalMessageService.SendEmailWorker); err != nil {
		log.Error(err)
	}

	// 通知域异步派发：规则行标 is_async 的事件由该任务投递。带 ctx 版注册——
	// asynq 的截止时间要透传进 mailer 的 DialContext 才能真掐断 SMTP 握手。
	notificationService.RegisterTaskEnqueuer(taskService)
	if err = asynq.RegisterSubscriberWithCtx(srv, task.NotificationDispatchTaskType, notificationService.AsyncNotificationDispatch); err != nil {
		log.Error(err)
	}

	// 通知台账清扫（每 5 分钟）：超期停留在 SENDING 的行定案 FAILED（只定案不补投）。
	// 系统级常驻任务，不进 sys_tasks（任务管理页不可见不可停）。
	if err = asynq.RegisterSubscriber(srv, task.NotificationDeliverySweepTaskType, notificationService.AsyncDeliverySweep); err != nil {
		log.Error(err)
	}
	if _, err = srv.NewPeriodicTask(task.NotificationDeliverySweepCronSpec, task.NotificationDeliverySweepTaskType, &task.NotificationDeliverySweepTaskData{}); err != nil {
		log.Error(err)
	}

	// shortplay 视频封面抽帧（FFmpeg 不可用/失败时 worker 内静默降级，不入队重试）
	if err = asynq.RegisterSubscriber(srv, task.VideoCoverExtractTaskType, videoService.AsyncCoverExtract); err != nil {
		log.Error(err)
	}

	// 启动所有的任务
	_, _ = taskService.StartAllTask(appViewer.NewSystemViewerContext(ctx.Context()), nil)

	return srv
}
