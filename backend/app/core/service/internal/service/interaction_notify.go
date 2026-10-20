package service

import (
	"context"
	"strconv"
	"strings"

	"github.com/go-kratos/kratos/v2/log"

	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"

	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"
)

// 互动事件站内信通知（C 端收件箱）：点赞/关注/评论/审核结果。
// 复用基座 internal_message 投递缝（SendSystemNotification，经 fan-out 落收件行
// 与 Redis Pub/Sub 实时推送），发送为尽力而为——失败仅记日志，不回滚主流程。
// 跳转标记沿用 sp-biz 尾行约定（App 端解析 videoId 直达；关注类无跳转不加标记）。

// spNicknameOf 取用户昵称（失败回退 "有人"，通知文案兜底）。
func spNicknameOf(ctx context.Context, userRepo data.UserRepo, userID uint32) string {
	if userRepo == nil || userID == 0 {
		return "有人"
	}
	u, err := userRepo.Get(ctx, &identityV1.GetUserRequest{
		QueryBy: &identityV1.GetUserRequest_Id{Id: userID},
	})
	if err != nil || u == nil {
		return "有人"
	}
	if n := strings.TrimSpace(u.GetNickname()); n != "" {
		return n
	}
	return u.GetUsername()
}

// spSendUserNotice 尽力而为发送站内信（系统/事件口径，零值目标忽略；
// 互动事件的"自己不通知自己"由调用方在钩子处过滤）。
func spSendUserNotice(ctx context.Context, n InternalMessageNotifier, lh *log.Helper, title, content string, targetID uint32) {
	if n == nil || targetID == 0 {
		return
	}
	if _, err := n.SendSystemNotification(ctx, title, content, []uint32{targetID}); err != nil {
		if lh != nil {
			lh.Errorf("send %q notification to %d failed: %s", title, targetID, err.Error())
		}
	}
}

// spVideoBizMarker 视频跳转标记（约定见 report_service.go 的 spBizMarkerPrefix）。
func spVideoBizMarker(videoID uint32) string {
	return spBizMarkerPrefix + `{"videoId":` + strconv.FormatUint(uint64(videoID), 10) + `}`
}

// ── 注入缝：三个服务共用基座 InternalMessageService ──

// RegisterNotifier 注入站内信通知能力（interaction 服务：点赞/关注）。
func (s *InteractionService) RegisterNotifier(n InternalMessageNotifier) {
	s.internalMessage = n
}

// RegisterNotifier 注入站内信通知能力（评论服务：评论/回复）。
func (s *VideoCommentService) RegisterNotifier(n InternalMessageNotifier) {
	s.internalMessage = n
}

// RegisterNotifier 注入站内信通知能力（视频服务：审核结果）。
func (s *VideoService) RegisterNotifier(n InternalMessageNotifier) {
	s.internalMessage = n
}

// ── 事件钩子（在各写操作成功后调用）──

// notifyVideoLiked 视频被赞通知作者（actor=点赞人）。
func (s *InteractionService) notifyVideoLiked(ctx context.Context, actorID uint32, v *ent.Video) {
	if s.internalMessage == nil || v == nil || v.AuthorID == 0 || v.AuthorID == actorID {
		return
	}
	nickname := spNicknameOf(ctx, s.userRepo, actorID)
	body := nickname + " 赞了你的视频《" + v.Title + "》" + spVideoBizMarker(v.ID)
	spSendUserNotice(ctx, s.internalMessage, s.log, "收到新的赞", body, v.AuthorID)
}

// notifyFollowed 新关注通知被关注人（CreateFollow 仅在新建关系时返回 true）。
func (s *InteractionService) notifyFollowed(ctx context.Context, actorID, followeeID uint32) {
	if s.internalMessage == nil || followeeID == 0 || followeeID == actorID {
		return
	}
	nickname := spNicknameOf(ctx, s.userRepo, actorID)
	spSendUserNotice(ctx, s.internalMessage, s.log, "新增关注", nickname+" 关注了你", followeeID)
}

// notifyCommentCreated 评论/回复通知：视频作者 + 楼中楼父评论作者（同人去重、跳视频）。
func (s *VideoCommentService) notifyCommentCreated(ctx context.Context, actorID, videoAuthorID, parentAuthorID, videoID uint32, videoTitle, content string) {
	if s.internalMessage == nil {
		return
	}
	nickname := spNicknameOf(ctx, s.userRepo, actorID)
	if videoAuthorID > 0 && videoAuthorID != actorID {
		body := nickname + " 评论了你的视频《" + videoTitle + "》：" + content + spVideoBizMarker(videoID)
		spSendUserNotice(ctx, s.internalMessage, s.log, "收到新的评论", body, videoAuthorID)
	}
	if parentAuthorID > 0 && parentAuthorID != videoAuthorID && parentAuthorID != actorID {
		body := nickname + " 回复了你的评论：" + content + spVideoBizMarker(videoID)
		spSendUserNotice(ctx, s.internalMessage, s.log, "收到新的回复", body, parentAuthorID)
	}
}

// notifyVideoReviewed 审核结果通知作者（系统口径，无 actor）。
func (s *VideoService) notifyVideoReviewed(ctx context.Context, authorID, videoID uint32, title, reason string, outcome videoReviewOutcome) {
	if s.internalMessage == nil || authorID == 0 {
		return
	}
	var body string
	switch outcome {
	case reviewPassed:
		body = "你的视频《" + title + "》已通过审核" + spVideoBizMarker(videoID)
	case reviewRejected:
		body = "你的视频《" + title + "》未通过审核：" + reason + spVideoBizMarker(videoID)
	case reviewOffline:
		body = "你的视频《" + title + "》已被下架：" + reason + spVideoBizMarker(videoID)
	default:
		return
	}
	spSendUserNotice(ctx, s.internalMessage, s.log, "审核结果", body, authorID)
}

// videoReviewOutcome 审核结果类型（通知文案分支）。
type videoReviewOutcome int

const (
	reviewNone videoReviewOutcome = iota
	reviewPassed
	reviewRejected
	reviewOffline
)
