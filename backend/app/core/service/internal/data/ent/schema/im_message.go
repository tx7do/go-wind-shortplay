package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// ImMessage holds the schema definition for the ImMessage entity.
type ImMessage struct {
	ent.Schema
}

func (ImMessage) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_im_messages",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("私信消息表"),
	}
}

// Fields of the ImMessage.
func (ImMessage) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("conversation_id").
			Comment("会话ID").
			Default(0),

		field.Uint32("sender_id").
			Comment("发送人用户ID").
			Default(0),

		field.Uint32("receiver_id").
			Comment("接收人用户ID（冗余，按人查询/审计用）").
			Default(0),

		field.Text("content").
			Comment("内容（发送时经长度校验，≤500 字）").
			Default(""),
	}
}

// Mixin of the ImMessage.
func (ImMessage) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.TenantID[uint32]{},
	}
}

func (ImMessage) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("conversation_id", "id").
			StorageKey("idx_sp_im_message_conversation"),

		index.Fields("receiver_id").
			StorageKey("idx_sp_im_message_receiver"),
	}
}
