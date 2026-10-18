package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// UserFollow holds the schema definition for the UserFollow entity.
type UserFollow struct {
	ent.Schema
}

func (UserFollow) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_user_follows",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("关注关系表"),
	}
}

// Fields of the UserFollow.
func (UserFollow) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("follower_id").
			Comment("关注人用户ID").
			Default(0),

		field.Uint32("followee_id").
			Comment("被关注人用户ID").
			Default(0),
	}
}

// Mixin of the UserFollow.
func (UserFollow) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.TenantID[uint32]{},
	}
}

func (UserFollow) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("follower_id", "followee_id").
			Unique().
			StorageKey("uix_sp_user_follow_pair"),

		index.Fields("followee_id").
			StorageKey("idx_sp_user_follow_followee"),
	}
}
