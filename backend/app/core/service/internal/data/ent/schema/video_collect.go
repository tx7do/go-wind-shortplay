package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoCollect holds the schema definition for the VideoCollect entity.
type VideoCollect struct {
	ent.Schema
}

func (VideoCollect) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_video_collects",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("收藏台账表"),
	}
}

// Fields of the VideoCollect.
func (VideoCollect) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("user_id").
			Comment("收藏人用户ID").
			Default(0),

		field.Uint32("video_id").
			Comment("视频ID").
			Default(0),
	}
}

// Mixin of the VideoCollect.
func (VideoCollect) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.TenantID[uint32]{},
	}
}

func (VideoCollect) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("user_id", "video_id").
			Unique().
			StorageKey("uix_sp_video_collect_user_video"),

		index.Fields("video_id").
			StorageKey("idx_sp_video_collect_video"),

		index.Fields("user_id", "created_at").
			StorageKey("idx_sp_video_collect_user_created_at"),
	}
}
