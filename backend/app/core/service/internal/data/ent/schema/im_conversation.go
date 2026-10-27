package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// ImConversation holds the schema definition for the ImConversation entity.
// 1:1 会话：participant_a_id 恒为较小用户 ID、participant_b_id 恒为较大，
// 成对唯一由服务端归一化保证（幂等建会话）。
type ImConversation struct {
	ent.Schema
}

func (ImConversation) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_im_conversations",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("私信会话表"),
	}
}

// Fields of the ImConversation.
func (ImConversation) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("participant_a_id").
			Comment("参与方A（较小用户ID）").
			Default(0),

		field.Uint32("participant_b_id").
			Comment("参与方B（较大用户ID）").
			Default(0),

		field.String("last_message_preview").
			Comment("最近一条消息预览（列表展示冗余）").
			Default(""),

		field.Time("last_message_at").
			Comment("最近消息时间（空会话为空）").
			Optional().
			Nillable(),

		field.Uint64("a_unread_count").
			Comment("A 侧未读数（B 发消息递增，A 已读清零）").
			Default(0),

		field.Uint64("b_unread_count").
			Comment("B 侧未读数（A 发消息递增，B 已读清零）").
			Default(0),
	}
}

// Mixin of the ImConversation.
func (ImConversation) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.TenantID[uint32]{},
	}
}

func (ImConversation) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("participant_a_id", "participant_b_id").
			Unique().
			StorageKey("uix_sp_im_conversation_pair"),

		index.Fields("participant_a_id", "last_message_at").
			StorageKey("idx_sp_im_conversation_a"),

		index.Fields("participant_b_id", "last_message_at").
			StorageKey("idx_sp_im_conversation_b"),
	}
}
