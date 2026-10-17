package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"

	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	notifyV1 "go-wind-shortplay/api/gen/go/notify/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/pkg/authctx"
)

type InteractionService struct {
	interactionV1.UnimplementedInteractionServiceServer

	interRepo *data.InteractionRepo
	videoRepo *data.VideoRepo
	userRepo  *data.UserRepo
	notifyRepo *data.NotificationRepo
	log       *log.Helper
}

func NewInteractionService(ctx *bootstrap.Context, interRepo *data.InteractionRepo, videoRepo *data.VideoRepo, userRepo *data.UserRepo, notifyRepo *data.NotificationRepo) *InteractionService {
	return &InteractionService{
		interRepo:  interRepo,
		videoRepo:  videoRepo,
		userRepo:   userRepo,
		notifyRepo: notifyRepo,
		log:        ctx.NewLoggerHelper("interaction/service/core-service"),
	}
}

func (s *InteractionService) Like(ctx context.Context, req *interactionV1.LikeRequest) (*interactionV1.LikeResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	liked, count, err := s.interRepo.Like(ctx, uid, uint32(req.GetTargetType()), req.GetTargetId())
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("like failed")
	}
	if liked && req.GetTargetType() == interactionV1.TargetType_TARGET_TYPE_VIDEO {
		s.notifyVideoOwner(ctx, req.GetTargetId(), uid, notifyV1.NotifyType_NOTIFY_TYPE_LIKE, 0, "赞了你的视频")
	}
	return &interactionV1.LikeResponse{Liked: liked, LikeCount: count}, nil
}

func (s *InteractionService) Unlike(ctx context.Context, req *interactionV1.LikeRequest) (*interactionV1.LikeResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	liked, count, err := s.interRepo.Unlike(ctx, uid, uint32(req.GetTargetType()), req.GetTargetId())
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("unlike failed")
	}
	return &interactionV1.LikeResponse{Liked: liked, LikeCount: count}, nil
}

func (s *InteractionService) Collect(ctx context.Context, req *interactionV1.CollectRequest) (*interactionV1.CollectResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	collected, count, err := s.interRepo.Collect(ctx, uid, req.GetVideoId())
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("collect failed")
	}
	return &interactionV1.CollectResponse{Collected: collected, CollectCount: count}, nil
}

func (s *InteractionService) Uncollect(ctx context.Context, req *interactionV1.CollectRequest) (*interactionV1.CollectResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	collected, count, err := s.interRepo.Uncollect(ctx, uid, req.GetVideoId())
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("uncollect failed")
	}
	return &interactionV1.CollectResponse{Collected: collected, CollectCount: count}, nil
}

func (s *InteractionService) GetInteractionStatus(ctx context.Context, req *interactionV1.GetInteractionStatusRequest) (*interactionV1.GetInteractionStatusResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	liked, collected, err := s.interRepo.GetInteractionStatus(ctx, uid, req.GetVideoIds())
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("query status failed")
	}
	statuses := make(map[uint32]*interactionV1.InteractionStatus, len(req.GetVideoIds()))
	for _, id := range req.GetVideoIds() {
		statuses[id] = &interactionV1.InteractionStatus{
			Liked:     liked[id],
			Collected: collected[id],
		}
	}
	return &interactionV1.GetInteractionStatusResponse{Statuses: statuses}, nil
}

func (s *InteractionService) ListCollectedVideos(ctx context.Context, req *paginationV1.PagingRequest) (*videoV1.ListVideoResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	offset, limit := pageArgs(req.GetPage(), req.GetPageSize())
	ids, total, err := s.interRepo.CollectedVideoIDs(ctx, uid, offset, limit)
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("list collects failed")
	}
	videos, err := s.videoRepo.ListPublishedByIDs(ctx, ids)
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("list collects failed")
	}
	out := make([]*videoV1.Video, 0, len(videos))
	for _, v := range videos {
		out = append(out, toVideo(v, nil))
	}
	return &videoV1.ListVideoResponse{Items: out, Total: ptr(int64(total))}, nil
}

func (s *InteractionService) Follow(ctx context.Context, req *interactionV1.FollowRequest) (*interactionV1.FollowResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	if uid == req.GetUserId() {
		return nil, interactionV1.ErrorCannotFollowSelf("cannot follow yourself")
	}
	following, err := s.interRepo.Follow(ctx, uid, req.GetUserId())
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("follow failed")
	}
	if following {
		s.notifyUser(req.GetUserId(), uid, notifyV1.NotifyType_NOTIFY_TYPE_FOLLOW, 0, 0, "关注了你")
	}
	return &interactionV1.FollowResponse{Following: following}, nil
}

func (s *InteractionService) Unfollow(ctx context.Context, req *interactionV1.FollowRequest) (*interactionV1.FollowResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	following, err := s.interRepo.Unfollow(ctx, uid, req.GetUserId())
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("unfollow failed")
	}
	return &interactionV1.FollowResponse{Following: following}, nil
}

func (s *InteractionService) GetFollowStatus(ctx context.Context, req *interactionV1.GetFollowStatusRequest) (*interactionV1.GetFollowStatusResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	statuses, err := s.interRepo.GetFollowStatus(ctx, uid, req.GetUserIds())
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("query follow status failed")
	}
	return &interactionV1.GetFollowStatusResponse{Statuses: statuses}, nil
}

func (s *InteractionService) ListFollowing(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListFollowResponse, error) {
	return s.listFollow(ctx, req, false)
}

func (s *InteractionService) ListFollowers(ctx context.Context, req *paginationV1.PagingRequest) (*interactionV1.ListFollowResponse, error) {
	return s.listFollow(ctx, req, true)
}

func (s *InteractionService) listFollow(ctx context.Context, req *paginationV1.PagingRequest, byFollowee bool) (*interactionV1.ListFollowResponse, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	offset, limit := pageArgs(req.GetPage(), req.GetPageSize())
	items, total, err := s.interRepo.FollowList(ctx, uid, byFollowee, offset, limit)
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("list follow failed")
	}

	// 组装用户简报
	userIDs := make([]uint32, 0, len(items))
	for _, it := range items {
		if byFollowee {
			if it.FollowerID != nil {
				userIDs = append(userIDs, *it.FollowerID)
			}
		} else {
			if it.FolloweeID != nil {
				userIDs = append(userIDs, *it.FolloweeID)
			}
		}
	}
	users := s.loadUsers(ctx, userIDs)

	out := make([]*interactionV1.FollowItem, 0, len(items))
	for _, it := range items {
		var targetID uint32
		if byFollowee {
			if it.FollowerID != nil {
				targetID = *it.FollowerID
			}
		} else {
			if it.FolloweeID != nil {
				targetID = *it.FolloweeID
			}
		}
		out = append(out, &interactionV1.FollowItem{
			User:       toUserBrief(users[targetID]),
			FollowedAt: tsPtr(it.CreatedAt),
		})
	}
	return &interactionV1.ListFollowResponse{Items: out, Total: ptr(int64(total))}, nil
}

// loadUsers 批量取用户（小集合循环查询，量大后改 IN 查询）
func (s *InteractionService) loadUsers(ctx context.Context, ids []uint32) map[uint32]*ent.User {
	res := make(map[uint32]*ent.User, len(ids))
	for _, id := range ids {
		if _, ok := res[id]; ok {
			continue
		}
		if u, err := s.userRepo.GetByID(ctx, id); err == nil {
			res[id] = u
		}
	}
	return res
}

// notifyVideoOwner 视频作者通知（去重：不给自己发）
func (s *InteractionService) notifyVideoOwner(ctx context.Context, videoID, senderID uint32, typ notifyV1.NotifyType, commentID uint32, content string) {
	v, err := s.videoRepo.GetByID(ctx, videoID)
	if err != nil || v.AuthorID == nil || *v.AuthorID == senderID || *v.AuthorID == 0 {
		return
	}
	s.notifyUser(*v.AuthorID, senderID, typ, videoID, commentID, content)
}

func (s *InteractionService) notifyUser(userID, senderID uint32, typ notifyV1.NotifyType, videoID, commentID uint32, content string) {
	if err := s.notifyRepo.Create(context.Background(), userID, uint8(typ), senderID, videoID, commentID, content); err != nil {
		s.log.Warnf("create notification failed: %s", err.Error())
	}
}

// ── CommentService ──

type CommentService struct {
	interactionV1.UnimplementedCommentServiceServer

	commentRepo *data.CommentRepo
	userRepo    *data.UserRepo
	notifyRepo  *data.NotificationRepo
	videoRepo   *data.VideoRepo
	log         *log.Helper
}

func NewCommentService(ctx *bootstrap.Context, commentRepo *data.CommentRepo, userRepo *data.UserRepo, notifyRepo *data.NotificationRepo, videoRepo *data.VideoRepo) *CommentService {
	return &CommentService{
		commentRepo: commentRepo,
		userRepo:    userRepo,
		notifyRepo:  notifyRepo,
		videoRepo:   videoRepo,
		log:         ctx.NewLoggerHelper("comment/service/core-service"),
	}
}

func (s *CommentService) CreateComment(ctx context.Context, req *interactionV1.CreateCommentRequest) (*interactionV1.Comment, error) {
	uid := authctx.UserIDFromContext(ctx)
	if uid == 0 {
		return nil, interactionV1.ErrorUnauthorized("login required")
	}
	if req.GetContent() == "" {
		return nil, interactionV1.ErrorBadRequest("content required")
	}
	c, err := s.commentRepo.Create(ctx, req.GetVideoId(), uid, req.GetContent(), req.GetParentId())
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("create comment failed")
	}
	_ = s.commentRepo.IncVideoCommentCount(ctx, req.GetVideoId(), 1)
	if req.GetParentId() > 0 {
		_ = s.commentRepo.IncReplyCount(ctx, req.GetParentId(), 1)
	}

	// 通知视频作者（不给自己发）
	if v, verr := s.videoRepo.GetByID(ctx, req.GetVideoId()); verr == nil && v.AuthorID != nil && *v.AuthorID != uid && *v.AuthorID > 0 {
		if nerr := s.notifyRepo.Create(ctx, *v.AuthorID, uint8(notifyV1.NotifyType_NOTIFY_TYPE_COMMENT), uid, req.GetVideoId(), c.ID, "评论了你的视频"); nerr != nil {
			s.log.Warnf("create comment notification failed: %s", nerr.Error())
		}
	}

	u, _ := s.userRepo.GetByID(ctx, uid)
	return toComment(c, toUserBrief(u)), nil
}

// DeleteComment 删除评论：本人可删；管理端经 metadata 标记放行（admin 网关注入）
func (s *CommentService) DeleteComment(ctx context.Context, req *interactionV1.DeleteCommentRequest) (*emptypb.Empty, error) {
	c, err := s.commentRepo.GetByID(ctx, req.GetId())
	if err != nil {
		return nil, interactionV1.ErrorCommentNotFound("comment not found")
	}
	uid := authctx.UserIDFromContext(ctx)
	isAdmin := authctx.IsAdminCaller(ctx)
	if !isAdmin && (uid == 0 || c.UserID == nil || *c.UserID != uid) {
		return nil, interactionV1.ErrorNotCommentOwner("not comment owner")
	}
	if err := s.commentRepo.Delete(ctx, req.GetId()); err != nil {
		return nil, interactionV1.ErrorInternalServerError("delete comment failed")
	}
	if c.VideoID != nil {
		_ = s.commentRepo.IncVideoCommentCount(ctx, *c.VideoID, -1)
	}
	return &emptypb.Empty{}, nil
}

func (s *CommentService) ListComment(ctx context.Context, req *interactionV1.ListCommentRequest) (*interactionV1.ListCommentResponse, error) {
	offset, limit := pageArgs(req.GetPageNum(), req.GetPageSize())
	// video_id=0 视为全量查询（管理端复用）
	items, total, err := s.commentRepo.ListAll(ctx, req.GetVideoId(), offset, limit)
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("list comments failed")
	}
	out := make([]*interactionV1.Comment, 0, len(items))
	for _, it := range items {
		var u *ent.User
		if it.UserID != nil {
			u, _ = s.userRepo.GetByID(ctx, *it.UserID)
		}
		out = append(out, toComment(it, toUserBrief(u)))
	}
	return &interactionV1.ListCommentResponse{Items: out, Total: ptr(int64(total))}, nil
}

// ListReply 评论的回复列表（楼中楼）
func (s *CommentService) ListReply(ctx context.Context, req *interactionV1.ListReplyRequest) (*interactionV1.ListCommentResponse, error) {
	offset, limit := pageArgs(req.GetPageNum(), req.GetPageSize())
	items, total, err := s.commentRepo.ListReplies(ctx, req.GetCommentId(), offset, limit)
	if err != nil {
		return nil, interactionV1.ErrorInternalServerError("list replies failed")
	}
	out := make([]*interactionV1.Comment, 0, len(items))
	for _, it := range items {
		var u *ent.User
		if it.UserID != nil {
			u, _ = s.userRepo.GetByID(ctx, *it.UserID)
		}
		out = append(out, toComment(it, toUserBrief(u)))
	}
	return &interactionV1.ListCommentResponse{Items: out, Total: ptr(int64(total))}, nil
}

// ListAllComments 管理端全量评论列表（AdminCommentService 调用）
func (s *CommentService) ListAllComments(ctx context.Context, videoID uint32, offset, limit int) ([]*interactionV1.Comment, int64, error) {
	items, total, err := s.commentRepo.ListAll(ctx, videoID, offset, limit)
	if err != nil {
		return nil, 0, err
	}
	out := make([]*interactionV1.Comment, 0, len(items))
	for _, it := range items {
		var u *ent.User
		if it.UserID != nil {
			u, _ = s.userRepo.GetByID(ctx, *it.UserID)
		}
		out = append(out, toComment(it, toUserBrief(u)))
	}
	return out, int64(total), nil
}
