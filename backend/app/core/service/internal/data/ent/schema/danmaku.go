package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// Danmaku holds the schema definition for the Danmaku entity.
type Danmaku struct {
	ent.Schema
}

func (Danmaku) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_danmaku",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("视频弹幕表"),
	}
}

// Fields of the Danmaku.
func (Danmaku) Fields() []ent.Field {
	return []ent.Field{
		field.Int64("video_id").
			Comment("视频ID").
			Default(0),

		field.Int64("user_id").
			Comment("发送人用户ID").
			Default(0),

		field.Text("content").
			Comment("内容（发送时经敏感词过滤，≤100 字）").
			Default(""),

		field.Uint64("time_offset_ms").
			Comment("视频时间轴偏移（毫秒）").
			Default(0),

		field.Enum("status").
			Comment("状态（管理端隐藏/恢复）").
			NamedValues(
				"Visible", "DANMAKU_STATUS_VISIBLE",
				"Hidden", "DANMAKU_STATUS_HIDDEN",
			).
			Default("DANMAKU_STATUS_VISIBLE"),
	}
}

// Mixin of the Danmaku.
func (Danmaku) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId64{},
		mixin.TimeAt{},
		mixin.TenantID[int64]{},
	}
}

func (Danmaku) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("video_id", "status").
			StorageKey("idx_sp_danmaku_video_status"),

		index.Fields("user_id").
			StorageKey("idx_sp_danmaku_user"),
	}
}
