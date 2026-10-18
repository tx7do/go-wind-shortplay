package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoReport holds the schema definition for the VideoReport entity.
type VideoReport struct {
	ent.Schema
}

func (VideoReport) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_video_reports",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("举报工单表"),
	}
}

// Fields of the VideoReport.
func (VideoReport) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("reporter_id").
			Comment("举报人用户ID").
			Default(0),

		field.Enum("target_type").
			Comment("目标类型").
			NamedValues(
				"Video", "VIDEO",
				"Comment", "COMMENT",
				"User", "USER",
			).
			Default("VIDEO"),

		field.Uint32("target_id").
			Comment("目标ID").
			Default(0),

		field.String("reason").
			Comment("举报原因（枚举码）").
			NotEmpty(),

		field.String("description").
			Comment("补充说明").
			Optional().
			Nillable(),

		field.Enum("status").
			Comment("工单状态").
			NamedValues(
				"Pending", "PENDING",
				"Resolved", "RESOLVED",
				"Dismissed", "DISMISSED",
			).
			Default("PENDING"),

		field.Uint32("handled_by").
			Comment("处理人（管理员）").
			Default(0),

		field.String("handle_note").
			Comment("处理备注").
			Optional().
			Nillable(),

		field.Time("handled_at").
			Comment("处理时间").
			Optional().
			Nillable(),
	}
}

// Mixin of the VideoReport.
func (VideoReport) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.OperatorID{},
		mixin.TenantID[uint32]{},
	}
}

func (VideoReport) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("status", "created_at").
			StorageKey("idx_sp_video_report_status_created_at"),

		index.Fields("target_type", "target_id").
			StorageKey("idx_sp_video_report_target"),

		index.Fields("reporter_id").
			StorageKey("idx_sp_video_report_reporter"),
	}
}
