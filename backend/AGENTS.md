# AGENTS.md — 后端开发指南（go-wind-shortplay）

> 本文件是 backend 子项目的 AI 编码规范单一事实源，适用于所有支持 AGENTS.md 的 AI 编码工具（ZCode、GitHub Copilot、Cursor、Codex、Gemini CLI 等）。Claude Code 通过同级 `CLAUDE.md` 中的 `@AGENTS.md` 引用加载。

## 本仓后端的来历：基于 go-wind-cms 基座源码移植（Phase 1，2026-10-18）

本 backend **不再是"按规约重建"**，而是以 [go-wind-cms](https://github.com/tx7do/go-wind-cms) 的 `backend/` 源码为底整体移植后裁剪而成（取证报告见 [docs/backend-vs-cms-diff.md](../docs/backend-vs-cms-diff.md)）：

- **Phase 1（已完成）**：移植基座全部基建域 + 裁剪 CMS 内容类业务域，改 module 名 / 端口 / 数据指向，登录链路实测打通。
- **Phase 2（待办）**：在此基座上按基座既有模式新增 shortplay 业务域（video / feed / interaction / report / sysconf / uba），见文末「Phase 2 接线点」。

**与基座的差异（截至 Phase 1）**：

1. **module 名**：`go-wind-shortplay`（基座 `go-wind-cms`）；`pkg/serviceid.ProjectName = "gowind-shortplay"`。
2. **端口**：admin REST `:7600`（SSE `:7601`）、app REST `:7700`（SSE `:7701`）、core gRPC `:7900`（基座 6600/6700/6900）。config 已支持 `${ADMIN_REST_ADDR}` 等环境变量覆盖。
3. **数据指向**：外部容器——Citus PG `127.0.0.1:5432` 库 `shortplay`（user `postgres`）、Redis `127.0.0.1:6379`（db2 给 asynq）、MinIO `127.0.0.1:9000`；全部支持 `${ENV:default}` 覆盖（`DB_HOST` / `REDIS_ADDR` / `OSS_ENDPOINT` 等）。注册中心用 etcd `localhost:2379`（三服务 gRPC 互相发现）。
4. **裁剪**：CMS 内容类业务域整体移除（清单见下节）。
5. **必要小改**（裁剪的连带手术，其余基座源码原样）：
   - `core media_asset_service`：去掉文章/页面引用图谱查询（`ListMediaAssetReferences` 落到 Unimplemented）；
   - `admin audit_export_service`：去掉 AI 用量导出段（`ServeAiUsageExport`），审计六类导出保留；
   - `core comment_repo.boolSetting`：site_settings 已裁，评论开关恒为开（shortplay 配置域接入后恢复）；
   - `pkg/task`：社交/flow/webhook/文章定时发布的任务类型常量保留但无订阅者（Phase 2 可复用或清理）；
   - asynq URI 内嵌密码不走 `${ENV:default}` 插值（嵌套默认值不支持），换环境改 `app/core/service/configs/server.yaml`。

## 保留域清单（15 个，基座源码原样）

| 域 | 内容 |
|---|---|
| identity | user / org_unit / position / tenant / membership(4 表) / user_credential / login_policy |
| permission | role / permission / permission_group / api / menu / role_metadata + 5 类 RBAC 关联表 |
| authentication | authentication（密码/刷新/客户端凭证/OIDC/MFA）/ user_credential 服务 / login_policy 服务 / captcha |
| audit | login / api / operation / data_access / permission 五类审计日志 + policy_evaluation_log（admin 侧附 XLSX/CSV 导出） |
| dict | dict_type / dict_entry / dict_entry_i18n / language |
| media | media_asset / media_variant |
| storage | file（MinIO 上传下载） |
| task | sys_tasks 定时任务 + asynq 异步任务 |
| notify | notification channel/delivery/rule/template/preference（Email + Webhook 渠道） |
| internal_message | 站内信 service/category/recipient + SSE 实时推送 |
| conf | 配置扩展 proto（conf 域） |
| comment | 评论（target 泛型，自包含） |
| admin / app | 两个 BFF 网关域（REST 转发面） |

**租户（tenant）**：基座多租户代码原样保留（TenantID mixin、登录租户解析、AnonymousTenantViewer 等）；Citus 库中平台租户 id=0 单租户运行，未做任何删改。

## 裁剪域清单（基座 23 proto 域 → 15）

| 被裁域 | 裁剪内容（约数） |
|---|---|
| ai | proto 9 + gen + ent schema 7 + repo 6 + service 14 + admin BFF 8（含 sse ai-chat 流） |
| content | proto 14 + gen + ent schema 28（post/page/category/tag/section/content_model/field_definition/component/experiment/form/redirect/edit_lock/collab/content_reference）+ repo 24 + core service 16 + admin BFF 10 + app BFF 7 |
| site | proto 5 + gen + ent schema 4（site/site_setting/navigation/navigation_item）+ repo 4 + service 4 + admin BFF 4 + app BFF 2 |
| social | proto 2 + gen + ent schema 4 + repo 4 + service 1 + admin BFF 1 + `pkg/social`（8 平台适配器） |
| webhook | proto 1 + gen + ent schema 2 + repo 1 + service 1 + admin BFF 1 |
| flow | proto 1 + gen + ent schema 1 + repo 1 + service 1 + admin BFF 1 + `pkg/lua` 脚本引擎 |
| translator | proto 1 + gen + admin BFF 1 + `pkg/translator`（google/baidu） |
| interaction | proto 2 + gen + ent schema 2（ledger 表）+ interaction_counter + repo + core/admin/app service（与 post ledger 强耦合，shortplay 版 Phase 2 重做） |
| stats | proto 2 + gen + repo（SQL 聚合查 posts/postlikes）+ admin BFF（内容统计面板，Phase 2 换 shortplay 统计） |

**连带清理**：admin `collab_server` + `internal/collab` 包、admin `mcp_server`、app `graphql_server` + `internal/graphql` + `api/graphql`、core `cmd/reindex`（ES 重索引工具）、`pkg/{ai,content,social,translator,lua,eventbus}`、`pkg/entgo/mixin/seo.go`、CMS 演示数据 `sql/*-demo-data.sql`（建表/种子走 Go 自动初始化，见 `sql/README.md`）；`pkg/mailer` **保留**（通知域 Email 渠道在用）。可选 server 全部随域移除（非配置停用）。

**基座被裁域的 BFF proto 同步删除**（admin 28 个 `i_*.proto`、app 9 个），`buf generate`（`clean: true`）已把 `api/gen/go` 对应目录清干净；OpenAPI assets 已重新生成。

## 项目概览

基于 [go-kratos v2](https://github.com/go-kratos/kratos) 的多租户微服务后端，Protobuf-first（契约驱动）工作流。

**核心技术栈**：go-kratos v2.9.2（HTTP+gRPC+SSE）· Go 1.26 · ent v0.14（privacy/entql/sql-modifier/upsert/lock 五 feature）· 手写装配（wiring.go，无 DI 框架）· PostgreSQL（pgx/v5）· Redis · Asynq · JWT(HS256)+Casbin/OPA 鉴权 · MinIO · etcd 服务发现 · zap 日志。

## 三服务架构

```
HTTP/REST 请求
  └─ admin-service  (后台网关 BFF，REST:7600 / SSE:7601 / gRPC)
       └─ gRPC(etcd 发现) → core-service  (核心业务 + 数据落点, gRPC:7900)
                 ├─ ent ORM → PostgreSQL(Citus)
                 ├─ Redis / MinIO
                 └─ Asynq 异步任务

app-service (前台 BFF，REST:7700 / SSE:7701) ──gRPC──→ core-service
```

| 服务 | 角色 | 访问 DB |
|------|------|:---:|
| `app/admin/service` | 后台网关 BFF（参数校验 + gRPC 转发） | ❌ |
| `app/app/service` | 前台网关 BFF | ❌ |
| `app/core/service` | 核心业务实现（持久化、真实逻辑） | ✅ |

## 目录结构

```
backend/
├── api/
│   ├── protos/<domain>/service/v1/   # ★ proto 源（15 域，人工维护）
│   ├── gen/go/                       # ← buf generate 产物（禁止手改）
│   ├── buf.gen.yaml 等               # 生成模板（go/grpc/http/errors/validate/redact + openapi/ts/dart）
│   └── graphql/                      # （已随 graphql server 裁剪删除）
├── app/<admin|app|core>/service/
│   ├── cmd/server/main.go + wiring.go  # ★ 入口 + 手写装配
│   ├── configs/                      # server/data/client/registry/oss/... yaml（${ENV:default} 可覆盖）
│   └── internal/
│       ├── server/                   # rest/grpc/sse(+asynq) 装配与中间件
│       ├── service/                  # BFF 薄转发 / core 真实业务
│       └── data/                     # 仅 core：ent/schema + *_repo.go + client/ + channel/
├── pkg/                              # auth 中间件 / entgo mixin+viewer / crypto / jwt / metadata / mailer / oss / constants ...
├── tools/register/                   # make register 装配登记工具
├── sql/README.md                     # 种子机制说明（Go 自动初始化）
├── Makefile / app.mk                 # 构建编排
└── go.mod                            # module go-wind-shortplay
```

## 关键约定（必须遵守，与基座一致）

1. **Protobuf 单一事实源** — 接口/模型/错误码先在 `api/protos/` 定义，`make api`（buf generate）生成；`api/gen/`、`ent/`（除 `schema/`）禁止手改。
2. **admin/app 不碰数据库** — BFF 只做校验 + gRPC 转发；数据访问只在 core 的 `internal/data/`。
3. **viewer 身份从鉴权上下文取** — base 的 `pkg/metadata` OperatorMetadata + `pkg/entgo/viewer`（UserViewer/AnonymousTenantViewer/SystemViewer）+ `privacy` 拦截器；repo/proto 请求体不接受客户端 user_id。
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
| `make test` / `make vet` / `make lint` | 测试 / go vet / golangci-lint |
| `make register ENTITY=xxx` | 装配登记（五处锚点注入） |
| `cd app/core/service && make run` | 本地跑 core（admin/app 同理） |

门禁：`go build ./...` + `go vet ./...`（+ `go test ./...`）零错误；改过 proto 再加 `buf generate`。

## 本地运行要点

- **依赖**：Citus PG `127.0.0.1:5432/shortplay`、Redis `127.0.0.1:6379`（密码见 configs）、MinIO `127.0.0.1:9000`、etcd `127.0.0.1:2379`（复用宿主机既有容器）。
- **建库**：PostgreSQL 建库 `shortplay`；表结构由 core 首次启动 `migrate: true` 自动创建。
- **种子**：Go 自动初始化——默认管理员 `admin / admin`（`pkg/constants.DefaultUsers`，UserService 构造期空表播种）、默认角色/权限/菜单/语言/通知规则同样自动播种。**不要找 SQL 种子脚本。**
- **登录**：`POST /admin/v1/login`，密码授权强制验证码：先 `GET /admin/v1/captcha`（答案落 Redis `gowind-shortplay:captcha:<id>`），请求头带 `X-Captcha-Id` / `X-Captcha-Value`；**密码字段须 AES 加密**：`base64(AES-CBC(明文, key=iv="f51d66a73d8a0927"))`（`crypto.DefaultAESKey`，前端同款逻辑）。
- **游客边界**：app 白名单（登录/注册/刷新/评论读写/媒体读取）匿名可达；其余需 Bearer。
- **CORS**：admin 白名单 `localhost:16800`（`app/admin/service/configs/server.yaml`），换端口要同步改。
- **JWT_SIGNING_KEY**：三服务共享（`${jwt_signing_key:...}` 插值），生产必须环境变量注入。

## Phase 2 接线点（shortplay 业务域接入指南）

以新增一个业务域（例：video）为例，全部按基座既有模式：

1. **proto**：`api/protos/video/service/v1/{video,video_error}.proto`（核心 gRPC 面，包名 `video.service.v1`）；BFF 面加 `api/protos/admin/service/v1/i_video.proto` / `api/protos/app/service/v1/i_video.proto`（`i_` 前缀，`import "video/service/v1/video.proto"` 复用 message，写 `google.api.http` 注解）。
2. **生成**：`make api`；新包名如需别名在 `api/buf.gen.yaml` 的 managed.override 里加 go_package 条目；`make openapi`。
3. **ent schema**：`app/core/service/internal/data/ent/schema/video.go`（表名/utf8mb4_bin/AutoIncrementId+OperatorID+TimeAt+TenantID mixin 惯例）→ `make ent`。
4. **repo**：`app/core/service/internal/data/video_repo.go`（接口+实现+defer 事务模式，参考 `user_repo.go`）。
5. **core service**：`internal/service/video_service.go`（嵌入 `videoV1.UnimplementedVideoServiceServer`，参考 `user_service.go`）。
6. **注册装配**（三处手工 + make register 可代劳）：
   - `app/core/service/cmd/server/wiring.go`：仓储小节 + 服务小节 + `server.NewGrpcServer(...)` 实参；
   - `app/core/service/internal/server/grpc_server.go`：形参 + `videoV1.RegisterVideoServiceServer`（`register:` 锚点）；
   - `app/admin/service/internal/data/data.go` + `cmd/server/wiring.go` + `internal/server/rest_server.go`：客户端 + BFF service + `RegisterVideoServiceHTTPServer`（app 侧同构）。
7. **BFF service**：admin/app `internal/service/video_service.go` 薄转发（注入 `data.NewVideoServiceClient`）。
8. **菜单/权限种子**：`pkg/constants/default_data.go` 的 `DefaultMenus` / `DefaultPermissions` / `DefaultRoles` 追加条目（空表播种；已有数据的环境需手工插或清表重播）。
9. **异步任务**（如转码/推荐）：`pkg/task` 加任务类型 + core `internal/server/asynq_server.go` 注册 subscriber。
10. **验证**：`make gen && make build`，三服务重启，curl 走登录 → 新接口。

## 关键文件索引

- `app/<svc>/service/cmd/server/wiring.go` — ★ 手写装配（查注入拓扑）
- `app/<svc>/service/internal/server/rest_server.go` / `grpc_server.go` / `asynq_server.go`(core) — 传输层
- `app/core/service/internal/data/ent/schema/` — ★ ent 实体（46 个，唯一人工维护 ent 目录）
- `pkg/middleware/auth/` — 认证中间件（authenticationV1.UserTokenPayload claims）
- `pkg/entgo/{mixin,viewer}/` — 通用 mixin 与 viewer 体系
- `pkg/constants/default_data.go` — 全部 Go 侧种子（用户/角色/权限/菜单/语言/通知规则）
- `app/core/service/internal/data/authenticator.go` + `configs/authenticator.yaml` — JWT 签发/校验与 AES key
