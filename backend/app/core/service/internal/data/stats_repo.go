package data

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	"go-wind-shortplay/app/core/service/internal/data/ent"

	statsV1 "go-wind-shortplay/api/gen/go/stats/service/v1"
)

// StatsRepo 数据看板聚合仓储（基于 shortplay 业务表 SQL 聚合，走 ent driver 原生查询）。
type StatsRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewStatsRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *StatsRepo {
	return &StatsRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("stats/repo/core-service"),
	}
}

// OverviewRow 运营总览聚合行
type OverviewRow struct {
	TotalVideos     uint64 `json:"total_videos"`
	PublishedVideos uint64 `json:"published_videos"`
	TotalViews      uint64 `json:"total_views"`
	TotalLikes      uint64 `json:"total_likes"`
	TotalComments   uint64 `json:"total_comments"`
	TodayPublished  uint64 `json:"today_published"`
}

// TrendRow 单日趋势聚合行
type TrendRow struct {
	Day       string `json:"day"`
	Published uint64 `json:"published"`
	Plays     uint64 `json:"plays"`
	Likes     uint64 `json:"likes"`
}

// AuthorAggRow 作者作品聚合行
type AuthorAggRow struct {
	Cnt      uint64 `json:"cnt"`
	Views    uint64 `json:"views"`
	Likes    uint64 `json:"likes"`
	Collects uint64 `json:"collects"`
	Comments uint64 `json:"comments"`
}

// queryUint64 单值聚合查询（COUNT/SUM，空结果返回 0）
func (r *StatsRepo) queryUint64(ctx context.Context, query string, args ...any) (uint64, error) {
	rows, err := r.entClient.DB().QueryContext(ctx, query, args...)
	if err != nil {
		return 0, err
	}
	defer func() { _ = rows.Close() }()
	var v uint64
	if rows.Next() {
		if err = rows.Scan(&v); err != nil {
			return 0, err
		}
	}
	return v, rows.Err()
}

// Overview 运营总览聚合
func (r *StatsRepo) Overview(ctx context.Context, totalUsers uint64) (*OverviewRow, error) {
	row := r.entClient.DB().QueryRowContext(ctx, `
SELECT
	COUNT(*) AS total_videos,
	COUNT(*) FILTER (WHERE status = 'PUBLISHED') AS published_videos,
	COALESCE(SUM(view_count), 0)    AS total_views,
	COALESCE(SUM(like_count), 0)    AS total_likes,
	COALESCE(SUM(comment_count), 0) AS total_comments,
	COUNT(*) FILTER (WHERE status = 'PUBLISHED' AND published_at >= date_trunc('day', NOW())) AS today_published
FROM sp_videos`)
	var out OverviewRow
	if err := row.Scan(&out.TotalVideos, &out.PublishedVideos, &out.TotalViews, &out.TotalLikes, &out.TotalComments, &out.TodayPublished); err != nil {
		r.log.Errorf("overview aggregate failed: %s", err.Error())
		return nil, err
	}
	return &out, nil
}

// TotalUsers 用户总数（正常状态）
func (r *StatsRepo) TotalUsers(ctx context.Context) (uint64, error) {
	return r.queryUint64(ctx, `SELECT COUNT(*) FROM sys_users WHERE status = 'NORMAL'`)
}

// TrendRows 近 N 日趋势（published 按视频 published_at 落日；plays/likes 按 uba_events 当日 VIDEO_PLAY/VIDEO_LIKE 计数）
func (r *StatsRepo) TrendRows(ctx context.Context, days int) ([]*TrendRow, error) {
	if days <= 0 {
		days = 7
	}
	if days > 30 {
		days = 30
	}
	rows, err := r.entClient.DB().QueryContext(ctx, `
WITH series AS (
	SELECT TO_CHAR(generate_series(date_trunc('day', NOW()::timestamp - ($1::int - 1) * INTERVAL '1 day'), date_trunc('day', NOW()::timestamp), INTERVAL '1 day'), 'YYYY-MM-DD') AS day
),
pub AS (
	SELECT TO_CHAR(published_at, 'YYYY-MM-DD') AS day, COUNT(*)::bigint AS published
	FROM sp_videos
	WHERE status = 'PUBLISHED' AND published_at IS NOT NULL
	  AND published_at >= date_trunc('day', NOW()::timestamp - ($1::int - 1) * INTERVAL '1 day')
	GROUP BY 1
),
ev AS (
	SELECT TO_CHAR(created_at, 'YYYY-MM-DD') AS day,
	       COUNT(*) FILTER (WHERE event_type = 'VIDEO_PLAY')::bigint AS plays,
	       COUNT(*) FILTER (WHERE event_type = 'VIDEO_LIKE')::bigint AS likes
	FROM sp_uba_events
	WHERE created_at >= date_trunc('day', NOW()::timestamp - ($1::int - 1) * INTERVAL '1 day')
	GROUP BY 1
)
SELECT s.day,
       COALESCE(p.published, 0) AS published,
       COALESCE(e.plays, 0)     AS plays,
       COALESCE(e.likes, 0)     AS likes
FROM series s
LEFT JOIN pub p ON p.day = s.day
LEFT JOIN ev  e ON e.day = s.day
ORDER BY s.day`, days)
	if err != nil {
		r.log.Errorf("trends aggregate failed: %s", err.Error())
		return nil, err
	}
	defer func() { _ = rows.Close() }()

	out := make([]*TrendRow, 0, days)
	for rows.Next() {
		var t TrendRow
		if err := rows.Scan(&t.Day, &t.Published, &t.Plays, &t.Likes); err != nil {
			return nil, err
		}
		out = append(out, &t)
	}
	return out, rows.Err()
}

// CreatorTrendRows 创作者近 N 日趋势（本人口径）：published 按本人视频
// published_at 落日；plays/likes 按本人视频的 uba_events 当日计数。
func (r *StatsRepo) CreatorTrendRows(ctx context.Context, authorID uint32, days int) ([]*TrendRow, error) {
	if days <= 0 {
		days = 7
	}
	if days > 30 {
		days = 30
	}
	rows, err := r.entClient.DB().QueryContext(ctx, `
WITH series AS (
	SELECT TO_CHAR(generate_series(date_trunc('day', NOW()::timestamp - ($1::int - 1) * INTERVAL '1 day'), date_trunc('day', NOW()::timestamp), INTERVAL '1 day'), 'YYYY-MM-DD') AS day
),
pub AS (
	SELECT TO_CHAR(published_at, 'YYYY-MM-DD') AS day, COUNT(*)::bigint AS published
	FROM sp_videos
	WHERE author_id = $2 AND status = 'PUBLISHED' AND published_at IS NOT NULL
	  AND published_at >= date_trunc('day', NOW()::timestamp - ($1::int - 1) * INTERVAL '1 day')
	GROUP BY 1
),
ev AS (
	SELECT TO_CHAR(e.created_at, 'YYYY-MM-DD') AS day,
	       COUNT(*) FILTER (WHERE e.event_type = 'VIDEO_PLAY')::bigint AS plays,
	       COUNT(*) FILTER (WHERE e.event_type = 'VIDEO_LIKE')::bigint AS likes
	FROM sp_uba_events e
	JOIN sp_videos v ON v.id = e.video_id
	WHERE v.author_id = $2
	  AND e.created_at >= date_trunc('day', NOW()::timestamp - ($1::int - 1) * INTERVAL '1 day')
	GROUP BY 1
)
SELECT s.day,
       COALESCE(p.published, 0) AS published,
       COALESCE(e.plays, 0)     AS plays,
       COALESCE(e.likes, 0)     AS likes
FROM series s
LEFT JOIN pub p ON p.day = s.day
LEFT JOIN ev  e ON e.day = s.day
ORDER BY s.day`, days, authorID)
	if err != nil {
		r.log.Errorf("creator trends aggregate failed: %s", err.Error())
		return nil, err
	}
	defer func() { _ = rows.Close() }()

	out := make([]*TrendRow, 0, days)
	for rows.Next() {
		var t TrendRow
		if err := rows.Scan(&t.Day, &t.Published, &t.Plays, &t.Likes); err != nil {
			return nil, err
		}
		out = append(out, &t)
	}
	return out, rows.Err()
}

// AuthorAggregates 作者作品聚合（publishedOnly=true 仅统计已发布）
func (r *StatsRepo) AuthorAggregates(ctx context.Context, authorID uint32, publishedOnly bool) (*AuthorAggRow, error) {
	cond := ""
	if publishedOnly {
		cond = " AND status = 'PUBLISHED'"
	}
	row := r.entClient.DB().QueryRowContext(ctx, `
SELECT
	COALESCE(COUNT(*), 0)           AS cnt,
	COALESCE(SUM(view_count), 0)    AS views,
	COALESCE(SUM(like_count), 0)    AS likes,
	COALESCE(SUM(collect_count), 0) AS collects,
	COALESCE(SUM(comment_count), 0) AS comments
FROM sp_videos WHERE author_id = $1`+cond, authorID)
	var out AuthorAggRow
	if err := row.Scan(&out.Cnt, &out.Views, &out.Likes, &out.Collects, &out.Comments); err != nil {
		r.log.Errorf("author aggregate failed: %s", err.Error())
		return nil, err
	}
	return &out, nil
}

// FollowerCount 粉丝数
func (r *StatsRepo) FollowerCount(ctx context.Context, userID uint32) (uint64, error) {
	return r.queryUint64(ctx, `SELECT COUNT(*) FROM sp_user_follows WHERE followee_id = $1`, userID)
}

// FollowingCount 关注数
func (r *StatsRepo) FollowingCount(ctx context.Context, userID uint32) (uint64, error) {
	return r.queryUint64(ctx, `SELECT COUNT(*) FROM sp_user_follows WHERE follower_id = $1`, userID)
}

// ToProto Overview 聚合行 → proto
func (row *OverviewRow) ToProto(totalUsers uint64) *statsV1.Overview {
	return &statsV1.Overview{
		TotalVideos:     &row.TotalVideos,
		PublishedVideos: &row.PublishedVideos,
		TotalViews:      &row.TotalViews,
		TotalLikes:      &row.TotalLikes,
		TotalComments:   &row.TotalComments,
		TotalUsers:      &totalUsers,
		TodayPublished:  &row.TodayPublished,
	}
}
