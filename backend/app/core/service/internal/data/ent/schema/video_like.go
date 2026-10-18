package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoLike holds the schema definition for the VideoLike entity.
// 点赞台账：一行 = 一次点赞事实；计数列只允许在本表事务内随行增减。
type VideoLike struct {
	ent.Schema
}

func (VideoLike) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_video_likes",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("点赞台账表"),
	}
}

// Fields of the VideoLike.
func (VideoLike) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("user_id").
			Comment("点赞人用户ID").
			Default(0),

		field.Enum("target_type").
			Comment("目标类型").
			NamedValues(
				"Video", "VIDEO",
				"Comment", "COMMENT",
			).
			Default("VIDEO"),

		field.Uint32("target_id").
			Comment("目标ID").
			Default(0),
	}
}

// Mixin of the VideoLike.
func (VideoLike) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.TenantID[uint32]{},
	}
}

func (VideoLike) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("user_id", "target_type", "target_id").
			Unique().
			StorageKey("uix_sp_video_like_user_target"),

		index.Fields("target_type", "target_id").
			StorageKey("idx_sp_video_like_target"),
	}
}
