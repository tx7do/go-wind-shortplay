package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// VideoReport 举报工单表
type VideoReport struct {
	ent.Schema
}

func (VideoReport) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "video_reports",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("举报工单表"),
	}
}

func (VideoReport) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("reporter_id").
			Comment("举报人ID").
			Optional().
			Nillable(),
		field.Uint8("target_type").
			Comment("目标类型：1 视频 2 评论 3 用户").
			Optional().
			Nillable(),
		field.Uint32("target_id").
			Comment("目标ID").
			Optional().
			Nillable(),
		field.String("reason").
			Comment("举报原因（枚举码）").
			NotEmpty(),
		field.String("description").
			Comment("补充说明").
			Optional().
			Nillable(),
		field.Uint8("status").
			Comment("状态：1 待处理 2 已通过 3 已驳回").
			Default(1).
			Optional().
			Nillable(),
		field.Uint32("handled_by").
			Comment("处理人（管理员ID）").
			Optional().
			Nillable(),
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

func (VideoReport) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}

func (VideoReport) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("status", "created_at"),
		index.Fields("target_type", "target_id"),
	}
}
