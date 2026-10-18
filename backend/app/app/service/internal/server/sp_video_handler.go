package server

import (
	"io"
	"strconv"

	"github.com/go-kratos/kratos/v2/transport/http"

	appV1 "go-wind-shortplay/api/gen/go/app/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"

	"go-wind-shortplay/app/app/service/internal/service"
)

// chunkMaxBytes 单分片上限（8MB，缺省分片 4MB 留裕量）
const chunkMaxBytes = 8 * 1024 * 1024

// registerSpVideoServiceHandler 视频创作服务路由：
// 非 generated 全量注册——只挂分片字节路由 PUT /app/v1/uploads/{task_id}/chunks/{chunk_index}
// （raw octet-stream body），其余路由由生成代码注册（见 rest_server）。
func registerSpVideoServiceHandler(srv *http.Server, svc *service.VideoService) {
	srv.Route("/").PUT("/app/v1/uploads/{task_id}/chunks/{chunk_index}", func(ctx http.Context) error {
		http.SetOperation(ctx, appV1.OperationVideoServiceUploadChunk)

		taskID := ctx.Vars().Get("task_id")
		chunkIndex64, err := strconv.ParseUint(ctx.Vars().Get("chunk_index"), 10, 32)
		if err != nil || taskID == "" {
			return videoV1.ErrorBadRequest("invalid upload chunk path")
		}

		data, err := io.ReadAll(io.LimitReader(ctx.Request().Body, chunkMaxBytes+1))
		if err != nil || len(data) == 0 {
			return videoV1.ErrorBadRequest("empty chunk body")
		}
		if int64(len(data)) > chunkMaxBytes {
			return videoV1.ErrorPayloadTooLarge("chunk exceeds limit")
		}

		out, err := svc.UploadChunk(ctx, &appV1.UploadChunkRequest{
			TaskId:     taskID,
			ChunkIndex: uint32(chunkIndex64),
			Data:       data,
		})
		if err != nil {
			return err
		}
		return ctx.Result(200, out)
	})
}
