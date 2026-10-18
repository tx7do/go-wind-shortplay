package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// UploadTask holds the schema definition for the UploadTask entity.
type UploadTask struct {
	ent.Schema
}

func (UploadTask) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_upload_tasks",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("分片上传任务表"),
	}
}

// Fields of the UploadTask.
func (UploadTask) Fields() []ent.Field {
	return []ent.Field{
		field.String("task_id").
			Comment("任务号（UUID）").
			NotEmpty().
			Unique(),

		field.String("file_name").
			Comment("原始文件名").
			NotEmpty(),

		field.Uint64("file_size").
			Comment("文件大小（字节）").
			Default(0),

		field.Uint32("chunk_size").
			Comment("分片大小（字节）").
			Default(0),

		field.Uint32("total_chunks").
			Comment("总分片数").
			Default(0),

		field.JSON("uploaded_chunks", []uint32{}).
			Comment("已上传分片序号").
			Optional(),

		field.Enum("status").
			Comment("任务状态").
			NamedValues(
				"Uploading", "UPLOADING",
				"Merging", "MERGING",
				"Completed", "COMPLETED",
				"Failed", "FAILED",
			).
			Default("UPLOADING"),

		field.String("file_key").
			Comment("合并后的 MinIO 对象键").
			Optional().
			Nillable(),

		field.Uint32("video_id").
			Comment("关联视频ID").
			Default(0),

		field.Uint32("author_id").
			Comment("上传者用户ID").
			Default(0),
	}
}

// Mixin of the UploadTask.
func (UploadTask) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.TenantID[uint32]{},
	}
}

func (UploadTask) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("author_id", "created_at").
			StorageKey("idx_sp_upload_task_author_created_at"),

		index.Fields("status").
			StorageKey("idx_sp_upload_task_status"),
	}
}
