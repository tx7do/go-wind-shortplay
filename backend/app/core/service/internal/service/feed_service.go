package service

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/redis/go-redis/v9"
	"github.com/tx7do/go-utils/trans"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	videopkg "go-wind-shortplay/app/core/service/internal/data/ent/video"

	feedV1 "go-wind-shortplay/api/gen/go/feed/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
)

const (
	// feedSeenKeyPrefix 已看集合 key 前缀（全仓 Redis key 约定 gowind-shortplay: 前缀）
	feedSeenKeyPrefix = "gowind-shortplay:feed:seen:"
	// feedSeenTTL 已看集合过期时间
	feedSeenTTL = 7 * 24 * time.Hour
	// feedSeenCap 已看集合上限，防止无限膨胀
	feedSeenCap = 2000

	// feedDislikeKeyPrefix 「不感兴趣」负反馈集合 key 前缀（uba 服务写入、feed 召回过滤）
	feedDislikeKeyPrefix = "gowind-shortplay:feed:dislike:"
	// feedDislikeTTL 负反馈过期时间（与已看集合同周期）
	feedDislikeTTL = 7 * 24 * time.Hour

	// searchHotKey 热搜词 ZSet key（member=关键词，score=搜索次数）
	searchHotKey = "gowind-shortplay:search:hot"
	// searchHotCap 热搜词榜保留条数（裁剪尾部防膨胀）
	searchHotCap = 100
	// spSearchKeywordMaxRunes 关键词入库上限（防超长串污染榜单）
	spSearchKeywordMaxRunes = 50
)

type FeedService struct {
	feedV1.UnimplementedFeedServiceServer

	log *log.Helper

	videoRepo *data.VideoRepo
	userRepo  data.UserRepo
	interRepo *data.InteractionRepo
	statsRepo *data.StatsRepo
	ubaRepo   *data.UbaRepo
	redis     *redis.Client
}

func NewFeedService(
	ctx *bootstrap.Context,
	videoRepo *data.VideoRepo,
	userRepo data.UserRepo,
	interRepo *data.InteractionRepo,
	statsRepo *data.StatsRepo,
	ubaRepo *data.UbaRepo,
	rdb *redis.Client,
) *FeedService {
	return &FeedService{
		log:       ctx.NewLoggerHelper("feed/service/core-service"),
		videoRepo: videoRepo,
		userRepo:  userRepo,
		interRepo: interRepo,
		statsRepo: statsRepo,
		ubaRepo:   ubaRepo,
		redis:     rdb,
	}
}

// ── 已看集合（Redis set，尽力而为）──

func (s *FeedService) seenKey(uid int64) string {
	return fmt.Sprintf("%s%d", feedSeenKeyPrefix, uid)
}

func (s *FeedService) loadSeenSet(ctx context.Context, uid int64) map[int64]struct{} {
	out := make(map[int64]struct{})
	if uid == 0 || s.redis == nil {
		return out
	}
	ids, err := s.redis.SMembers(ctx, s.seenKey(uid)).Result()
	if err != nil {
		return out
	}
	for _, idStr := range ids {
		var id int64
		if _, err := fmt.Sscanf(idStr, "%d", &id); err == nil {
			out[id] = struct{}{}
		}
	}
	return out
}

// markSeen 本页记为已看（SAdd + TTL；超上限随机弹出多余成员防膨胀）
func (s *FeedService) markSeen(ctx context.Context, uid int64, videoIDs []int64) {
	if uid == 0 || s.redis == nil || len(videoIDs) == 0 {
		return
	}
	key := s.seenKey(uid)
	members := make([]interface{}, 0, len(videoIDs))
	for _, id := range videoIDs {
		members = append(members, fmt.Sprintf("%d", id))
	}
	pipe := s.redis.Pipeline()
	pipe.SAdd(ctx, key, members...)
	pipe.Expire(ctx, key, feedSeenTTL)
	if _, err := pipe.Exec(ctx); err != nil {
		s.log.Warnf("mark seen failed: %s", err.Error())
		return
	}
	if n, err := s.redis.SCard(ctx, key).Result(); err == nil && n > feedSeenCap {
		s.redis.SPopN(ctx, key, n-feedSeenCap)
	}
}

// loadDislikeSet 「不感兴趣」集合（Redis set，尽力而为；uba 服务写入）
func (s *FeedService) loadDislikeSet(ctx context.Context, uid int64) map[int64]struct{} {
	out := make(map[int64]struct{})
	if uid == 0 || s.redis == nil {
		return out
	}
	ids, err := s.redis.SMembers(ctx, fmt.Sprintf("%s%d", feedDislikeKeyPrefix, uid)).Result()
	if err != nil {
		return out
	}
	for _, idStr := range ids {
		var id int64
		if _, err := fmt.Sscanf(idStr, "%d", &id); err == nil {
			out[id] = struct{}{}
		}
	}
	return out
}

// RecordSearchKeyword 搜索词计入热搜榜（ZIncrBy + 裁剪，尽力而为）。
// 空串/超长词不入榜；大小写归一防同词分列。
func (s *FeedService) RecordSearchKeyword(ctx context.Context, keyword string) {
	if s.redis == nil {
		return
	}
	kw := strings.TrimSpace(strings.ToLower(keyword))
	if kw == "" || len([]rune(kw)) > spSearchKeywordMaxRunes {
		return
	}
	pipe := s.redis.Pipeline()
	pipe.ZIncrBy(ctx, searchHotKey, 1, kw)
	pipe.ZRemRangeByRank(ctx, searchHotKey, 0, -(searchHotCap + 1))
	if _, err := pipe.Exec(ctx); err != nil {
		s.log.Warnf("record search keyword failed: %s", err.Error())
	}
}

// pageArgsFeed 页码/页大小（缺省 1/10，上限 50）
func pageArgsFeed(pageNum, pageSize int64) (int64, int64) {
	if pageNum < 1 {
		pageNum = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	if pageSize > 50 {
		pageSize = 50
	}
	return pageNum, pageSize
}

// GetFeed 沉浸式 Feed：关注召回 → 热门 → 最新兜底，已看过滤
func (s *FeedService) GetFeed(ctx context.Context, req *feedV1.GetFeedRequest) (*feedV1.GetFeedResponse, error) {
	pageNum, pageSize := pageArgsFeed(int64(req.GetPageNum()), int64(req.GetPageSize()))
	uid := spViewerUserID(ctx)

	recallN := int(pageSize) * 4
	reasonsOf := make(map[int64]feedV1.FeedReason, recallN)
	merged := make([]*ent.Video, 0, recallN)
	mergedIDs := make(map[int64]struct{}, recallN)

	add := func(vs []*ent.Video, reason feedV1.FeedReason) {
		for _, v := range vs {
			if _, dup := mergedIDs[v.ID]; dup {
				continue
			}
			mergedIDs[v.ID] = struct{}{}
			merged = append(merged, v)
			reasonsOf[v.ID] = reason
		}
	}

	seen := s.loadSeenSet(ctx, uid)
	disliked := s.loadDislikeSet(ctx, uid)
	excluded := func(vs []*ent.Video) []*ent.Video {
		if len(seen) == 0 && len(disliked) == 0 {
			return vs
		}
		out := make([]*ent.Video, 0, len(vs))
		for _, v := range vs {
			if _, wasSeen := seen[v.ID]; wasSeen {
				continue
			}
			if _, notInterested := disliked[v.ID]; notInterested {
				continue
			}
			out = append(out, v)
		}
		return out
	}

	// 1. 关注召回
	if uid > 0 {
		authorIDs, _ := s.interRepo.FollowingAuthorIDs(ctx, uid, 100)
		if followVideos, err := s.videoRepo.ListPublishedByAuthors(ctx, authorIDs, recallN); err == nil {
			add(excluded(followVideos), feedV1.FeedReason_FEED_REASON_FOLLOW)
		}
	}
	// 2. 热门加权
	if hotVideos, err := s.videoRepo.ListHot(ctx, recallN); err == nil {
		add(excluded(hotVideos), feedV1.FeedReason_FEED_REASON_HOT)
	}
	// 3. 最新兜底（带标签过滤时走标签聚合）
	if req.GetTag() != "" {
		if tagVideos, err := s.videoRepo.ListByTag(ctx, req.GetTag(), recallN); err == nil {
			add(excluded(tagVideos), feedV1.FeedReason_FEED_REASON_LATEST)
		}
	} else if latestVideos, err := s.videoRepo.ListLatest(ctx, recallN); err == nil {
		add(excluded(latestVideos), feedV1.FeedReason_FEED_REASON_LATEST)
	}

	// 截页
	offset := (pageNum - 1) * pageSize
	if int(offset) >= len(merged) {
		merged = nil
	} else {
		merged = merged[offset:]
	}
	hasMore := false
	if len(merged) > int(pageSize) {
		merged = merged[:pageSize]
		hasMore = true
	}

	items := make([]*feedV1.FeedItem, 0, len(merged))
	videoIDs := make([]int64, 0, len(merged))
	for _, v := range merged {
		reason := reasonsOf[v.ID]
		if reason == feedV1.FeedReason_FEED_REASON_UNSPECIFIED {
			reason = feedV1.FeedReason_FEED_REASON_LATEST
		}
		items = append(items, &feedV1.FeedItem{
			Video:  spVideoToDTO(v, nil),
			Reason: reason,
		})
		videoIDs = append(videoIDs, v.ID)
	}

	// 本页记为已看（下翻不重复推送）
	if uid > 0 && len(videoIDs) > 0 {
		s.markSeen(ctx, uid, videoIDs)
	}

	return &feedV1.GetFeedResponse{
		Items:   items,
		HasMore: trans.Ptr(hasMore),
	}, nil
}

// GetVideoDetail 单视频详情 + 作者 + 观看者状态；播放量 +1
func (s *FeedService) GetVideoDetail(ctx context.Context, req *feedV1.GetVideoDetailRequest) (*feedV1.VideoDetail, error) {
	e, err := s.videoRepo.GetEntityRaw(ctx, req.GetVideoId())
	if err != nil {
		return nil, feedV1.ErrorNotFound("video not found")
	}
	// 非已发布视频仅管理端可见
	if e.Status != videopkg.StatusPublished && !spIsAdminCaller(ctx) {
		return nil, feedV1.ErrorNotFound("video not found")
	}

	tags, _ := s.videoRepo.TagsOfVideo(ctx, e.ID)
	detail := &feedV1.VideoDetail{
		Video: spVideoToDTO(e, tags),
	}

	if author, aerr := s.userRepo.Get(ctx, &identityV1.GetUserRequest{
		QueryBy: &identityV1.GetUserRequest_Id{Id: e.AuthorID},
	}); aerr == nil && author != nil {
		detail.Author = toUserBriefSP(author)

		following, followers, _ := s.interRepo.FollowCounts(ctx, author.GetId())
		detail.AuthorStats = &identityV1.UserStats{
			UserId:         trans.Ptr(author.GetId()),
			FollowerCount:  u64pI64v(int64(followers)),
			FollowingCount: u64pI64v(int64(following)),
		}
	}

	// 观看者互动状态（游客全 false）+ 断点续播位置
	uid := spViewerUserID(ctx)
	state := &feedV1.ViewerState{Liked: trans.Ptr(false), Collected: trans.Ptr(false), Following: trans.Ptr(false)}
	if uid > 0 {
		liked, _ := s.interRepo.GetLikeStatus(ctx, uid, []int64{e.ID})
		collected, _ := s.interRepo.GetCollectStatus(ctx, uid, []int64{e.ID})
		followed, _ := s.interRepo.GetFollowStatus(ctx, uid, []int64{e.AuthorID})
		state.Liked = trans.Ptr(liked[e.ID])
		state.Collected = trans.Ptr(collected[e.ID])
		state.Following = trans.Ptr(followed[e.AuthorID])
		if s.ubaRepo != nil {
			if pos, perr := s.ubaRepo.LatestPosition(ctx, uid, e.ID); perr == nil && pos > 0 {
				state.ResumePositionMs = u64pI64v(pos)
			}
		}
	}
	detail.ViewerState = state

	// 播放量 +1（容忍失败）
	_ = s.videoRepo.AddViewCount(ctx, e.ID)

	return detail, nil
}

// SearchVideos 搜索（标题模糊 + 标签精确合并；关键词计入热搜榜）
func (s *FeedService) SearchVideos(ctx context.Context, req *feedV1.SearchVideosRequest) (*feedV1.GetFeedResponse, error) {
	pageNum, pageSize := pageArgsFeed(int64(req.GetPageNum()), int64(req.GetPageSize()))
	videos, err := s.videoRepo.SearchByKeyword(ctx, req.GetKeyword(), 200)
	if err != nil {
		return nil, err
	}
	s.RecordSearchKeyword(ctx, req.GetKeyword())
	return feedItemsFromVideosSP(videos, int(pageNum), int(pageSize)), nil
}

// ListHotKeywords 热搜词（真实搜索频次倒序，游客可访问；尽力而为）
func (s *FeedService) ListHotKeywords(ctx context.Context, req *feedV1.ListHotKeywordsRequest) (*feedV1.ListHotKeywordsResponse, error) {
	resp := &feedV1.ListHotKeywordsResponse{Keywords: []string{}}
	if s.redis == nil {
		return resp, nil
	}
	limit := int(req.GetLimit())
	if limit <= 0 {
		limit = 10
	}
	if limit > 20 {
		limit = 20
	}
	kws, err := s.redis.ZRangeArgs(ctx, redis.ZRangeArgs{
		Key:   searchHotKey,
		Start: 0,
		Stop:  int64(limit - 1),
		Rev:   true,
	}).Result()
	if err != nil {
		return resp, nil
	}
	resp.Keywords = kws
	return resp, nil
}

// ListVideosByTag 标签聚合
func (s *FeedService) ListVideosByTag(ctx context.Context, req *feedV1.ListVideosByTagRequest) (*feedV1.GetFeedResponse, error) {
	pageNum, pageSize := pageArgsFeed(int64(req.GetPageNum()), int64(req.GetPageSize()))
	videos, err := s.videoRepo.ListByTag(ctx, req.GetTag(), 200)
	if err != nil {
		return nil, err
	}
	return feedItemsFromVideosSP(videos, int(pageNum), int(pageSize)), nil
}

func feedItemsFromVideosSP(videos []*ent.Video, pageNum, pageSize int) *feedV1.GetFeedResponse {
	resp := &feedV1.GetFeedResponse{HasMore: trans.Ptr(false)}
	if len(videos) == 0 {
		return resp
	}
	offset := (pageNum - 1) * pageSize
	if offset >= len(videos) {
		return resp
	}
	videos = videos[offset:]
	hasMore := false
	if len(videos) > pageSize {
		videos = videos[:pageSize]
		hasMore = true
	}
	for _, v := range videos {
		resp.Items = append(resp.Items, &feedV1.FeedItem{
			Video:  spVideoToDTO(v, nil),
			Reason: feedV1.FeedReason_FEED_REASON_LATEST,
		})
	}
	resp.HasMore = trans.Ptr(hasMore)
	return resp
}

// spVideoStatusDTO ent 状态枚举 → proto
func spVideoStatusDTO(s videopkg.Status) videoV1.VideoStatus {
	switch s {
	case videopkg.StatusDraft:
		return videoV1.VideoStatus_VIDEO_STATUS_DRAFT
	case videopkg.StatusReviewing:
		return videoV1.VideoStatus_VIDEO_STATUS_REVIEWING
	case videopkg.StatusPublished:
		return videoV1.VideoStatus_VIDEO_STATUS_PUBLISHED
	case videopkg.StatusRejected:
		return videoV1.VideoStatus_VIDEO_STATUS_REJECTED
	case videopkg.StatusOffline:
		return videoV1.VideoStatus_VIDEO_STATUS_OFFLINE
	default:
		return videoV1.VideoStatus_VIDEO_STATUS_UNSPECIFIED
	}
}

// spVideoToDTO ent.Video → proto Video（服务内映射，标签另查）
func spVideoToDTO(e *ent.Video, tags []string) *videoV1.Video {
	if e == nil {
		return nil
	}
	return &videoV1.Video{
		Id:           trans.Ptr(e.ID),
		Title:        trans.Ptr(e.Title),
		Description:  e.Description,
		CoverUrl:     e.CoverURL,
		VideoUrl:     e.VideoURL,
		Duration:     trans.Ptr(e.Duration),
		Width:        trans.Ptr(e.Width),
		Height:       trans.Ptr(e.Height),
		Status:       spVideoStatusDTO(e.Status).Enum(),
		AuthorId:     trans.Ptr(e.AuthorID),
		LikeCount:    i64FromU64p(&e.LikeCount),
		CollectCount: trans.Ptr(e.CollectCount),
		CommentCount: i64FromU64p(&e.CommentCount),
		ViewCount:    trans.Ptr(e.ViewCount),
		RejectReason: e.RejectReason,
		Tags:         tags,
	}
}

// toUserBriefSP identity User → UserBrief
func toUserBriefSP(u *identityV1.User) *identityV1.UserBrief {
	if u == nil {
		return nil
	}
	return &identityV1.UserBrief{
		Id:        trans.Ptr(u.GetId()),
		Nickname:  trans.Ptr(u.GetNickname()),
		AvatarUrl: trans.Ptr(u.GetAvatar()),
	}
}

func u64pI64v(v int64) *uint64 {
	x := uint64(v)
	return &x
}

func i64FromU64v(v *uint64) *int64 {
	if v == nil {
		return nil
	}
	x := int64(*v)
	return &x
}

func i64FromU64p(v *uint64) *int64 {
	if v == nil {
		return nil
	}
	x := int64(*v)
	return &x
}
