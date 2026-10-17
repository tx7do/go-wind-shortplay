package data

import (
	"context"

	passCrypto "github.com/tx7do/go-utils/password"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	entCrud "github.com/tx7do/go-crud/entgo"

	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/user"
)

// UserRepo 用户仓储
type UserRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper
}

func NewUserRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *UserRepo {
	return &UserRepo{
		entClient: entClient,
		log:       ctx.NewLoggerHelper("user/repo/core-service"),
	}
}

func (r *UserRepo) Client() *ent.Client {
	return r.entClient.Client()
}

func (r *UserRepo) GetByID(ctx context.Context, id uint32) (*ent.User, error) {
	return r.Client().User.Query().Where(user.ID(id)).Only(ctx)
}

func (r *UserRepo) GetByUsername(ctx context.Context, username string) (*ent.User, error) {
	return r.Client().User.Query().Where(user.Username(username)).Only(ctx)
}

func (r *UserRepo) ExistUsername(ctx context.Context, username string) (bool, error) {
	return r.Client().User.Query().Where(user.Username(username)).Exist(ctx)
}

// List 分页查询用户（支持关键字模糊匹配用户名 / 昵称）
func (r *UserRepo) List(ctx context.Context, offset, limit int, keyword string) ([]*ent.User, int, error) {
	q := r.Client().User.Query()
	if keyword != "" {
		q = q.Where(user.Or(
			user.UsernameContains(keyword),
			user.NicknameContains(keyword),
		))
	}
	total, err := q.Count(ctx)
	if err != nil {
		return nil, 0, err
	}
	items, err := q.Order(ent.Desc(user.FieldID)).Offset(offset).Limit(limit).All(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

func (r *UserRepo) Create(ctx context.Context, username, passwordHash, nickname string) (*ent.User, error) {
	return r.Client().User.Create().
		SetUsername(username).
		SetNillablePasswordHash(&passwordHash).
		SetNickname(nickname).
		SetStatus(uint8(identityV1.UserStatus_USER_STATUS_NORMAL)).
		Save(ctx)
}

// Update 更新用户资料；passwordHash 为 nil 表示不改密码
func (r *UserRepo) Update(ctx context.Context, id uint32, nickname, avatarURL, bio *string, passwordHash *string) (*ent.User, error) {
	u := r.Client().User.UpdateOneID(id).
		SetNillableNickname(nickname).
		SetNillableAvatarURL(avatarURL).
		SetNillableBio(bio).
		SetNillablePasswordHash(passwordHash)
	return u.Save(ctx)
}

func (r *UserRepo) UpdateStatus(ctx context.Context, id uint32, status uint8) (*ent.User, error) {
	return r.Client().User.UpdateOneID(id).SetStatus(status).Save(ctx)
}

func (r *UserRepo) Delete(ctx context.Context, id uint32) error {
	return r.Client().User.DeleteOneID(id).Exec(ctx)
}

// EnsureSeedAdmin 首次启动且无任何用户时，播种管理员账号 admin/admin。
// 生产环境务必登录后立即改密。
func (r *UserRepo) EnsureSeedAdmin(ctx context.Context) error {
	n, err := r.Client().User.Query().Count(ctx)
	if err != nil {
		return err
	}
	if n > 0 {
		return nil
	}
	crypto, err := passCrypto.CreateCrypto("argon2")
	if err != nil {
		return err
	}
	hash, err := crypto.Encrypt("admin")
	if err != nil {
		return err
	}
	if _, err := r.Create(ctx, "admin", hash, "管理员"); err != nil {
		return err
	}
	r.log.Warn("seeded default admin account: admin/admin — CHANGE THE PASSWORD IN PRODUCTION")
	return nil
}
