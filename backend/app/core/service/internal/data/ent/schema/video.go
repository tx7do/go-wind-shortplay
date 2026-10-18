package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// Video holds the schema definition for the Video entity.
type Video struct {
	ent.Schema
}

func (Video) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_videos",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("短视频表"),
	}
}

// Fields of the Video.
func (Video) Fields() []ent.Field {
	return []ent.Field{
		field.String("title").
			Comment("标题").
			NotEmpty(),

		field.String("description").
			Comment("简介").
			Optional().
			Nillable(),

		field.String("cover_url").
			Comment("封面图").
			Optional().
			Nillable(),

		field.String("video_url").
			Comment("视频播放地址").
			Optional().
			Nillable(),

		field.Uint32("duration").
			Comment("时长（秒）").
			Default(0),

		field.Uint32("width").
			Comment("分辨率宽").
			Default(0),

		field.Uint32("height").
			Comment("分辨率高").
			Default(0),

		field.Enum("status").
			Comment("状态：DRAFT草稿 REVIEWING审核中 PUBLISHED已发布 REJECTED驳回 OFFLINE下架").
			NamedValues(
				"Draft", "DRAFT",
				"Reviewing", "REVIEWING",
				"Published", "PUBLISHED",
				"Rejected", "REJECTED",
				"Offline", "OFFLINE",
			).
			Default("DRAFT"),

		field.Uint32("author_id").
			Comment("作者用户ID").
			Default(0),

		field.String("reject_reason").
			Comment("驳回原因").
			Optional().
			Nillable(),

		field.Uint64("like_count").
			Comment("点赞数（ledger 事务内增减，禁止直接 Set 覆盖）").
			Default(0),

		field.Uint64("collect_count").
			Comment("收藏数（ledger 事务内增减）").
			Default(0),

		field.Uint64("comment_count").
			Comment("评论数（ledger 事务内增减）").
			Default(0),

		field.Uint64("view_count").
			Comment("播放量（ledger 事务内增减）").
			Default(0),

		field.Time("published_at").
			Comment("发布时间").
			Optional().
			Nillable(),
	}
}

// Mixin of the Video.
func (Video) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.OperatorID{},
		mixin.TenantID[uint32]{},
	}
}

func (Video) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("status", "published_at").
			StorageKey("idx_sp_video_status_published_at"),

		index.Fields("author_id", "status").
			StorageKey("idx_sp_video_author_status"),

		index.Fields("tenant_id", "status").
			StorageKey("idx_sp_video_tenant_status"),
	}
}
