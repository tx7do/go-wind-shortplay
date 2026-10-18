package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoComment holds the schema definition for the VideoComment entity.
// 短视频评论：与基座 CMS 泛型 comment 域（object_id + 游客作者模型）分开另建，
// 目标恒为视频、作者恒为登录用户，计数随 video.comment_count 台账联动。
type VideoComment struct {
	ent.Schema
}

func (VideoComment) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_video_comments",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("短视频评论表"),
	}
}

// Fields of the VideoComment.
func (VideoComment) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("video_id").
			Comment("视频ID").
			Default(0),

		field.Uint32("user_id").
			Comment("评论人用户ID").
			Default(0),

		field.Text("content").
			Comment("内容").
			Default(""),

		field.Uint32("parent_id").
			Comment("父评论ID（0=一级评论）").
			Default(0),

		field.Uint64("like_count").
			Comment("点赞数（ledger 事务内增减）").
			Default(0),

		field.Uint64("reply_count").
			Comment("回复数（仅一级评论维护）").
			Default(0),
	}
}

// Mixin of the VideoComment.
func (VideoComment) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.OperatorID{},
		mixin.TenantID[uint32]{},
	}
}

func (VideoComment) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("video_id", "created_at").
			StorageKey("idx_sp_video_comment_video_created_at"),

		index.Fields("parent_id").
			StorageKey("idx_sp_video_comment_parent"),
	}
}
