package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// Video 视频主表（元数据 / 状态 / 作者 / 存储地址）
type Video struct {
	ent.Schema
}

func (Video) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "videos",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("视频主表"),
	}
}

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
			Comment("封面图地址").
			Optional().
			Nillable(),
		field.String("video_url").
			Comment("视频播放地址（MinIO 对象键或完整 URL）").
			NotEmpty(),
		field.Uint32("duration").
			Comment("时长（秒）").
			Default(0).
			Optional().
			Nillable(),
		field.Uint32("width").
			Comment("分辨率宽").
			Default(0).
			Optional().
			Nillable(),
		field.Uint32("height").
			Comment("分辨率高").
			Default(0).
			Optional().
			Nillable(),
		field.Uint8("status").
			Comment("状态：1 草稿 2 审核中 3 已发布 4 驳回 5 下架").
			Default(3).
			Optional().
			Nillable(),
		field.Uint32("author_id").
			Comment("作者ID").
			Optional().
			Nillable(),
		field.String("reject_reason").
			Comment("驳回原因").
			Optional().
			Nillable(),
		// 计数缓存列：Redis 为准，异步批量回写
		field.Int64("like_count").
			Comment("点赞数").
			Default(0).
			Optional().
			Nillable(),
		field.Int64("collect_count").
			Comment("收藏数").
			Default(0).
			Optional().
			Nillable(),
		field.Int64("comment_count").
			Comment("评论数").
			Default(0).
			Optional().
			Nillable(),
		field.Int64("view_count").
			Comment("播放量").
			Default(0).
			Optional().
			Nillable(),
		field.Time("published_at").
			Comment("发布时间").
			Optional().
			Nillable(),
	}
}

func (Video) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}

func (Video) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("author_id"),
		index.Fields("status", "published_at"),
		index.Fields("status", "like_count"),
		index.Fields("status", "view_count"),
	}
}
