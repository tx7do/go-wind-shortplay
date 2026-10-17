package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// SysConfig 系统配置表（单行：id=1）
type SysConfig struct {
	ent.Schema
}

func (SysConfig) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sys_configs",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("系统配置表"),
	}
}

func (SysConfig) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("max_upload_size_mb").
			Comment("单视频大小上限（MB）").
			Default(500).
			Optional().
			Nillable(),
		field.Uint32("max_duration_seconds").
			Comment("单视频时长上限（秒）").
			Default(600).
			Optional().
			Nillable(),
		field.Bool("manual_review_enabled").
			Comment("人工审核开关").
			Default(false).
			Optional().
			Nillable(),
		field.Bool("register_enabled").
			Comment("开放注册开关").
			Default(true).
			Optional().
			Nillable(),
		field.JSON("allowed_video_types", []string{}).
			Comment("允许的视频扩展名").
			Optional(),
	}
}

func (SysConfig) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}
