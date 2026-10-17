package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoCollect 收藏表
type VideoCollect struct {
	ent.Schema
}

func (VideoCollect) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "video_collects",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("收藏表"),
	}
}

func (VideoCollect) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("user_id").
			Comment("收藏人ID").
			Optional().
			Nillable(),
		field.Uint32("video_id").
			Comment("视频ID").
			Optional().
			Nillable(),
	}
}

func (VideoCollect) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}

func (VideoCollect) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("user_id", "video_id").Unique(),
		index.Fields("video_id"),
	}
}
