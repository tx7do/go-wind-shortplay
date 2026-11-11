package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// SysConfig holds the schema definition for the SysConfig entity.
// shortplay 运维开关单行表（id=1）：上传限制 / 时长限制 / 人工审核 / 开放注册。
type SysConfig struct {
	ent.Schema
}

func (SysConfig) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_sys_configs",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("shortplay 系统配置表（单行）"),
	}
}

// Fields of the SysConfig.
func (SysConfig) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("max_upload_size_mb").
			Comment("单视频大小上限（MB）").
			Default(500),

		field.Uint32("max_duration_seconds").
			Comment("单视频时长上限（秒）").
			Default(600),

		field.Bool("manual_review_enabled").
			Comment("人工审核开关（false 则发布直接可见）").
			Default(false),

		field.Bool("register_enabled").
			Comment("开放注册开关").
			Default(true),

		field.JSON("allowed_video_types", []string{}).
			Comment("允许的视频扩展名（小写带点）").
			Optional(),

		field.Bool("sensitive_filter_enabled").
			Comment("敏感词过滤开关（命中：发布转审核中 / 评论拒绝）").
			Default(false),

		field.JSON("sensitive_words", []string{}).
			Comment("敏感词表").
			Optional(),

		field.Bool("announcement_enabled").
			Comment("App 公告横幅开关").
			Default(false),

		field.Text("announcement_text").
			Comment("公告文案（空则不展示）").
			Optional().
			Nillable(),

		field.String("announcement_link").
			Comment("公告跳转链接（可空）").
			Default(""),

		field.Bool("danmaku_enabled").
			Comment("弹幕开关（关闭则 App 隐藏弹幕层并拒绝发送）").
			Default(true),

		field.Bool("im_enabled").
			Comment("私信开关（关闭则拒绝发送，存量会话仍可读）").
			Default(true),
	}
}

// Mixin of the SysConfig.
func (SysConfig) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId64{},
		mixin.TimeAt{},
		mixin.OperatorID64{},
	}
}
