package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// UbaEvent 用户行为埋点事件表（观看时长 / 完播 / 划走 / 互动）
type UbaEvent struct {
	ent.Schema
}

func (UbaEvent) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "uba_events",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("用户行为埋点事件表"),
	}
}

func (UbaEvent) Fields() []ent.Field {
	return []ent.Field{
		field.Uint8("event_type").
			Comment("事件类型，对应 uba.EventType 枚举").
			Optional().
			Nillable(),
		field.Uint32("video_id").
			Comment("视频ID（非视频事件为 0）").
			Default(0).
			Optional().
			Nillable(),
		field.Uint32("user_id").
			Comment("用户ID（游客为 0）").
			Default(0).
			Optional().
			Nillable(),
		field.Uint32("target_user_id").
			Comment("对方用户ID（关注事件）").
			Default(0).
			Optional().
			Nillable(),
		field.Int64("duration_ms").
			Comment("观看时长（毫秒）").
			Default(0).
			Optional().
			Nillable(),
		field.Uint32("watch_percent").
			Comment("观看进度百分比（0-100）").
			Default(0).
			Optional().
			Nillable(),
		field.String("extra").
			Comment("扩展参数（JSON）").
			Optional().
			Nillable(),
		field.Time("occurred_at").
			Comment("发生时间").
			Optional().
			Nillable(),
	}
}

func (UbaEvent) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.CreatedAt{},
	}
}

func (UbaEvent) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("video_id", "event_type"),
		index.Fields("user_id", "created_at"),
	}
}
