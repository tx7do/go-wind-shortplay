package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoTagRel 视频标签关联表
type VideoTagRel struct {
	ent.Schema
}

func (VideoTagRel) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "video_tag_rels",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("视频标签关联表"),
	}
}

func (VideoTagRel) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("video_id").
			Comment("视频ID").
			Optional().
			Nillable(),
		field.Uint32("tag_id").
			Comment("标签ID").
			Optional().
			Nillable(),
	}
}

func (VideoTagRel) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}

func (VideoTagRel) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("video_id", "tag_id").Unique(),
		index.Fields("tag_id"),
	}
}
