# AGENTS.md — 后端开发指南

> 本文件是 backend 子项目的 AI 编码规范单一事实源，适用于所有支持 AGENTS.md 的 AI 编码工具（ZCode、GitHub Copilot、Cursor、Codex、Gemini CLI 等）。Claude Code 通过同级 `CLAUDE.md` 中的 `@AGENTS.md` 引用加载。
> 工程规范对齐 [go-wind-cms](https://github.com/tx7do/go-wind-cms)，差异点见「与 cms 的差异」一节。

## 项目概览

基于 [go-kratos v2](https://github.com/go-kratos.dev) 的短视频社区后端（GoWind 生态组件），采用 **Protobuf-first（契约驱动）** 工作流。

**核心技术栈**：
- **框架**: go-kratos v2.9（HTTP + gRPC）
- **语言**: Go 1.26+
- **ORM**: entgo.io/ent v0.14（schema 即代码）
- **依赖注入**: 手写装配（`cmd/server/wiring.go`，无 DI 框架）
- **数据库**: PostgreSQL（主）/ MySQL，驱动 pgx/v5
- **缓存**: Redis（计数 / 已看过滤 / Feed 去重）
- **对象存储**: MinIO（S3 兼容，视频 / 封面）
- **鉴权**: HS256 JWT（core 签发、网关校验、metadata 透传）
- **API 定义**: Protobuf + buf.build
- **媒体处理**: FFmpeg 单帧抽图（封面），进程内执行、缺失静默降级

## 三服务架构（关键心智模型）

```
HTTP/REST 请求
  └─ admin-service  (后台网关 BFF，REST:7600)
       └─ gRPC → core-service  (核心业务 + 数据落点, gRPC:7900)
                 ├─ ent ORM → PostgreSQL
                 ├─ Redis / MinIO
                 └─ FFmpeg（封面抽帧，进程内）

app-service (前台网关 BFF，REST:7700，Flutter 走这里) ──gRPC──→ core-service
```

| 服务 | 角色 | 是否访问 DB |
|------|------|:---:|
| `app/admin/service` | 后台网关 BFF（React admin 走这里） | ❌ |
| `app/app/service` | 前台网关 BFF（Flutter 走这里） | ❌ |
| `app/core/service` | 核心业务实现（持久化、真实逻辑） | ✅ |

> **admin / app 是「瘦」网关**：service 仅做参数校验 + gRPC 转发到 core。**所有数据库操作只能在 core-service 内进行。**
> 服务拆分原则：**领域拆分体现在 proto 与 core 内部模块上，不体现在进程上**。转码集群 / AI 推荐等商业增值能力以独立服务形态外挂（见 docs/ROADMAP.md）。

## 目录结构

```
backend/
├── api/
│   ├── protos/                   # ★ proto 源文件（人工维护）
│   │   └── <domain>/service/v1/  # video/feed/interaction/report/uba/sysconf/notify/identity/stats + admin/app BFF
│   └── gen/go/                   # ← buf generate 生成（禁止手改）
├── app/
│   └── <admin|app|core>/service/
│       ├── cmd/server/           # 入口 + 手写依赖装配（wiring.go）
│       ├── configs/              # 运行时配置（server/data/client/oss.yaml）
│       └── internal/
│           ├── server/           # 传输层（REST / gRPC 装配 + 中间件 + 鉴权白名单）
│           ├── service/          # 业务逻辑层（core 实现领域接口；BFF 薄转发）
│           └── data/             # 数据访问层（仅 core 有）
│               ├── ent/schema/   # ★ ent 实体定义（人工维护）
│               ├── ent/          # ← ent generate 生成（禁止手改）
│               ├── client/       # ent/redis/minio 客户端构造
│               └── *_repo.go     # 仓储实现
├── pkg/                          # 跨服务公共库
│   ├── serviceid/                # 项目名 / 服务名 / 发现地址
│   ├── oss/                      # MinIO 薄封装（对象键 ↔ URL）
│   ├── authctx/                  # 鉴权上下文取值（userId / 调用面）
│   └── middleware/auth/          # JWT 中间件（Server 校验 / Client 透传）
├── Makefile / app.mk             # 构建编排（根 Makefile + 服务共享 app.mk）
├── docker-compose.yaml           # 全量部署（基础设施 + 三服务）
└── docker-compose.libs.yaml      # 仅基础设施
```

## 鉴权模型（开源版）

1. **core 签发**：`AuthenticationService.Login/Register` 校验 Argon2 密码后签发 HS256 JWT（access 24h + refresh 30d，`tokenType` claim 区分）。
2. **网关校验**：BFF `auth.NewServerMiddleware` 校验 Bearer token，claims 注入请求上下文；白名单操作（登录 / 游客 Feed 等）跳过，见各 `rest_server.go` 的 `*WhiteList`。
3. **透传 core**：BFF 出站中间件把 `x-user-id`、`x-client-type`（admin/app）写入 gRPC metadata；core 的 `NewCoreServerMiddleware` 还原为 claims。
4. **业务侧取值**：一律走 `pkg/authctx`（`UserIDFromContext` / `IsAdminCaller`），禁止直接摸 claims map。
5. **权限控制**：游客只能浏览（白名单接口）；发布 / 点赞 / 评论 / 关注需登录；管理端操作（审核 / 强制下架 / 删评论 / 举报处置）经 `IsAdminCaller` 豁免属主校验。RBAC（Casbin/OPA）随管理后台前端接入。
6. **JWT_SIGNING_KEY**：三服务共享；生产必须经环境变量注入，缺省 dev key 仅限本地。

## 关键约定（必须遵守）

### 契约与生成

1. **Protobuf 是单一事实源** — 接口、数据模型、错误码先在 `api/protos/` 定义，再生成 Go 代码
2. **禁止手改生成代码** — `api/gen/`、`*/ent/`（除 `ent/schema/`）
3. **改 proto 后必须重新生成** — `make api`（或一键 `make gen`）
4. **新增 ent 实体后必须重新生成** — 服务目录下 `make ent`
5. **新增模块必须接入手写装配** — 在 `cmd/server/wiring.go` 对应分层小节追加构造行，漏接由编译器在调用处报错

### 分层规约

6. **admin/app service 不碰数据库** — 只校验参数并 gRPC 转发到 core
7. **数据访问只在 core 的 `internal/data/`** — 其它服务不直接操作 ent
8. **viewer 身份从鉴权上下文取** — service 层经 `authctx.UserIDFromContext` 提取，repo / proto 请求体不接受客户端传入的 user_id（防越权）
9. **跨领域调用走 service 层组装** — 禁止 repo 之间互相 import（例：comment 通知作者由 service 查 video 归属后落 notification）

### 命名约定

10. **文件**：`snake_case.go`，按 `<entity>_service.go` / `<entity>_repo.go` 划分
11. **接口与实现分离**：构造函数 `NewXxx` 返回接口类型（后续按需引入）；目前 repo 直接导出结构体
12. **接收者简短**：service 用 `s`，repo 用 `r`，context 用 `ctx`
13. **包名全小写**，与目录一致（`package service`、`package data`）

### 错误处理

14. **统一使用 Kratos 错误码封装** — 错误在 `<domain>_error.proto` 中用 enum 定义并生成 `ErrorXxx` 助手函数
15. **禁止裸用 `errors.New` / `fmt.Errorf`** 返回业务错误 — 用 `videoV1.ErrorNotFound("video not found")` 等
16. **各域错误枚举**已预置标准 HTTP 码 + 域内特有错误（如 `VIDEO_NOT_FOUND` / `INVALID_STATUS_TRANSITION`）；新错误先加 enum 再生成

### 状态机与计数（video 域专用）

17. **视频状态流转必须走 `validateTransition`** — DRAFT→REVIEWING→PUBLISHED、REVIEWING→REJECTED、PUBLISHED→OFFLINE；新增流转先改白名单表
18. **计数列（like/collect/comment/view）只允许 ledger 事务内增减**（`AddXxxCount`），禁止直接 Set 覆盖；Redis 计数缓存是升级路径，接口形态不变

## 与 cms 的差异（刻意的简化）

| 项 | go-wind-cms | 本项目（开源 MVP） |
|----|-------------|-------------------|
| 多租户 | TenantID mixin + viewer 隔离 | 无（SaaS 多租户归商业版） |
| RBAC | Casbin/OPA 全套 | 仅认证 + 调用面标记；RBAC 随 admin 前端接入 |
| 异步任务 | Asynq 进程内 worker | 暂无（封面抽帧同步尽力而为）；上传转码异步化是 Week 2 议题 |
| 审计日志 | 六类审计日志 | 无（商用版增强） |
| 服务发现 | etcd | dev 直连 `CORE_SERVICE_ADDR`；etcd 配置保留可切 |
| OpenSearch | 全文检索 | 无（搜索走 SQL LIKE，量大后接 ES） |

## 常用命令

```bash
make init          # 安装 protoc 插件与 CLI（首次）
make api           # buf generate（proto → Go）
make openapi       # 生成 admin/app OpenAPI 文档到 assets/
make ent           # 生成 ent 代码（各服务）
make gen           # ent + api + openapi
make build         # 全服务构建
cd app/core/service && make run   # 本地跑 core（同理 admin/app）

docker compose -f docker-compose.libs.yaml up -d   # 起基础设施
docker compose up -d --build                        # 全量部署
```

## 环境变量

| 变量 | 说明 | 缺省 |
|------|------|------|
| `JWT_SIGNING_KEY` | JWT 签名密钥（三服务一致） | dev key（警告） |
| `CORE_SERVICE_ADDR` | BFF 直连 core 地址 | 127.0.0.1:7900 |
| `OSS_BUCKET` | MinIO 工作桶 | shortplay |
| `OSS_PUBLIC_ENDPOINT` | 客户端访问 MinIO 的端点 | 返回对象键 |
| `UPLOAD_TEMP_DIR` | 分片上传暂存目录 | 系统临时目录 |
