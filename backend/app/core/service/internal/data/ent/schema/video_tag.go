package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoTag holds the schema definition for the VideoTag entity.
type VideoTag struct {
	ent.Schema
}

func (VideoTag) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_video_tags",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("短视频标签表"),
	}
}

// Fields of the VideoTag.
func (VideoTag) Fields() []ent.Field {
	return []ent.Field{
		field.String("name").
			Comment("标签名").
			NotEmpty().
			Unique(),

		field.Uint64("video_count").
			Comment("引用视频数").
			Default(0),
	}
}

// Mixin of the VideoTag.
func (VideoTag) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.OperatorID{},
		mixin.TenantID[uint32]{},
	}
}

func (VideoTag) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("video_count").
			StorageKey("idx_sp_video_tag_video_count"),
	}
}
