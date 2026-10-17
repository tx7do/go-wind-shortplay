package server

import (
	"context"
	"fmt"
	"html"
	"io"
	"net/http"
	"strconv"

	khttp "github.com/go-kratos/kratos/v2/transport/http"

	feedV1 "go-wind-shortplay/api/gen/go/feed/service/v1"
)

// RegisterSharePage 分享 H5 预览页（GET /s/{video_id}）。
//
// 简易实现：服务端拉视频详情渲染内联 HTML（video 标签 + OG meta），
// 微信/浏览器内打开直接可播；Flutter 端分享链接指向此页。
// Phase 2+ 可替换为独立 H5 站点或 SSR。
func RegisterSharePage(srv *khttp.Server, feedClient feedV1.FeedServiceClient) {
	srv.Route("/s").GET("/{video_id}", func(ctx khttp.Context) error {
		videoID, err := strconv.ParseUint(ctx.Vars().Get("video_id"), 10, 32)
		if err != nil || videoID == 0 {
			ctx.Response().WriteHeader(http.StatusNotFound)
			_, werr := io.WriteString(ctx.Response(), "not found")
			return werr
		}

		reqCtx, cancel := context.WithTimeout(ctx, 5_000_000_000) // 5s
		defer cancel()
		detail, err := feedClient.GetVideoDetail(reqCtx, &feedV1.GetVideoDetailRequest{VideoId: uint32(videoID)})
		if err != nil || detail.GetVideo() == nil {
			ctx.Response().WriteHeader(http.StatusNotFound)
			_, werr := io.WriteString(ctx.Response(), "video not found")
			return werr
		}

		v := detail.GetVideo()
		title := html.EscapeString(v.GetTitle())
		author := html.EscapeString(detail.GetAuthor().GetNickname())
		cover := html.EscapeString(v.GetCoverUrl())
		videoURL := html.EscapeString(v.GetVideoUrl())
		desc := html.EscapeString(v.GetDescription())

		page := fmt.Sprintf(`<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta property="og:title" content="%s">
<meta property="og:description" content="%s">
<meta property="og:image" content="%s">
<meta property="og:type" content="video.other">
<title>%s - 风行短剧</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#000;color:#fff;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif;
display:flex;align-items:center;justify-content:center;min-height:100vh}
.stage{position:relative;width:100%%;max-width:480px;aspect-ratio:9/16;max-height:100vh;background:#111}
video{width:100%%;height:100%%;object-fit:contain}
.meta{position:absolute;left:0;right:0;bottom:0;padding:24px 16px 20px;
background:linear-gradient(transparent,rgba(0,0,0,.85));pointer-events:none}
.meta h1{font-size:16px;font-weight:600;margin-bottom:6px}
.meta p{font-size:13px;color:#ddd;margin-bottom:4px}
.meta .author{font-size:14px;color:#fff;font-weight:500}
.badge{position:absolute;top:12px;right:12px;background:rgba(0,0,0,.5);color:#fff;
font-size:12px;padding:4px 10px;border-radius:999px;pointer-events:none}
</style>
</head>
<body>
<div class="stage">
<video src="%s" poster="%s" controls playsinline autoplay muted loop></video>
<div class="badge">风行短剧</div>
<div class="meta">
<h1>%s</h1>
<p class="author">@%s</p>
<p>%s</p>
</div>
</div>
</body>
</html>`, title, desc, cover, title, videoURL, cover, title, author, desc)

		ctx.Response().Header().Set("Content-Type", "text/html; charset=utf-8")
		_, werr := io.WriteString(ctx.Response(), page)
		return werr
	})
}
