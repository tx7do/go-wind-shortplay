package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoTagRel holds the schema definition for the VideoTagRel entity.
type VideoTagRel struct {
	ent.Schema
}

func (VideoTagRel) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_video_tag_rels",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("短视频-标签关联表"),
	}
}

// Fields of the VideoTagRel.
func (VideoTagRel) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("video_id").
			Comment("视频ID").
			Default(0),

		field.Uint32("tag_id").
			Comment("标签ID").
			Default(0),
	}
}

// Mixin of the VideoTagRel.
func (VideoTagRel) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.TenantID[uint32]{},
	}
}

func (VideoTagRel) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("video_id").
			StorageKey("idx_sp_video_tag_rel_video"),

		index.Fields("tag_id", "video_id").
			Unique().
			StorageKey("uix_sp_video_tag_rel_tag_video"),
	}
}
