package service

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/redis/go-redis/v9"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	feedV1 "go-wind-shortplay/api/gen/go/feed/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	"go-wind-shortplay/app/core/service/internal/data"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/pkg/authctx"
)

const (
	seenKeyPrefix = "feed:seen:"
	seenTTL       = 7 * 24 * time.Hour
	seenCap       = 2000 // 已看集合上限，防止无限膨胀
)

type FeedService struct {
	feedV1.UnimplementedFeedServiceServer

	videoRepo  *data.VideoRepo
	userRepo   *data.UserRepo
	interRepo  *data.InteractionRepo
	redis      *redis.Client
	log        *log.Helper
}

func NewFeedService(ctx *bootstrap.Context, videoRepo *data.VideoRepo, userRepo *data.UserRepo, interRepo *data.InteractionRepo, rdb *redis.Client) *FeedService {
	return &FeedService{
		videoRepo: videoRepo,
		userRepo:  userRepo,
		interRepo: interRepo,
		redis:     rdb,
		log:       ctx.NewLoggerHelper("feed/service/core-service"),
	}
}

// GetFeed 沉浸式 Feed 流：关注召回优先 → 热门 → 最新兜底，已看过滤
func (s *FeedService) GetFeed(ctx context.Context, req *feedV1.GetFeedRequest) (*feedV1.GetFeedResponse, error) {
	_, pageSize := pageArgs(req.GetPageNum(), req.GetPageSize())
	uid := authctx.UserIDFromContext(ctx)

	// 三路召回（配额按页大小放大，合并去重后再截页）
	recallN := pageSize * 4
	var followVideos, hotVideos, latestVideos []*ent.Video
	var err error

	if uid > 0 {
		authorIDs, _ := s.interRepo.FollowingAuthorIDs(ctx, uid, 100)
		followVideos, err = s.videoRepo.ListPublishedByAuthors(ctx, authorIDs, recallN)
		if err != nil {
			s.log.Warnf("follow recall failed: %s", err.Error())
		}
	}
	hotVideos, err = s.videoRepo.ListHot(ctx, recallN)
	if err != nil {
		s.log.Warnf("hot recall failed: %s", err.Error())
	}
	latestVideos, err = s.videoRepo.ListLatest(ctx, recallN)
	if err != nil {
		s.log.Warnf("latest recall failed: %s", err.Error())
	}

	// 已看过滤
	seen := s.loadSeenSet(ctx, uid)

	merged := make([]*ent.Video, 0, recallN)
	seenIDs := make(map[uint32]struct{}, recallN)
	add := func(vs []*ent.Video) {
		for _, v := range vs {
			if _, dup := seenIDs[v.ID]; dup {
				continue
			}
			if _, wasSeen := seen[v.ID]; wasSeen {
				continue
			}
			seenIDs[v.ID] = struct{}{}
			merged = append(merged, v)
		}
	}
	add(followVideos)
	add(hotVideos)
	add(latestVideos)

	// 截页
	offset, limit := pageArgs(req.GetPageNum(), req.GetPageSize())
	if offset > len(merged) {
		merged = nil
	} else {
		merged = merged[offset:]
	}
	if len(merged) > limit {
		merged = merged[:limit]
	}

	items := make([]*feedV1.FeedItem, 0, len(merged))
	for _, v := range merged {
		reason := feedV1.FeedReason_FEED_REASON_LATEST
		for _, fv := range followVideos {
			if fv.ID == v.ID {
				reason = feedV1.FeedReason_FEED_REASON_FOLLOW
				break
			}
		}
		if reason == feedV1.FeedReason_FEED_REASON_LATEST {
			for _, hv := range hotVideos {
				if hv.ID == v.ID {
					reason = feedV1.FeedReason_FEED_REASON_HOT
					break
				}
			}
		}
		items = append(items, &feedV1.FeedItem{
			Video:  toVideo(v, nil),
			Reason: reason,
		})
	}

	// 本页记为已看（下翻不重复推送）
	if uid > 0 && len(merged) > 0 {
		s.markSeen(ctx, uid, merged)
	}

	return &feedV1.GetFeedResponse{
		Items:   items,
		HasMore: ptr(len(items) >= pageSize),
	}, nil
}

// GetVideoDetail 单视频详情 + 作者 + 观看者状态；浏览量 +1
func (s *FeedService) GetVideoDetail(ctx context.Context, req *feedV1.GetVideoDetailRequest) (*feedV1.VideoDetail, error) {
	v, err := s.videoRepo.GetByID(ctx, req.GetVideoId())
	if err != nil {
		return nil, feedV1.ErrorNotFound("video not found")
	}
	if v.AuthorID == nil {
		return nil, feedV1.ErrorNotFound("video author missing")
	}

	author, err := s.userRepo.GetByID(ctx, *v.AuthorID)
	if err != nil {
		return nil, feedV1.ErrorNotFound("author not found")
	}

	detail := &feedV1.VideoDetail{
		Video:  toVideo(v, nil),
		Author: toUserBrief(author),
	}

	// 作者统计
	following, followers, _ := s.interRepo.FollowCounts(ctx, author.ID)
	detail.AuthorStats = &identityV1.UserStats{
		UserId:        ptr(author.ID),
		FollowerCount: ptr(uint64(followers)),
		FollowingCount: ptr(uint64(following)),
	}

	// 观看者互动状态（游客全 false）
	uid := authctx.UserIDFromContext(ctx)
	state := &feedV1.ViewerState{Liked: ptr(false), Collected: ptr(false), Following: ptr(false)}
	if uid > 0 {
		liked, collected, _ := s.interRepo.GetInteractionStatus(ctx, uid, []uint32{v.ID})
		isFollowed, _ := s.interRepo.GetFollowStatus(ctx, uid, []uint32{author.ID})
		state.Liked = ptr(liked[v.ID])
		state.Collected = ptr(collected[v.ID])
		state.Following = ptr(isFollowed[author.ID])
	}
	detail.ViewerState = state

	return detail, nil
}

// SearchVideos 标题模糊 + 标签精确搜索
func (s *FeedService) SearchVideos(ctx context.Context, req *feedV1.SearchVideosRequest) (*feedV1.GetFeedResponse, error) {
	keyword := req.GetKeyword()
	if keyword == "" {
		return &feedV1.GetFeedResponse{Items: []*feedV1.FeedItem{}, HasMore: ptr(false)}, nil
	}

	found, err := s.videoRepo.SearchByTitle(ctx, keyword, 50)
	if err != nil {
		return nil, feedV1.ErrorInternalServerError("search failed")
	}

	// 标签精确匹配合并（去重）
	if tag, err := s.videoRepo.TagByName(ctx, keyword); err == nil && tag != nil {
		ids, _ := s.videoRepo.VideoIDsByTag(ctx, tag.ID, 50)
		byTag, _ := s.videoRepo.ListPublishedByIDs(ctx, ids)
		exist := make(map[uint32]struct{}, len(found))
		for _, f := range found {
			exist[f.ID] = struct{}{}
		}
		for _, v := range byTag {
			if _, dup := exist[v.ID]; !dup {
				found = append(found, v)
			}
		}
	}

	return paginateVideos(found, req.GetPageNum(), req.GetPageSize()), nil
}

func (s *FeedService) ListVideosByTag(ctx context.Context, req *feedV1.ListVideosByTagRequest) (*feedV1.GetFeedResponse, error) {
	tag, err := s.videoRepo.TagByName(ctx, req.GetTag())
	if err != nil {
		return &feedV1.GetFeedResponse{Items: []*feedV1.FeedItem{}, HasMore: ptr(false)}, nil
	}
	ids, err := s.videoRepo.VideoIDsByTag(ctx, tag.ID, 200)
	if err != nil {
		return nil, feedV1.ErrorInternalServerError("list tag videos failed")
	}
	found, err := s.videoRepo.ListPublishedByIDs(ctx, ids)
	if err != nil {
		return nil, feedV1.ErrorInternalServerError("list tag videos failed")
	}
	return paginateVideos(found, req.GetPageNum(), req.GetPageSize()), nil
}

// paginateVideos 内存分页打包（召回集合量级小，够用；量大后改为查询层分页）
func paginateVideos(vs []*ent.Video, pageNum, pageSize uint32) *feedV1.GetFeedResponse {
	offset, limit := pageArgs(pageNum, pageSize)
	if offset > len(vs) {
		vs = nil
	} else {
		vs = vs[offset:]
	}
	if len(vs) > limit {
		vs = vs[:limit]
	}
	items := make([]*feedV1.FeedItem, 0, len(vs))
	for _, v := range vs {
		items = append(items, &feedV1.FeedItem{Video: toVideo(v, nil)})
	}
	return &feedV1.GetFeedResponse{
		Items:   items,
		HasMore: ptr(offset+len(vs) < limit*50), // 粗略判断
	}
}

// ── 已看集合（Redis） ──

func (s *FeedService) seenKey(uid uint32) string {
	return fmt.Sprintf("%s%d", seenKeyPrefix, uid)
}

func (s *FeedService) loadSeenSet(ctx context.Context, uid uint32) map[uint32]struct{} {
	res := make(map[uint32]struct{})
	if uid == 0 || s.redis == nil {
		return res
	}
	ids, err := s.redis.SMembers(ctx, s.seenKey(uid)).Result()
	if err != nil {
		return res
	}
	for _, raw := range ids {
		if id, err := strconv.ParseUint(raw, 10, 32); err == nil {
			res[uint32(id)] = struct{}{}
		}
	}
	return res
}

func (s *FeedService) markSeen(ctx context.Context, uid uint32, vs []*ent.Video) {
	if uid == 0 || s.redis == nil {
		return
	}
	members := make([]interface{}, 0, len(vs))
	for _, v := range vs {
		members = append(members, strconv.FormatUint(uint64(v.ID), 10))
	}
	key := s.seenKey(uid)
	pipe := s.redis.Pipeline()
	pipe.SAdd(ctx, key, members...)
	pipe.Expire(ctx, key, seenTTL)
	// 超限裁剪：保留最新的一半（SPOP 随机弹出，已看集合允许有损）
	if n, _ := s.redis.SCard(ctx, key).Result(); n > seenCap {
		pipe.SPopN(ctx, key, n-seenCap/2)
	}
	_, _ = pipe.Exec(ctx)
}

// RecordSeen 供 UBA 服务在播放事件时调用（观看 ≥N 秒才算已看也可后续细化）
func (s *FeedService) RecordSeen(ctx context.Context, uid, videoID uint32) {
	if uid == 0 || videoID == 0 {
		return
	}
	s.markSeen(ctx, uid, []*ent.Video{{ID: videoID}})
}
