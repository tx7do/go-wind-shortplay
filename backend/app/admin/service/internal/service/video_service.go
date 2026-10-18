package service

import (
	"context"
	"encoding/json"
	"strconv"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	adminV1 "go-wind-shortplay/api/gen/go/admin/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// VideoService 视频管理服务（admin BFF 薄转发）。
// React 前端的 query（关键字）/filter（状态数字串）/authorId 直传，
// 这里翻译成 go-crud 过滤 JSON 再转发 core。
type VideoService struct {
	adminV1.VideoServiceHTTPServer

	videoClient videoV1.VideoServiceClient
	log         *log.Helper
}

func NewVideoService(
	ctx *bootstrap.Context,
	videoClient videoV1.VideoServiceClient,
) *VideoService {
	return &VideoService{
		log:         ctx.NewLoggerHelper("video/service/admin-service"),
		videoClient: videoClient,
	}
}

// spVideoStatusFilterValue 状态数字串 → ent 枚举名（1草稿/2审核中/3已发布/4驳回/5下架）
func spVideoStatusFilterValue(filter string) string {
	switch filter {
	case "1":
		return "DRAFT"
	case "2":
		return "REVIEWING"
	case "3":
		return "PUBLISHED"
	case "4":
		return "REJECTED"
	case "5":
		return "OFFLINE"
	default:
		return ""
	}
}

// translateVideoListParams 翻译列表参数为 query JSON
func translateVideoListParams(req *paginationV1.PagingRequest) {
	if req == nil {
		return
	}
	// 原始 query 参数（非 JSON）视为标题关键字；JSON 则原样透传
	raw := req.GetQuery()
	filter := req.GetFilter()
	if raw != "" && !json.Valid([]byte(raw)) {
		q := map[string]any{"title___icontains": raw}
		if sv := spVideoStatusFilterValue(filter); sv != "" {
			q["status"] = sv
		}
		if b, err := json.Marshal(q); err == nil {
			setPagingQuerySP(req, string(b))
		}
		return
	}
	if raw == "" && filter != "" {
		if sv := spVideoStatusFilterValue(filter); sv != "" {
			if b, err := json.Marshal(map[string]any{"status": sv}); err == nil {
				setPagingQuerySP(req, string(b))
			}
		}
	}
}

// setPagingQuerySP 设置 PagingRequest 过滤 JSON（oneof 字段经 FilteringType 赋值）
func setPagingQuerySP(req *paginationV1.PagingRequest, query string) {
	if req == nil {
		return
	}
	req.FilteringType = &paginationV1.PagingRequest_Query{Query: query}
}

// spQueryAuthorID 从原始 HTTP 查询串解析 authorId（生成层不识别的业务参数）
func spQueryAuthorID(ctx context.Context) uint32 {
	r, ok := khttp.RequestFromServerContext(ctx)
	if !ok || r == nil {
		return 0
	}
	if v := r.URL.Query().Get("authorId"); v != "" {
		if id, err := strconv.ParseUint(v, 10, 32); err == nil {
			return uint32(id)
		}
	}
	return 0
}

func (s *VideoService) List(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListVideoResponse, error) {
	translateVideoListParams(req)
	// authorId 过滤（用户管理「查看作品」）
	if authorID := spQueryAuthorID(ctx); authorID > 0 {
		obj := map[string]any{"author_id": authorID}
		if req.GetQuery() != "" {
			var m map[string]any
			if json.Unmarshal([]byte(req.GetQuery()), &m) == nil && m != nil {
				m["author_id"] = authorID
				obj = m
			}
		}
		if b, err := json.Marshal(obj); err == nil {
			setPagingQuerySP(req, string(b))
		}
	}
	return s.videoClient.ListVideo(ctx, req)
}

func (s *VideoService) Get(ctx context.Context, req *videoV1.GetVideoRequest) (*videoV1.Video, error) {
	return s.videoClient.GetVideo(ctx, req)
}

// Update 编辑视频（标题 / 简介 / 封面 / 标签）：
// core UpdateVideo 内部按管理端 viewer 放行（spIsAdminCaller），BFF 只做转发。
func (s *VideoService) Update(ctx context.Context, req *videoV1.UpdateVideoRequest) (*videoV1.Video, error) {
	return s.videoClient.UpdateVideo(ctx, req)
}

func (s *VideoService) ChangeStatus(ctx context.Context, req *videoV1.ChangeVideoStatusRequest) (*videoV1.Video, error) {
	return s.videoClient.ChangeVideoStatus(ctx, req)
}

func (s *VideoService) Delete(ctx context.Context, req *videoV1.DeleteVideoRequest) (*emptypb.Empty, error) {
	return s.videoClient.DeleteVideo(ctx, req)
}
