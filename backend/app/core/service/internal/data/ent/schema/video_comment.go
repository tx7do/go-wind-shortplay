package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoComment 评论表（开源版单级；parent_id 预留楼中楼）
type VideoComment struct {
	ent.Schema
}

func (VideoComment) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "video_comments",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("评论表"),
	}
}

func (VideoComment) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("video_id").
			Comment("视频ID").
			Optional().
			Nillable(),
		field.Uint32("user_id").
			Comment("评论人ID").
			Optional().
			Nillable(),
		field.String("content").
			Comment("评论内容").
			NotEmpty(),
		field.Uint32("parent_id").
			Comment("父评论ID（Phase 2 楼中楼）").
			Default(0).
			Optional().
			Nillable(),
		field.Int64("like_count").
			Comment("点赞数").
			Default(0).
			Optional().
			Nillable(),
		field.Int64("reply_count").
			Comment("回复数（仅一级评论维护）").
			Default(0).
			Optional().
			Nillable(),
	}
}

func (VideoComment) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}

func (VideoComment) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("video_id", "created_at"),
		index.Fields("user_id"),
	}
}
