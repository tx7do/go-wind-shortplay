package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// Notification 站内通知表（点赞 / 评论 / 粉丝 / 系统）
type Notification struct {
	ent.Schema
}

func (Notification) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "notifications",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("站内通知表"),
	}
}

func (Notification) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("user_id").
			Comment("接收人ID").
			Optional().
			Nillable(),
		field.Uint8("type").
			Comment("类型：1 点赞 2 评论 3 粉丝 4 系统").
			Optional().
			Nillable(),
		field.Uint32("sender_id").
			Comment("触发者ID（系统通知为 0）").
			Default(0).
			Optional().
			Nillable(),
		field.Uint32("video_id").
			Comment("关联视频ID").
			Default(0).
			Optional().
			Nillable(),
		field.Uint32("comment_id").
			Comment("关联评论ID").
			Default(0).
			Optional().
			Nillable(),
		field.String("content").
			Comment("通知文案").
			Optional().
			Nillable(),
		field.Bool("is_read").
			Comment("是否已读").
			Default(false).
			Optional().
			Nillable(),
	}
}

func (Notification) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}

func (Notification) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("user_id", "is_read", "created_at"),
	}
}
