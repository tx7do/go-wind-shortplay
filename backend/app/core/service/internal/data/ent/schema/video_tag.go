package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoTag 视频标签表
type VideoTag struct {
	ent.Schema
}

func (VideoTag) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "video_tags",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("视频标签表"),
	}
}

func (VideoTag) Fields() []ent.Field {
	return []ent.Field{
		field.String("name").
			Comment("标签名").
			Unique().
			NotEmpty(),
		field.Int64("video_count").
			Comment("引用视频数").
			Default(0).
			Optional().
			Nillable(),
	}
}

func (VideoTag) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}
