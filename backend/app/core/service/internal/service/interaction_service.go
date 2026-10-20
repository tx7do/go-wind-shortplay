package service

import (
	"context"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/go-utils/timeutil"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"

	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"

	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
)

type InteractionService struct {
	interactionV1.UnimplementedInteractionServiceServer

	log *log.Helper

	interRepo *data.InteractionRepo
	videoRepo *data.VideoRepo
	userRepo  data.UserRepo

	internalMessage InternalMessageNotifier
}

func NewInteractionService(
	ctx *bootstrap.Context,
	interRepo *data.InteractionRepo,
	videoRepo *data.VideoRepo,
	userRepo data.UserRepo,
) *InteractionService {
	return &InteractionService{
		log:       ctx.NewLoggerHelper("interaction/service/core-service"),
		interRepo: interRepo,
		videoRepo: videoRepo,
		userRepo:  userRepo,
	}
}

// Like 点赞（视频或评论）。幂等。
func (s *InteractionService) Like(ctx context.Context, req *interactionV1.LikeRequest) (*interactionV1.LikeResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	if req.GetTargetId() == 0 {
		return nil, interactionV1.ErrorBadRequest("invalid parameter")
	}

	var count int64
	switch req.GetTargetType() {
	case interactionV1.TargetType_TARGET_TYPE_COMMENT:
		_, err := s.interRepo.LikeCommentWithCounter(ctx, uid, req.GetTargetId())
		if err != nil {
			return nil, err
		}
		if n, cerr := s.interRepo.CountLikesOfTarget(ctx, req.GetTargetType(), req.GetTargetId()); cerr == nil {
			count = int64(n)
		}
	default:
		liked, _, err := s.interRepo.LikeVideoWithCounter(ctx, uid, req.GetTargetId())
		if err != nil {
			return nil, err
		}
		v, gerr := s.videoRepo.GetEntityRaw(ctx, req.GetTargetId())
		if gerr != nil {
			return nil, interactionV1.ErrorVideoNotFound("video not found")
		}
		count = int64(v.LikeCount)
		// 重复点赞幂等去重：仅新建点赞时通知作者
		if liked {
			s.notifyVideoLiked(ctx, uid, v)
		}
	}
	return &interactionV1.LikeResponse{
		Liked:     true,
		LikeCount: count,
	}, nil
}

// Unlike 取消点赞。幂等。
func (s *InteractionService) Unlike(ctx context.Context, req *interactionV1.LikeRequest) (*interactionV1.LikeResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}

	var count int64
	switch req.GetTargetType() {
	case interactionV1.TargetType_TARGET_TYPE_COMMENT:
		if _, err := s.interRepo.UnlikeCommentWithCounter(ctx, uid, req.GetTargetId()); err != nil {
			return nil, err
		}
		if n, cerr := s.interRepo.CountLikesOfTarget(ctx, req.GetTargetType(), req.GetTargetId()); cerr == nil {
			count = int64(n)
		}
	default:
		if _, err := s.interRepo.UnlikeVideoWithCounter(ctx, uid, req.GetTargetId()); err != nil {
			return nil, err
		}
		v, gerr := s.videoRepo.GetEntityRaw(ctx, req.GetTargetId())
		if gerr != nil {
			return nil, interactionV1.ErrorVideoNotFound("video not found")
		}
		count = int64(v.LikeCount)
	}
	return &interactionV1.LikeResponse{
		Liked:     false,
		LikeCount: count,
	}, nil
}

// Collect 收藏。幂等。
func (s *InteractionService) Collect(ctx context.Context, req *interactionV1.CollectRequest) (*interactionV1.CollectResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	if _, err := s.interRepo.CollectWithCounter(ctx, uid, req.GetVideoId()); err != nil {
		return nil, err
	}
	v, err := s.videoRepo.GetEntityRaw(ctx, req.GetVideoId())
	if err != nil {
		return nil, interactionV1.ErrorVideoNotFound("video not found")
	}
	return &interactionV1.CollectResponse{
		Collected:    true,
		CollectCount: int64(v.CollectCount),
	}, nil
}

// Uncollect 取消收藏。幂等。
func (s *InteractionService) Uncollect(ctx context.Context, req *interactionV1.CollectRequest) (*interactionV1.CollectResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	if _, err := s.interRepo.UncollectWithCounter(ctx, uid, req.GetVideoId()); err != nil {
		return nil, err
	}
	v, err := s.videoRepo.GetEntityRaw(ctx, req.GetVideoId())
	if err != nil {
		return nil, interactionV1.ErrorVideoNotFound("video not found")
	}
	return &interactionV1.CollectResponse{
		Collected:    false,
		CollectCount: int64(v.CollectCount),
	}, nil
}

// GetInteractionStatus 批量互动状态（游客全 false）
func (s *InteractionService) GetInteractionStatus(ctx context.Context, req *interactionV1.GetInteractionStatusRequest) (*interactionV1.GetInteractionStatusResponse, error) {
	uid := spViewerUserID(ctx)
	resp := &interactionV1.GetInteractionStatusResponse{
		Statuses: make(map[uint32]*interactionV1.InteractionStatus),
	}
	if uid == 0 || len(req.GetVideoIds()) == 0 {
		return resp, nil
	}
	liked, _ := s.interRepo.GetLikeStatus(ctx, uid, req.GetVideoIds())
	collected, _ := s.interRepo.GetCollectStatus(ctx, uid, req.GetVideoIds())
	for _, id := range req.GetVideoIds() {
		resp.Statuses[id] = &interactionV1.InteractionStatus{
			Liked:     liked[id],
			Collected: collected[id],
		}
	}
	return resp, nil
}

// ListCollectedVideos 我的收藏
func (s *InteractionService) ListCollectedVideos(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListVideoResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	page := req.GetPage()
	if page < 1 {
		page = 1
	}
	size := req.GetPageSize()
	if size <= 0 {
		size = 10
	}
	if size > 50 {
		size = 50
	}
	ids, total, err := s.interRepo.CollectedVideoIDs(ctx, uid, page, size)
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("list collects failed")
	}
	resp := &videoV1.ListVideoResponse{Total: trans.Ptr(int64(total))}
	videos, _ := s.videoRepo.ListCollectedByUser(ctx, ids)
	byID := make(map[uint32]*videoV1.Video, len(videos))
	for _, v := range videos {
		tags, _ := s.videoRepo.TagsOfVideo(ctx, v.ID)
		byID[v.ID] = spVideoToDTO(v, tags)
	}
	// 保持收藏时间倒序
	for _, id := range ids {
		if dto, ok := byID[id]; ok {
			resp.Items = append(resp.Items, dto)
		}
	}
	return resp, nil
}

// Follow 关注。幂等；不能关注自己。
func (s *InteractionService) Follow(ctx context.Context, req *interactionV1.FollowRequest) (*interactionV1.FollowResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	if req.GetUserId() == 0 {
		return nil, interactionV1.ErrorBadRequest("invalid parameter")
	}
	if req.GetUserId() == uid {
		return nil, interactionV1.ErrorCannotFollowSelf("cannot follow self")
	}
	created, err := s.interRepo.CreateFollow(ctx, uid, req.GetUserId())
	if err != nil {
		return nil, err
	}
	// 重复关注幂等去重：仅新建关注关系时通知
	if created {
		s.notifyFollowed(ctx, uid, req.GetUserId())
	}
	return &interactionV1.FollowResponse{Following: true}, nil
}

// Unfollow 取消关注。幂等。
func (s *InteractionService) Unfollow(ctx context.Context, req *interactionV1.FollowRequest) (*interactionV1.FollowResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	if _, err := s.interRepo.DeleteFollow(ctx, uid, req.GetUserId()); err != nil {
		return nil, err
	}
	return &interactionV1.FollowResponse{Following: false}, nil
}

// GetFollowStatus 批量关注状态
func (s *InteractionService) GetFollowStatus(ctx context.Context, req *interactionV1.GetFollowStatusRequest) (*interactionV1.GetFollowStatusResponse, error) {
	uid := spViewerUserID(ctx)
	resp := &interactionV1.GetFollowStatusResponse{Statuses: make(map[uint32]bool)}
	if uid == 0 || len(req.GetUserIds()) == 0 {
		return resp, nil
	}
	statuses, err := s.interRepo.GetFollowStatus(ctx, uid, req.GetUserIds())
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("get follow status failed")
	}
	resp.Statuses = statuses
	return resp, nil
}

// ListFollowing 我的关注
func (s *InteractionService) ListFollowing(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListFollowResponse, error) {
	return s.listFollowSide(ctx, req, true)
}

// ListFollowers 我的粉丝
func (s *InteractionService) ListFollowers(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListFollowResponse, error) {
	return s.listFollowSide(ctx, req, false)
}

func (s *InteractionService) listFollowSide(ctx context.Context, req *paginationV1.PagingRequest, following bool) (*interactionV1.ListFollowResponse, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	page := req.GetPage()
	if page < 1 {
		page = 1
	}
	size := req.GetPageSize()
	if size <= 0 {
		size = 10
	}
	if size > 50 {
		size = 50
	}

	var (
		rows  []*ent.UserFollow
		total int
		err   error
	)
	if following {
		rows, total, err = s.interRepo.ListFollowing(ctx, uid, page, size)
	} else {
		rows, total, err = s.interRepo.ListFollowers(ctx, uid, page, size)
	}
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("list follow failed")
	}

	resp := &interactionV1.ListFollowResponse{Total: trans.Ptr(int64(total))}
	for _, row := range rows {
		targetID := row.FolloweeID
		if !following {
			targetID = row.FollowerID
		}
		item := &interactionV1.FollowItem{FollowedAt: timeutil.TimeToTimestamppb(row.CreatedAt)}
		if u, uerr := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
			QueryBy: &identityV1.GetUserRequest_Id{Id: targetID},
		}); uerr == nil {
			item.User = toUserBriefSP(u)
		}
		resp.Items = append(resp.Items, item)
	}
	return resp, nil
}

// rowCreatedAtSP 时间指针转 Timestamp
func rowCreatedAtSP(t *time.Time) *timestamppb.Timestamp {
	return timeutil.TimeToTimestamppb(t)
}

// ── 视频评论 ──

type VideoCommentService struct {
	interactionV1.UnimplementedCommentServiceServer

	log *log.Helper

	commentRepo *data.VideoCommentRepo
	videoRepo   *data.VideoRepo
	userRepo    data.UserRepo
	sysConfRepo *data.SysConfRepo

	internalMessage InternalMessageNotifier
}

func NewVideoCommentService(
	ctx *bootstrap.Context,
	commentRepo *data.VideoCommentRepo,
	videoRepo *data.VideoRepo,
	userRepo data.UserRepo,
	sysConfRepo *data.SysConfRepo,
) *VideoCommentService {
	return &VideoCommentService{
		log:         ctx.NewLoggerHelper("video-comment/service/core-service"),
		commentRepo: commentRepo,
		videoRepo:   videoRepo,
		userRepo:    userRepo,
		sysConfRepo: sysConfRepo,
	}
}

// enrichCommentAuthors 批量补全评论人 UserBrief
func (s *VideoCommentService) enrichCommentAuthors(ctx context.Context, comments []*interactionV1.Comment) {
	if len(comments) == 0 {
		return
	}
	ids := make(map[uint32]struct{}, len(comments))
	for _, c := range comments {
		if c.GetUserId() > 0 {
			ids[c.GetUserId()] = struct{}{}
		}
	}
	users := make(map[uint32]*identityV1.UserBrief, len(ids))
	for id := range ids {
		if u, err := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
			QueryBy: &identityV1.GetUserRequest_Id{Id: id},
		}); err == nil && u != nil {
			users[id] = toUserBriefSP(u)
		}
	}
	for _, c := range comments {
		c.User = users[c.GetUserId()]
	}
}

// CreateComment 发表评论（评论行 + 视频评论计数 + 父评论回复数同事务）
func (s *VideoCommentService) CreateComment(ctx context.Context, req *interactionV1.CreateCommentRequest) (*interactionV1.Comment, error) {
	uid := spViewerUserID(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	if req.GetVideoId() == 0 || req.GetContent() == "" {
		return nil, interactionV1.ErrorBadRequest("invalid parameter")
	}
	v, verr := s.videoRepo.GetEntityRaw(ctx, req.GetVideoId())
	if verr != nil {
		return nil, interactionV1.ErrorVideoNotFound("video not found")
	}
	// 敏感词过滤：评论命中直接拒绝
	if spHitSensitiveWords(ctx, s.sysConfRepo, req.GetContent()) {
		return nil, interactionV1.ErrorSensitiveWordHit("comment rejected by content filter")
	}

	e, err := s.commentRepo.CreateWithCounter(ctx, uid, req.GetVideoId(), req.GetContent(), req.GetParentId())
	if err != nil {
		return nil, err
	}

	// 评论/回复通知（视频作者 + 楼中楼父评论作者，同人去重）
	var parentAuthorID uint32
	if req.GetParentId() > 0 {
		if parent, perr := s.commentRepo.Get(ctx, req.GetParentId()); perr == nil && parent != nil {
			parentAuthorID = parent.UserID
		}
	}
	s.notifyCommentCreated(ctx, uid, v.AuthorID, parentAuthorID, v.ID, v.Title, e.Content)
	dto := &interactionV1.Comment{
		Id:        trans.Ptr(e.ID),
		VideoId:   trans.Ptr(e.VideoID),
		UserId:    trans.Ptr(e.UserID),
		Content:   trans.Ptr(e.Content),
		ParentId:  trans.Ptr(e.ParentID),
		LikeCount: trans.Ptr(e.LikeCount),
		ReplyCount: trans.Ptr(e.ReplyCount),
		CreatedAt: rowCreatedAtSP(e.CreatedAt),
	}
	s.enrichCommentAuthors(ctx, []*interactionV1.Comment{dto})
	return dto, nil
}

// DeleteComment 删除评论（本人或管理端）
func (s *VideoCommentService) DeleteComment(ctx context.Context, req *interactionV1.DeleteCommentRequest) (*emptypb.Empty, error) {
	e, err := s.commentRepo.Get(ctx, req.GetId())
	if err != nil {
		return nil, err
	}
	uid := spViewerUserID(ctx)
	if !spIsAdminCaller(ctx) && e.UserID != uid {
		return nil, interactionV1.ErrorNotCommentOwner("not comment owner")
	}
	if err = s.commentRepo.DeleteWithCounter(ctx, e); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// ListComment 视频评论列表（游客可读）
func (s *VideoCommentService) ListComment(ctx context.Context, req *interactionV1.ListCommentRequest) (*interactionV1.ListCommentResponse, error) {
	if req.GetVideoId() == 0 {
		return nil, interactionV1.ErrorBadRequest("invalid parameter")
	}
	hotSort := req.GetSort() == interactionV1.CommentSort_COMMENT_SORT_HOT
	items, total, err := s.commentRepo.ListByVideo(ctx, req.GetVideoId(), nil, req.GetPageNum(), req.GetPageSize(), hotSort)
	if err != nil {
		return nil, err
	}
	resp := &interactionV1.ListCommentResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		resp.Items = append(resp.Items, &interactionV1.Comment{
			Id:        trans.Ptr(e.ID),
			VideoId:   trans.Ptr(e.VideoID),
			UserId:    trans.Ptr(e.UserID),
			Content:   trans.Ptr(e.Content),
			ParentId:  trans.Ptr(e.ParentID),
			LikeCount: trans.Ptr(e.LikeCount),
			ReplyCount: trans.Ptr(e.ReplyCount),
			CreatedAt: rowCreatedAtSP(e.CreatedAt),
		})
	}
	s.enrichCommentAuthors(ctx, resp.Items)
	return resp, nil
}

// ListReply 楼中楼回复列表
func (s *VideoCommentService) ListReply(ctx context.Context, req *interactionV1.ListReplyRequest) (*interactionV1.ListCommentResponse, error) {
	if req.GetCommentId() == 0 {
		return nil, interactionV1.ErrorBadRequest("invalid parameter")
	}
	items, total, err := s.commentRepo.ListReplies(ctx, req.GetCommentId(), req.GetPageNum(), req.GetPageSize())
	if err != nil {
		return nil, err
	}
	resp := &interactionV1.ListCommentResponse{Total: trans.Ptr(int64(total))}
	for _, e := range items {
		resp.Items = append(resp.Items, &interactionV1.Comment{
			Id:        trans.Ptr(e.ID),
			VideoId:   trans.Ptr(e.VideoID),
			UserId:    trans.Ptr(e.UserID),
			Content:   trans.Ptr(e.Content),
			ParentId:  trans.Ptr(e.ParentID),
			LikeCount: trans.Ptr(e.LikeCount),
			ReplyCount: trans.Ptr(e.ReplyCount),
			CreatedAt: rowCreatedAtSP(e.CreatedAt),
		})
	}
	s.enrichCommentAuthors(ctx, resp.Items)
	return resp, nil
}

// AdminList 管理端全量评论列表（admin BFF 转发入口）
func (s *VideoCommentService) AdminList(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListCommentResponse, error) {
	resp, err := s.commentRepo.ListAdmin(ctx, req)
	if err != nil {
		return nil, err
	}
	s.enrichCommentAuthors(ctx, resp.Items)
	return resp, nil
}
