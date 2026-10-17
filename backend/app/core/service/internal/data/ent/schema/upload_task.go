package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// UploadTask 分片上传任务表
type UploadTask struct {
	ent.Schema
}

func (UploadTask) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "upload_tasks",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("分片上传任务表"),
	}
}

func (UploadTask) Fields() []ent.Field {
	return []ent.Field{
		field.String("task_id").
			Comment("任务号（UUID）").
			Unique().
			NotEmpty(),
		field.String("file_name").
			Comment("原始文件名").
			NotEmpty(),
		field.Int64("file_size").
			Comment("文件大小（字节）").
			Default(0).
			Optional().
			Nillable(),
		field.Uint32("chunk_size").
			Comment("分片大小（字节）").
			Default(0).
			Optional().
			Nillable(),
		field.Uint32("total_chunks").
			Comment("总分片数").
			Default(0).
			Optional().
			Nillable(),
		field.JSON("uploaded_chunks", []uint32{}).
			Comment("已上传分片序号").
			Optional(),
		field.Uint8("status").
			Comment("状态：1 上传中 2 合并中 3 完成 4 失败").
			Default(1).
			Optional().
			Nillable(),
		field.String("file_key").
			Comment("合并后的 MinIO 对象键").
			Optional().
			Nillable(),
		field.Uint32("video_id").
			Comment("关联视频ID").
			Default(0).
			Optional().
			Nillable(),
		field.Uint32("author_id").
			Comment("上传人ID").
			Optional().
			Nillable(),
	}
}

func (UploadTask) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}

func (UploadTask) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("author_id"),
	}
}
