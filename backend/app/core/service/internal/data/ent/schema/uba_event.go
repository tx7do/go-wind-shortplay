package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// UbaEvent holds the schema definition for the UbaEvent entity.
type UbaEvent struct {
	ent.Schema
}

func (UbaEvent) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_uba_events",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("UBA 行为事件表"),
	}
}

// Fields of the UbaEvent.
func (UbaEvent) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("user_id").
			Comment("行为人用户ID（游客为0）").
			Default(0),

		field.Enum("event_type").
			Comment("事件类型").
			NamedValues(
				"VideoPlay", "VIDEO_PLAY",
				"VideoHeartbeat", "VIDEO_HEARTBEAT",
				"VideoComplete", "VIDEO_COMPLETE",
				"VideoSwipeAway", "VIDEO_SWIPE_AWAY",
				"VideoLike", "VIDEO_LIKE",
				"VideoCollect", "VIDEO_COLLECT",
				"CommentCreate", "COMMENT_CREATE",
				"FollowAuthor", "FOLLOW_AUTHOR",
			).
			Default("VIDEO_PLAY"),

		field.Uint32("video_id").
			Comment("视频ID（非视频事件为0）").
			Default(0),

		field.Uint32("target_user_id").
			Comment("对方用户ID（关注事件）").
			Default(0),

		field.Uint64("duration_ms").
			Comment("观看时长（毫秒）").
			Default(0),

		field.Uint32("watch_percent").
			Comment("观看进度百分比（0-100）").
			Default(0),

		field.String("extra").
			Comment("扩展参数（JSON 字符串）").
			Optional().
			Nillable(),

		field.Time("occurred_at").
			Comment("发生时间").
			Optional().
			Nillable(),
	}
}

// Mixin of the UbaEvent.
func (UbaEvent) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.TenantID[uint32]{},
	}
}

func (UbaEvent) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("event_type", "occurred_at").
			StorageKey("idx_sp_uba_event_type_occurred_at"),

		index.Fields("video_id", "event_type").
			StorageKey("idx_sp_uba_video_event"),
	}
}
