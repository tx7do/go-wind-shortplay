package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/tx7do/go-crud/entgo/mixin"
)

// User 用户表（开源版内置账号体系，弱化多租户）
type User struct {
	ent.Schema
}

func (User) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "users",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("用户表"),
	}
}

func (User) Fields() []ent.Field {
	return []ent.Field{
		field.String("username").
			Comment("登录名").
			Unique().
			NotEmpty(),
		field.String("password_hash").
			Comment("密码哈希（bcrypt）").
			Sensitive().
			Optional().
			Nillable(),
		field.String("nickname").
			Comment("昵称").
			NotEmpty(),
		field.String("avatar_url").
			Comment("头像地址").
			Optional().
			Nillable(),
		field.String("bio").
			Comment("个人简介").
			Optional().
			Nillable(),
		field.Uint8("status").
			Comment("状态：1 禁用 2 正常").
			Default(2).
			Optional().
			Nillable(),
	}
}

func (User) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
	}
}

func (User) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("status"),
	}
}
