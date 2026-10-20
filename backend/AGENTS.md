# AGENTS.md — 后端开发指南（go-wind-shortplay）

> 本文件是 backend 子项目的 AI 编码规范单一事实源，适用于所有支持 AGENTS.md 的 AI 编码工具（ZCode、GitHub Copilot、Cursor、Codex、Gemini CLI 等）。Claude Code 通过同级 `CLAUDE.md` 中的 `@AGENTS.md` 引用加载。

## 本仓后端的来历：基于 go-wind-cms 基座源码重建（2026-10-18）

本 backend 以 [go-wind-cms](https://github.com/tx7do/go-wind-cms) 的 `backend/` 源码为底整体重建（提交 18691a9），随后在其上移植 shortplay 业务域并完成多轮收尾（基座缺陷收尾 4e21f6b → A 类功能闭环 babc285 → B 类健壮性收尾 7bc6148 → 开源发布准备 7f02940 / 站内信租户归属修复 7dcf4ad）。基座基建域保持与上游源码同构，裁剪 CMS 内容类业务域。与基座的取证比对方法与偏离清单见 [docs/UPSTREAM.md](../docs/UPSTREAM.md)。

**与基座的差异（同步上游时注意保留，完整清单见 UPSTREAM.md §2.4）**：

1. **module 名**：`go-wind-shortplay`（基座 `go-wind-cms`）；`pkg/serviceid.ProjectName = "gowind-shortplay"`（验证码 Redis 键前缀 `gowind-shortplay:captcha:<id>` 等）。
2. **端口**：admin REST `:7600`（SSE `:7601`）、app REST `:7700`（SSE `:7701`）、core gRPC `:7900`（基座 6600/6601、6700/6701、随机）。config 已支持 `${ADMIN_REST_ADDR}` 等环境变量覆盖。
3. **数据指向**：外部容器——PostgreSQL `127.0.0.1:5432` 库 `shortplay`（user `postgres`）、Redis `127.0.0.1:6379`（db2 给 asynq）、MinIO `127.0.0.1:9000`；全部支持 `${ENV:default}` 覆盖（`DB_HOST` / `REDIS_ADDR` / `OSS_ENDPOINT` 等）。注册中心用 etcd `localhost:2379`（三服务 gRPC 互相发现）。
4. **裁剪**：CMS 内容类业务域整体移除（ai / content / site / social / flow / translator / webhook，清单见下节），并新增 shortplay 业务域（video / feed / report / sysconf / uba + identity 域裁剪版承载用户）。
5. **新增基础设施**（基座没有，同步时勿被覆盖）：
   - `pkg/configenv/`——环境变量覆盖链路：注册名为 `env` 的配置源工厂，使各服务 `configs/*.yaml` 的 `${VAR:default}` 按「环境变量优先、缺省值兜底」解析（基座只注册 file source，环境变量默认不生效）；`OverrideAESKeyFromEnv()` 提供 `AES_KEY` 环境变量统一覆盖登录密码传输加密密钥（基座代码路径直引 `crypto.DefaultAESKey` 包级变量，配置文件的 `aes_key` 不参与解密）。三服务 `main.go` 启动时调用该钩子；各服务 `configs/config.yaml` 声明 `config: { type: env }` 启用。
   - `backend/.env` 装载——`app.mk` 顶部 `include` 并 `export` `backend/.env`（模板 `.env.example`，已 gitignore），配合 configenv 使 `make run` / `make build` / `make test` 无需手工 source 环境变量；docker compose 另行读取同文件做 `${VAR}` 插值。
   - `.golangci.yml`——本仓自建 lint 配置（v2 格式）：`default: standard`，排除 `api/gen`、`internal/data/ent(etest)`、`*.pb.go` 生成代码；`_test.go` 放宽 errcheck/ineffassign。基座无此文件。
   - sp-biz 站内信跳转标记约定——`internal/service/report_service.go` 的 `spBizMarkerPrefix`：机器可读跳转载荷以独立尾行 `sp-biz:{...}` 追加在站内信 content 末尾（视频类为 `sp-biz:{"videoId":<id>}`），客户端解析后剔除；无标记/解析失败一律按普通文本处理（向后兼容）。
   - `GET /admin/v1/navigation`——shortplay 自定义动态菜单契约（自定义 JSON 形状，手工路由 + handler 内显式验 Bearer，`navigation_service.go`），供 admin 前端动态路由消费；基座原生 `GET /admin/v1/routes` 同时保留。
   - app BFF `/auth/*` 兼容层——`app/service/internal/service/authentication_service.go` 的 `AuthLogin/AuthRegister/AuthRefresh/AuthLogout`：登录/注册免验证码、密码 AES 密文入参（注册侧先解密再 bcrypt 落库）、注册租户由服务端强制为 `constants.DefaultTenantCode`（客户端传入不可信）、开放注册开关由 sysconf 把关；刷新按 refreshToken 值反查 Redis 绑定键 `gwc:rt:{ct}:{uid}:{jti}` 后走 core 标准轮换。另有手工挂载的 `POST /app/v1/register`（core RegisterUser 直连）。
   - `app/core/service/internal/data/business_tenant.go`——业务行租户归属：视频/互动/评论/关注/举报/埋点/上传任务等业务数据必须挂在具名租户（缺省 `shortplay`）下；平台/系统上下文（无租户语义）缺省归 shortplay 租户，避免业务行落 tenant_id=0 成为租户用户的孤儿数据；C 端租户用户仍由基座 TenantPrivacy 强制覆盖。
   - asynq 队列 URI 单层插值 `${ASYNQ_REDIS_URI:...}`（密码内嵌无法嵌套引用 `${REDIS_PASSWORD}`），换环境改 `backend/.env` 的 `ASYNQ_REDIS_URI` 整体值。

## 域清单

proto 域共 **22 个**（`api/protos/<domain>/service/v1/`）：

| 类别 | 域 |
|---|---|
| 基座基建域（14，与基座同构） | identity · permission · authentication · audit · dict · media · storage · task · notify · internal_message · conf · comment(target 泛型表承载) · admin(BFF) · app(BFF) |
| shortplay 业务域（8，基座没有或按 shortplay 重写） | video · series(剧集：剧 CRUD/选集浏览/挂靠，可见性跟随视频) · feed · report · sysconf · uba · interaction(点赞/收藏/关注 ledger，视频/评论 target) · stats(DashboardService：总览/趋势/TOP10/创作者与用户统计) |

- **identity**：user（shortplay 裁剪版字段）+ 基座租户/组织（tenant / org_unit / position / membership 4 表 / user_credential / login_policy）；shortplay 用户管理与 C 端用户由 identity 域承载。
- **comment**：基座 target 泛型评论表（`comments`，object_id 承载 videoId）+ shortplay `sp_video_comments`；admin 评论管理、app 视频评论均经 comment 域。
- **interaction**：点赞/收藏/关注 ledger（基座泛型 ledger 表），Like/Unlike/Collect/Uncollect/Follow/Unfollow/GetInteractionStatus/ListCollectedVideos/ListFollowing/ListFollowers。
- **业务权限码**：`pkg/constants/permission.go`——`biz:video_manage` / `biz:comment_manage` / `biz:report_manage` / `biz:user_manage` / `biz:sysconf_manage`；系统码 `sys:access_backend` / `sys:access_app` / `sys:platform_admin` / `sys:tenant_manager` / `sys:manage_tenants` / `sys:audit_logs`。

**裁剪域清单（基座有而本仓未采纳，同步上游时跳过）**：ai、content（post/page/category/tag/section/…全量）、site、social、flow、translator、webhook，及配套 `pkg/{ai,content,social,lua,translator,eventbus}`、graphql/mcp/collab 等 server。`pkg/mailer` 保留（通知域 Email 渠道在用）。

## 项目概览

基于 [go-kratos v2](https://github.com/go-kratos/kratos) 的多租户微服务后端，Protobuf-first（契约驱动）工作流。

**核心技术栈**：go-kratos v2.9.2（HTTP+gRPC+SSE）· Go 1.26 · ent v0.14（privacy/entql/sql-modifier/upsert/lock 五 feature）· 手写装配（wiring.go，无 DI 框架）· PostgreSQL（pgx/v5）· Redis · Asynq · JWT(HS256)+Casbin 鉴权 · MinIO · etcd 服务发现 · zap 日志。

## 三服务架构

```
HTTP/REST 请求
  └─ admin-service  (后台网关 BFF，REST:7600 / SSE:7601 / gRPC)
       └─ gRPC(etcd 发现) → core-service  (核心业务 + 数据落点, gRPC:7900)
                 ├─ ent ORM → PostgreSQL
                 ├─ Redis / MinIO
                 └─ Asynq 异步任务

app-service (前台 BFF，REST:7700 / SSE:7701) ──gRPC──→ core-service
```

| 服务 | 角色 | 访问 DB |
|------|------|:---:|
| `app/admin/service` | 后台网关 BFF（参数校验 + gRPC 转发） | ❌ |
| `app/app/service` | 前台网关 BFF | ❌ |
| `app/core/service` | 核心业务实现（持久化、真实逻辑） | ✅ |

**令牌按 BFF 隔离**：admin / app 各以自己的 `ClientType`（`ClientType_admin` / `ClientType_app`）签发与校验令牌（Redis 缓存键含 clientType），一端签发的 token 在另一端 401。

## 目录结构

```
backend/
├── api/
│   ├── protos/<domain>/service/v1/   # ★ proto 源（21 域，人工维护）
│   ├── gen/go/                       # ← buf generate 产物（禁止手改）
│   └── buf.gen.yaml 等               # 生成模板（go/grpc/http/errors/validate/redact + openapi/ts/dart）
├── app/<admin|app|core>/service/
│   ├── cmd/server/main.go + wiring.go  # ★ 入口（含 configenv AES 钩子）+ 手写装配
│   ├── configs/                      # server/data/client/registry/oss/config/... yaml（${ENV:default} 可覆盖）
│   ├── assets/                       # openapi.yaml（make openapi 产物）
│   └── internal/
│       ├── server/                   # rest/grpc/sse(+asynq) 装配、image_upload.go、中间件
│       ├── service/                  # BFF 薄转发 / core 真实业务
│       └── data/                     # 仅 core：ent/schema(58 实体) + *_repo.go + client/ + business_tenant.go
├── pkg/                              # configenv / metadata / entgo(mixin+viewer) / middleware/auth / crypto / constants / authorizer / oss / mailer / serviceid / task ...
├── tools/register/                   # make register 装配登记工具
├── sql/README.md                     # 种子机制说明（Go 自动初始化，无 SQL 种子脚本）
├── .env.example / .golangci.yml      # 环境变量模板 / lint 配置
├── Makefile / app.mk                 # 构建编排
└── go.mod                            # module go-wind-shortplay
```

## 关键约定（必须遵守，与基座一致）

1. **Protobuf 单一事实源** — 接口/模型/错误码先在 `api/protos/` 定义，`make api`（buf generate）生成；`api/gen/`、`ent/`（除 `schema/`）禁止手改。
2. **admin/app 不碰数据库** — BFF 只做校验 + gRPC 转发；数据访问只在 core 的 `internal/data/`。
3. **viewer 身份从鉴权上下文取** — 基座 `pkg/metadata` OperatorMetadata + `pkg/entgo/viewer`（UserViewer/AnonymousTenantViewer/SystemViewer）+ privacy 拦截器；repo/proto 请求体不接受客户端 user_id。业务行租户归属经 `business_tenant.go` 兜底到缺省业务租户。
4. **装配按分层小节** — wiring.go 追加构造行，CRUD 标准形态用 `make register ENTITY=xxx [SVC=admin|app|core] [PKG=xxxV1]`；漏接=编译错误。
5. **业务错误用域错误枚举** — `*_error.proto` enum + 生成的 `ErrorXxx` 助手；禁裸 `errors.New`。
6. **repo 事务** — `defer { rollback/commit }` 闭包模式；接口 `XxxRepo` / 实现 `xxxRepo` / 构造 `NewXxxRepo` 返回接口。
7. **日志** — `ctx.NewLoggerHelper(module)` 的 `*log.Helper`；禁 `fmt.Println`。
8. **改 proto/ent 后必须重新生成** — `make api` / `make ent` / 一键 `make gen`；改 `.proto` 后同时 `make openapi` 刷新 swagger assets。

## 构建与开发命令

| 命令 | 作用 |
|------|------|
| `make gen` | ent + api + openapi 一键 |
| `make api` / `make ent` / `make openapi` | 单项生成 |
| `make build` / `make build_only` | 编译三服务 |
| `make test` / `make vet` / `make lint` | 测试 / go vet / golangci-lint（配置见 `.golangci.yml`） |
| `make register ENTITY=xxx` | 装配登记（五处锚点注入） |
| `cd app/core/service && make run` | 本地跑 core（admin/app 同理；`make run` 会先跑 api/openapi 生成并自动装载 `backend/.env`） |

门禁：`make lint` + `go test ./...` 零错误；改过 proto 再加 `make gen` 并连同生成产物提交。

> `make vet` 是裸 `go vet`（无参数），在 `backend/` 根目录跑不到包；要真的过一遍静态检查，写 `go vet ./...` 或直接依赖 `make lint`。

## 本地运行要点

- **依赖**：PostgreSQL `127.0.0.1:5432/shortplay`、Redis `127.0.0.1:6379`（asynq 用 db2）、MinIO `127.0.0.1:9000`、etcd `127.0.0.1:2379`（复用宿主机既有容器）。
- **建库**：PostgreSQL 建库 `shortplay`；表结构由 core 首次启动 `migrate: true` 自动创建。
- **环境变量**：`cp .env.example .env` 填真实值；`app.mk` 自动装载 `backend/.env` 并 export，`pkg/configenv` 的 env 配置源使各 yaml 的 `${VAR:default}` 按「环境变量优先、缺省值兜底」生效。注意 asynq URI 密码内嵌、走单层 `${ASYNQ_REDIS_URI:...}` 整体插值，不随 `REDIS_PASSWORD` 联动。
- **种子**：Go 自动初始化，**不要找 SQL 种子脚本**（`sql/README.md`）：
  - 空表播种（构造期 count==0 守卫）：默认管理员 `admin / admin`（`pkg/constants.DefaultUsers`）、默认角色/权限/权限组/菜单（`DefaultRoles` / `DefaultPermissions` / `DefaultPermissionGroups` / `DefaultMenus`，含 shortplay 业务菜单与 `biz:*` 权限码）、语言、通知规则；
  - 启动自愈补种（不受 count 门控，按代码/键判存在幂等补种）：默认角色的权限绑定、默认租户（`shortplay`）与其普通用户角色 `app:user`、默认租户管理员（`tenant_service.go`），保证既有库升级后种子也能补齐。
- **登录**：`POST /admin/v1/login`，密码授权强制验证码：先 `GET /admin/v1/captcha`（6 位大写字母+数字，答案落 Redis `gowind-shortplay:captcha:<id>`，verify-and-delete 单次有效），请求头带 `X-Captcha-Id` / `X-Captcha-Value`；**密码字段须 AES 加密**：`base64(AES-CBC(明文, key=iv=<AES_KEY>))`（PKCS7；`crypto.DefaultAESKey`，前端同款逻辑）。dev 缺省 key 为基座公开缺省「f51d66a73d8a0927」仅限本地；生产经环境变量 `AES_KEY` 覆盖（`pkg/configenv.OverrideAESKeyFromEnv`，三服务 main.go 启动钩子，须与前端 `VITE_AES_KEY` 一致）。
- **游客边界**：app 白名单（`rest_server.go` 的 AddWhiteList）——登录/注册/刷新（含 `/auth/*`）、OIDC 授权 URL、Feed/视频详情/搜索/标签聚合、用户资料/统计/作品列表、评论列表与楼中楼、互动状态查询、标签列表、UBA 上报、媒体读取（media-assets get/content）；其余（发布/点赞/收藏/关注/通知/头像直传等）需 Bearer。admin 除登录/验证码外全需登录。
- **上传**：双端图片直传 `POST /admin/v1/uploads/image` 与 `POST /app/v1/uploads/image`（body=图片原始字节，Content-Type 为图片 MIME，≤2MB → `{url}`，手工路由、**不入游客白名单**必须登录）；视频分片上传为 app 端 proto 路由 + 手工 octet-stream 字节路由（注册顺序先于生成路由）。
- **CORS**：admin 白名单 `localhost:16800` 与 `127.0.0.1:16800`（`app/admin/service/configs/server.yaml`），换端口要同步改。
- **JWT_SIGNING_KEY**：三服务共享（`${JWT_SIGNING_KEY:...}` 插值），生产必须环境变量注入。
- **Swagger**：各服务 `configs/server.yaml` 的 `server.rest.enable_swagger` **缺省 false**（`/docs/` 404）；本地需要时改为 true（OpenAPI 资产经 `make openapi` 生成在各自 `assets/`）。

## 新增/扩展业务域接线点

以新增一个业务域（例：video）为例，全部按基座既有模式：

1. **proto**：`api/protos/video/service/v1/{video,video_error}.proto`（核心 gRPC 面，包名 `video.service.v1`）；BFF 面加 `api/protos/admin/service/v1/i_video.proto` / `api/protos/app/service/v1/i_video.proto`（`i_` 前缀，`import "video/service/v1/video.proto"` 复用 message，写 `google.api.http` 注解）。
2. **生成**：`make api`；新包名如需别名在 `api/buf.gen.yaml` 的 managed.override 里加 go_package 条目；`make openapi`。
3. **ent schema**：`app/core/service/internal/data/ent/schema/video.go`（表名/utf8mb4_bin/AutoIncrementId+TimeAt 等基座 mixin 惯例；业务行租户注入用 `business_tenant.go`）→ `make ent`。
4. **repo**：`app/core/service/internal/data/video_repo.go`（接口+实现+defer 事务模式）。
5. **core service**：`internal/service/video_service.go`（嵌入生成包的 Unimplemented，参考既有服务）。
6. **注册装配**（三处手工 + make register 可代劳）：
   - `app/core/service/cmd/server/wiring.go`：仓储小节 + 服务小节 + `server.NewGrpcServer(...)` 实参；
   - `app/core/service/internal/server/grpc_server.go`：形参 + `RegisterXxxServiceServer`（`register:` 锚点）；
   - `app/admin/service/internal/data/data.go` + `cmd/server/wiring.go` + `internal/server/rest_server.go`：客户端 + BFF service + `RegisterXxxServiceHTTPServer`（app 侧同构）。
7. **BFF service**：admin/app `internal/service/video_service.go` 薄转发（注入 `data.NewVideoServiceClient`）。
8. **菜单/权限种子**：`pkg/constants/default_data.go` 的 `DefaultMenus` / `DefaultPermissions` 追加条目，权限码进 `pkg/constants/permission.go`（空表播种；既有环境依赖启动自愈补种或清表重播）。
9. **异步任务**（如转码/推荐）：`pkg/task` 加任务类型 + core `internal/server/asynq_server.go` 注册 subscriber。
10. **验证**：`make gen && make build`，三服务重启，curl 走登录 → 新接口。

## 关键文件索引

- `app/<svc>/service/cmd/server/wiring.go` — ★ 手写装配（查注入拓扑）
- `app/<svc>/service/internal/server/rest_server.go` / `grpc_server.go` / `asynq_server.go`(core) / `image_upload.go` — 传输层与手工路由
- `app/core/service/internal/data/ent/schema/` — ★ ent 实体（58 个，唯一人工维护 ent 目录）
- `app/core/service/internal/data/business_tenant.go` — 业务行租户归属兜底
- `pkg/middleware/auth/` — 认证中间件（authenticationV1.UserTokenPayload claims）
- `pkg/metadata/` + `pkg/entgo/{mixin,viewer}/` — OperatorMetadata 透传与 viewer 体系
- `pkg/configenv/` — env 配置源 + AES_KEY 覆盖
- `pkg/constants/default_data.go` — 全部 Go 侧种子（用户/角色/权限/权限组/菜单/语言/通知规则）；`permission.go` — 权限码
- `app/core/service/internal/data/authenticator.go` + `configs/authenticator.yaml` — JWT 签发/校验与令牌缓存
