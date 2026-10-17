package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// UserFollow 用户关注关系表
type UserFollow struct {
	ent.Schema
}

func (UserFollow) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "user_follows",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("用户关注关系表"),
	}
}

func (UserFollow) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("follower_id").
			Comment("关注人ID").
			Optional().
			Nillable(),
		field.Uint32("followee_id").
			Comment("被关注人ID").
			Optional().
			Nillable(),
	}
}

func (UserFollow) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}

func (UserFollow) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("follower_id", "followee_id").Unique(),
		index.Fields("followee_id"),
	}
}
