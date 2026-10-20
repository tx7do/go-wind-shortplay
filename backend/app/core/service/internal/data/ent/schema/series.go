package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// Series holds the schema definition for the Series entity.
type Series struct {
	ent.Schema
}

func (Series) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_series",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("剧集表（短剧多集容器，可见性跟随其视频审核状态）"),
	}
}

// Fields of the Series.
func (Series) Fields() []ent.Field {
	return []ent.Field{
		field.String("title").
			Comment("剧名").
			NotEmpty(),

		field.String("description").
			Comment("剧简介").
			Optional().
			Nillable(),

		field.String("cover_url").
			Comment("封面图（可空，展示侧回退第一集封面）").
			Optional().
			Nillable(),

		field.Uint32("author_id").
			Comment("作者用户ID").
			Default(0),
	}
}

// Mixin of the Series.
func (Series) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.OperatorID{},
		mixin.TenantID[uint32]{},
	}
}

func (Series) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("author_id").
			StorageKey("idx_sp_series_author"),
	}
}
