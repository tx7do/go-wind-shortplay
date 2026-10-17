package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoDraft 视频草稿表
type VideoDraft struct {
	ent.Schema
}

func (VideoDraft) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "video_drafts",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("视频草稿表"),
	}
}

func (VideoDraft) Fields() []ent.Field {
	return []ent.Field{
		field.String("title").
			Comment("标题").
			Optional().
			Nillable(),
		field.String("description").
			Comment("简介").
			Optional().
			Nillable(),
		field.String("cover_url").
			Comment("封面图地址").
			Optional().
			Nillable(),
		field.String("video_url").
			Comment("视频地址").
			Optional().
			Nillable(),
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
		field.String("upload_task_id").
			Comment("关联上传任务号").
			Optional().
			Nillable(),
		field.Uint32("author_id").
			Comment("作者ID").
			Optional().
			Nillable(),
	}
}

func (VideoDraft) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}

func (VideoDraft) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("author_id"),
	}
}
