package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoLike 点赞流水表（视频 / 评论通用 ledger）
type VideoLike struct {
	ent.Schema
}

func (VideoLike) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "video_likes",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("点赞流水表"),
	}
}

func (VideoLike) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("user_id").
			Comment("点赞人ID").
			Optional().
			Nillable(),
		field.Uint8("target_type").
			Comment("目标类型：1 视频 2 评论").
			Optional().
			Nillable(),
		field.Uint32("target_id").
			Comment("目标ID").
			Optional().
			Nillable(),
	}
}

func (VideoLike) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}

func (VideoLike) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("user_id", "target_type", "target_id").Unique(),
		index.Fields("target_type", "target_id"),
	}
}
