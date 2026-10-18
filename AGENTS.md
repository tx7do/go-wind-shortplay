# AGENTS.md — go-wind-shortplay Monorepo 开发指南（AI Agent 入口）

本文件是 monorepo 总入口：定位布局、指路各端文档、声明全仓铁律。**深入开发前先读本文件与对应端的相关文档**。

## 仓库布局

GoWind ShortPlay（风行短剧）：一个 Go 后端 + 一个 React 管理后台 + 一个 Flutter App 的短视频社区（开源基础版 MVP），工程规范对齐 [go-wind-cms](https://github.com/tx7do/go-wind-cms)。

```
backend/                        Go 1.26 + Kratos + Ent（DI 手写装配 wiring.go）
├── api/
│   ├── protos/                 .proto 源文件（identity/permission/authentication/audit/dict/media/storage/task/notify/internal_message/comment/interaction/stats/conf 基座域 + video/feed/report/sysconf/uba 业务域 + admin/app BFF 面）
│   └── gen/go/                 生成代码（HTTP/gRPC/校验），不手改
├── app/
│   ├── admin/service/          管理后台服务（BFF，REST :7600 / SSE :7601）
│   ├── app/service/            前台应用服务（BFF，REST :7700 / SSE :7701，Flutter 走这里）
│   └── core/service/           核心业务与数据层（Ent schema、仓储、业务逻辑，唯一数据落点，gRPC :7900）
├── pkg/                        公共包（configenv env 覆盖链路 / metadata / entgo viewer / constants 种子 / crypto / oss / serviceid / middleware/auth / ...）
├── Makefile / app.mk           构建编排（根 Makefile + 服务共享 app.mk；make 命令自动装载 backend/.env）
└── docker-compose.yaml         容器化部署（三应用服务）
frontend/
├── admin/                      管理后台：React 19 + antd + ProComponents + TanStack Query + Vite 8（dev :16800）
└── app/                        Flutter App：BLoC + media_kit
docs/                           专题文档（API 契约摘要、架构决策）
```

三服务架构指**网关 BFF 与核心服务的分层**：admin / app 是瘦网关（参数校验 + gRPC 转发），**所有数据库操作只能在 core 内进行**。领域拆分体现在 proto 与 core 内部模块上（业务域 video / feed / report / sysconf / uba + 基座基建域 identity / permission / authentication / comment / interaction / notify / stats 等），不体现在进程上；转码集群 / AI 推荐等商业增值能力以独立服务形态外挂（见 [docs/ROADMAP.md](./docs/ROADMAP.md)）。

管理后台基于 **go-wind-cms 的 Ant Design Pro 底座裁剪适配**（`frontend/admin`），Flutter App 同样遵循 GoWind 生态约定——**两端正 UI 都严禁从零重写，必须裁剪底座、按底座既有模式扩展**。

## 门禁（提交前必须全绿）

| 范围 | 命令（在各自目录下） |
|---|---|
| backend | `make lint` + `go test ./...` |
| frontend/admin | `pnpm run typecheck` + `pnpm run lint` |
| frontend/app | `flutter analyze`（必须 No issues found）+ `flutter test` |

**门禁出现任何新报错，一律当作自己引入的 bug 修复**，不存在"可忽略的既有错误"。改完代码先跑门禁再声称完成。

> `make vet` 是裸 `go vet`（无参数），在 `backend/` 根目录跑不到包；要真的过一遍静态检查，写 `go vet ./...` 或直接依赖 `make lint`（golangci-lint）。

## 全仓铁律

1. **不吞错**：任何 catch 至少二选一——日志带出**原始错误对象**，或重新抛出。用户可见的通知 ≠ 日志。合法裸 catch 仅限纯本地 best-effort 兜底且注释写明原因。
2. **生成产物不手改**：`api/gen/go/`、ent 生成代码（`ent/schema/` 除外）、`assets/openapi.yaml` 都是产物。改 `.proto` 或 `ent/schema` 后必须重新生成（`make api` / `make ent` / 一键 `make gen`）并**连同产物一并提交**。
3. **admin/app 不碰数据库**：BFF 只做参数校验 + gRPC 转发；数据访问只存在于 core 的 `internal/data/`。
4. **viewer 身份从鉴权上下文取**：service 层经基座 `pkg/metadata`（OperatorMetadata）+ `pkg/entgo/viewer`（UserViewer / AnonymousTenantViewer / SystemViewer，privacy 拦截器）提取身份与租户；业务行租户归属由 core `internal/data/business_tenant.go` 兜底到缺省业务租户；repo / proto 请求体不接受客户端传入的 user_id（防越权）。
5. **状态机与计数**：视频状态流转必须走 `validateVideoStatusTransition` 白名单（core `video_service.go`）；计数列（like/collect/comment/view）只允许 ledger 事务内增减（`AddXxxCount`），禁止直接 Set 覆盖。
6. **业务错误用域错误枚举**：错误在 `<domain>_error.proto` 中用 enum 定义，用生成的 `ErrorXxx` 助手返回；禁止裸 `errors.New` / `fmt.Errorf` 返回业务错误。

## 工具链与常用命令

后端构建与代码生成统一走 `backend/` 根 Makefile（`make init` 安装 protoc 插件与 CLI 工具链），逐服务命令见 `app.mk`；完整命令表与规约见 [backend/AGENTS.md](./backend/AGENTS.md)。

```bash
cd backend
make init          # 首次：protoc 插件 + buf/ent/golangci-lint/gow
make api           # proto → Go（buf generate）
make openapi       # admin/app 两份 OpenAPI 到各自 assets/
make ent           # ent 代码生成（各服务，--feature privacy,entql）
make gen           # ent + api + openapi 一键
make build / test / lint
cd app/core/service && make run   # 本地跑 core（admin/app 同理）
```

- 新模块必须接入手写装配（`cmd/server/wiring.go` 对应分层小节追加构造行），漏接由编译器报错。
- 项目无 DI 框架，不要引入 wire 依赖。

## 本地验证要点

- **依赖服务**：PostgreSQL / Redis / MinIO / etcd 复用宿主机既有容器；ZLMediaKit 用 `docker run` 单独创建（`shortplay-zlmediakit`）；PostgreSQL 中建库 `shortplay`。连接参数经 `configs/*.yaml` 的 `${ENV:default}` 插值用环境变量覆盖（`DB_HOST` / `REDIS_ADDR` / `OSS_ENDPOINT` 等）；本地真实值放 gitignored 的 `backend/.env`（模板 `backend/.env.example`，`make run` 经 app.mk 自动装载，env 覆盖链路由 `pkg/configenv` 接通），configs 内缺省值为占位串、开源发布前不得回填真实凭据。
- **端口**：admin REST `:7600`（SSE `:7601`）、app REST `:7700`（SSE `:7701`）、core gRPC `:7900`；admin 前端 dev `:16800`（`.env.development` 的 `VITE_SERVER_PORT`）。
- **CORS**：admin 后端白名单默认只放行 `localhost:16800` / `127.0.0.1:16800`（`app/admin/service/configs/server.yaml`），换端口联调要同步改。
- **登录账号**：core 首次启动自动建表并播种管理员 `admin / admin`，**不要**找 SQL 种子脚本；管理端登录需图形验证码，密码 AES 密文传输（dev 缺省 key 见 `backend/.env.example`）。
- **JWT_SIGNING_KEY**：三服务共享一致；生产必须经环境变量注入，缺省 dev key 仅限本地。
- **游客边界**：app 白名单接口（Feed / 详情 / 搜索 / 主页（资料/统计/作品）/ 评论列表 / 互动状态 / 标签 / UBA 上报 / 媒体读取）允许游客访问；发布 / 点赞 / 评论 / 关注 / 通知 / 图片直传需登录。前端对公开页 401 静默处理，不得强制跳登录。
- **Swagger**：各服务 `server.rest.enable_swagger` 缺省 false（`/docs/` 404）；需要时在 configs 打开（OpenAPI 资产经 `make openapi` 生成）。

## 文档索引

- 根 README（三语）：[README.md](./README.md) / [README.en-US.md](./README.en-US.md) / [README.ja-JP.md](./README.ja-JP.md)
- 后端（单一事实源）：[backend/AGENTS.md](./backend/AGENTS.md)
- 管理后台：[frontend/admin/AGENTS.md](./frontend/admin/AGENTS.md)
- Flutter App：[frontend/app/AGENTS.md](./frontend/app/AGENTS.md)
- REST API 契约摘要：[docs/API.md](./docs/API.md)
- 架构决策与服务拆分研判：[docs/ROADMAP.md](./docs/ROADMAP.md)
