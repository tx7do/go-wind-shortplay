package service

import (
	"context"
	"strings"

	"go-wind-shortplay/app/core/service/internal/data"
)

// 本地敏感词过滤（开源版内容安全兜底）：发布/评论命中按 sysconf 开关与词表处置——
// 发布转审核中（即使人工审核关）、评论直接拒绝。第三方鉴黄/敏感词为商业增值包
// （docs/ROADMAP.md），本实现为进程内纯文本包含匹配，词表走 sysconf 单行配置。

// spHitSensitiveWords 检查任意文本是否命中敏感词表（开关关闭/词表为空恒 false）。
func spHitSensitiveWords(ctx context.Context, repo *data.SysConfRepo, texts ...string) bool {
	if repo == nil || len(texts) == 0 {
		return false
	}
	conf, err := repo.GetEnsure(ctx)
	if err != nil || !conf.SensitiveFilterEnabled || len(conf.SensitiveWords) == 0 {
		return false
	}
	for _, w := range conf.SensitiveWords {
		w = strings.TrimSpace(w)
		if w == "" {
			continue
		}
		for _, t := range texts {
			if t != "" && strings.Contains(t, w) {
				return true
			}
		}
	}
	return false
}
