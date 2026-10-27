package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// SeriesFollow holds the schema definition for the SeriesFollow entity.
type SeriesFollow struct {
	ent.Schema
}

func (SeriesFollow) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sp_series_follows",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("追剧关系表"),
	}
}

// Fields of the SeriesFollow.
func (SeriesFollow) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("follower_id").
			Comment("追剧用户ID").
			Default(0),

		field.Uint32("series_id").
			Comment("剧集ID").
			Default(0),
	}
}

// Mixin of the SeriesFollow.
func (SeriesFollow) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.TenantID[uint32]{},
	}
}

func (SeriesFollow) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("follower_id", "series_id").
			Unique().
			StorageKey("uix_sp_series_follow_pair"),

		index.Fields("series_id").
			StorageKey("idx_sp_series_follow_series"),
	}
}
