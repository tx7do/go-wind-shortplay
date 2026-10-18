<div align="center">

# GoWind ShortPlay

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Go Version](https://img.shields.io/badge/Go-1.26+-00ADD8?logo=go&logoColor=white)](https://go.dev/)
[![React](https://img.shields.io/badge/React-19.x-61DAFB?logo=react&logoColor=white)](https://react.dev/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Kratos](https://img.shields.io/badge/Kratos-2.9-00ADD8?logo=go&logoColor=white)](https://go-kratos.dev/)

[English](./README.en-US.md) | **中文** | [日本語](./README.ja-JP.md)

</div>

---

风行短剧（GoWind ShortPlay）是一款开箱即用的企业级短视频社区基础版（开源 MVP），基于 GoWind 生态构建：上下滑沉浸式视频流、拍摄发布、互动社区与后台审核闭环，小流量企业内部场景可直接上线。

**核心亮点：**

- **API 优先** — Protobuf-first 契约驱动，RESTful / gRPC 双协议，OpenAPI 文档自动生成并内嵌 Swagger
- **三服务架构** — admin / app 瘦网关 BFF + core 唯一数据落点，与 [go-wind-cms](https://github.com/tx7do/go-wind-cms) 完全同构
- **双端覆盖** — React 19 管理后台（GoWind Admin 底座裁剪适配）+ Flutter 跨平台 App，共用一个 core 服务
- **开箱即用** — docker compose 一键起；core 启动即自动建表并播种管理员账号
- **商业版留口** — 转码集群、AI 推荐、内容安全、SaaS 多租户、直播以独立服务外挂，契约边界已定（见 [docs/ROADMAP.md](./docs/ROADMAP.md)）

> **开源版 / 商业版边界**：本仓库为开源基础版，不含多码率转码集群、AI 推荐、内容安全审核、SaaS 多租户与直播（归商业闭源增值包）。

## 技术栈

### 后端

| 层级 | 技术 | 说明 |
|:-----|:-----|:-----|
| 语言 | [Go 1.26+](https://go.dev/) | 高性能编译型语言 |
| 框架 | [go-kratos](https://go-kratos.dev/) v2.9 | B 站开源微服务框架 |
| 依赖注入 | 手写装配（wiring.go） | 无 DI 框架 |
| ORM | [Ent](https://entgo.io/) v0.14 | schema 即代码 |
| 数据库 | [PostgreSQL](https://www.postgresql.org/) / [MySQL](https://www.mysql.com/) | pgx/v5 驱动，双支持 |
| 缓存 | [Redis](https://redis.io/) | 计数 / 已看过滤 / Feed 去重 |
| 对象存储 | [MinIO](https://min.io/) | 视频 / 封面（S3 兼容） |
| 媒体处理 | FFmpeg | 单帧抽图封面，进程内执行、缺失静默降级 |
| API 定义 | [Protobuf](https://protobuf.dev/) + [buf.build](https://buf.build/) | 接口契约优先 |
| 鉴权 | HS256 JWT | core 签发、网关校验、metadata 透传 |
| 服务发现 | etcd | 三服务 gRPC 注册/发现 |

> 后端以 [go-wind-cms](https://github.com/tx7do/go-wind-cms) 的 `backend/` 基座源码移植裁剪而来（Phase 1：保留 identity/permission/authentication/audit/dict/media/storage/task/notify/internal_message 等全部基建域，CMS 内容类业务域已裁剪）；与基座差异仅模块名/端口/数据指向，shortplay 业务域（video/feed 等）按基座既有模式在 Phase 2 接入，详见 [backend/AGENTS.md](./backend/AGENTS.md)。从基座同步上游改动的方法见 [docs/UPSTREAM.md](./docs/UPSTREAM.md)。

### 管理后台前端

| 技术 | 说明 |
|:-----|:-----|
| [React 19](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/) | 渐进式前端框架 + 类型安全 |
| [Ant Design](https://ant.design/) + [ProComponents](https://procomponents.ant.design/) | 企业级中后台组件（Ant Design Pro v6） |
| [TanStack Query](https://tanstack.com/query) | 服务端状态管理 |
| 构建工具 | [Vite](https://vite.dev/) 8（要求 Node ≥ 20.19） |

> 管理后台基于 go-wind-cms 的 Ant Design Pro 底座裁剪适配而来：保留外壳与基建（布局 / 路由 / 鉴权 / i18n / 传输层），按底座既有模式新增短视频社区业务模块。

### 移动端

| 技术 | 说明 |
|:-----|:-----|
| [Flutter](https://flutter.dev/) 3.x | 一套代码同时生成 iOS 和 Android |
| [BLoC](https://bloclibrary.dev/) | 状态管理 |
| [media_kit](https://media-kit.pro/) | 视频播放器（沉浸式上下滑） |

## 架构

```
React Admin ──▶ admin-service (BFF :7600, SSE :7601) ──┐
                                                       ├──gRPC──▶ core-service (:7900, 唯一数据落点)
Flutter App ──▶ app-service   (BFF :7700) ─────────────┘              │
                                            PostgreSQL / Redis / MinIO / FFmpeg
```

- **admin / app 是瘦网关 BFF**（参数校验 + 转发），所有业务与数据操作收敛在 core
- 领域拆分体现在 proto 与 core 内部模块上（video / feed / interaction / report / uba / sysconf / notify / identity / stats），不体现在进程上
- 服务拆分研判与商业版扩展路径见 [docs/ROADMAP.md](./docs/ROADMAP.md)

### 端口表

| 端口 | 服务 | 说明 |
|---|---|---|
| :7600 | admin BFF（REST） | 管理后台 API；Swagger `/docs/` |
| :7601 | admin BFF（SSE） | 通知实时推送 `/events`（需 `?stream=<accessToken>` 与 Bearer 同令牌） |
| :7700 | app BFF（REST） | Flutter App API；Swagger `/docs/` |
| :7900 | core（gRPC） | 唯一数据落点，etcd 注册 |
| :16800 | admin 前端 dev server | Vite（`frontend/admin`）；后端 CORS 白名单缺省只放行 `localhost:16800` |
| :8280 | ZLMediaKit HTTP | 本地流媒体（直播/转码扩展预留，`docker run` 映射） |

## 核心功能

### 视频与 Feed

| 功能 | 说明 |
|:-----|:-----|
| 视频发布 | 分片上传（断点续传友好）、合并入库 MinIO、FFmpeg 抽帧封面、草稿箱 |
| 状态机 | 草稿 → 审核 → 发布 / 驳回 → 下架，流转白名单校验 |
| 沉浸式 Feed | 上下滑视频流、三路规则召回（关注最新 / 热门加权 / 最新兜底）、Redis 已看去重 |
| 搜索与聚合 | 标题模糊 + 标签精确搜索、标签聚合页、标签列表（发布选择 / 搜索联想） |

### 互动与社区

| 功能 | 说明 |
|:-----|:-----|
| 点赞 / 收藏 | 视频与评论点赞、视频收藏 |
| 关注 | 关注 / 粉丝列表、个人主页 |
| 评论 | 视频评论（楼中楼字段预留） |
| 通知 | 点赞 / 评论 / 粉丝 / 系统通知 |
| 举报闭环 | 用户举报工单，通过即联动处置目标（下架 / 删除） |
| UBA 埋点 | 观看 / 完播 / 划走行为采集，服务 Feed 排序 |
| 创作者统计 | 作品 / 获赞 / 粉丝等维度统计 |
| 分享 | 分享 H5 落地页 |

### 管理后台

| 功能 | 说明 |
|:-----|:-----|
| 视频管理 | 审核 / 驳回 / 下架 / 删除，状态流转可视 |
| 评论管理 | 评论查询与删除 |
| 举报工单 | 举报受理与处置，处置联动目标内容 |
| 用户管理 | 用户查询与管理 |
| 数据看板 | 核心指标概览 |
| 系统配置 | 上传限制 / 时长限制 / 人工审核开关 |

## 项目结构

```
go-wind-shortplay/
├── backend/                        # 后端服务
│   ├── api/                        # Protobuf API 定义 & 生成代码
│   │   ├── protos/                 # .proto 源文件（video/feed/interaction/... 各域 + admin/app BFF）
│   │   └── gen/go/                 # 生成代码（HTTP/gRPC/校验），不手改
│   ├── app/
│   │   ├── admin/service/          # 管理后台服务（BFF，REST :7600）
│   │   ├── app/service/            # 前台应用服务（BFF，REST :7700）
│   │   └── core/service/           # 核心业务服务（业务逻辑 + 数据层，gRPC :7900）
│   ├── pkg/                        # 公共包（鉴权上下文/中间件/OSS/服务发现...）
│   ├── Makefile / app.mk           # 构建编排
│   └── docker-compose.yaml         # 容器化部署（三应用服务）
├── frontend/
│   ├── admin/                      # 管理后台前端（React 19 + Ant Design Pro v6，dev :16800）
│   └── app/                        # Flutter App（BLoC + media_kit）
└── docs/                           # 文档（API 契约摘要、架构决策）
```

## 快速开始

### 环境要求

- Go 1.26+
- Docker & Docker Compose
- Node.js ≥ 20.19 & pnpm（Vite 8 要求）
- Flutter 3.x
- buf（Protobuf 工具链，`make init` 可自动安装）

### 1. 准备依赖服务

PostgreSQL / Redis / MinIO / Kafka 复用宿主机既有容器；ZLMediaKit 用 `docker run` 单独创建，并在 PostgreSQL 中建库 `shortplay`：

```bash
docker run -d --name shortplay-zlmediakit --restart unless-stopped \
  -p 8280:80 -p 8444:443 -p 8555:554 -p 8935:1935 -p 8200:8000/udp -p 11001:10000 \
  -v shortplay_zlm_data:/opt/media/bin/data \
  zlmediakit/zlmediakit:master
```

```sql
CREATE DATABASE shortplay;
```

### 2. 配置环境变量

```bash
cd backend
cp .env.example .env    # 填入本机 PostgreSQL / Redis / MinIO 连接值（.env 已 gitignore）
```

`.env` 会被 `make run`（app.mk 自动装载）与 docker compose 读取；各服务 `configs/*.yaml` 中的 `${VAR:default}` 占位符按「环境变量优先、缺省值兜底」解析（缺省值为占位串，**必须**在 `.env` 里给真实值才能连上依赖）。生产部署改经部署环境注入，严禁提交真实凭据。

### 3. 初始化并启动后端

```bash
cd backend
make init        # 首次：安装 protoc 插件与 CLI 工具链

make gen         # ent + api + openapi 一键生成
cd app/core/service  && make run   # gRPC :7900（启动即自动建表并播种管理员）
cd app/admin/service && make run   # REST :7600
cd app/app/service   && make run   # REST :7700
```

冒烟验证（登录密码为 AES 密文传输；下例密文 = dev 缺省 key 加密的 `demo123`，自改 `AES_KEY` 后需按 `frontend/admin/src/utils/crypto.ts` 同款算法重算）：

```bash
curl -X POST http://127.0.0.1:7700/app/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo","password":"SjM/2yeJT+/3xpCGydysrA==","nickname":"Demo"}'
```

API 文档：服务启动后访问 `http://127.0.0.1:7600/docs/`、`http://127.0.0.1:7700/docs/`（Swagger）。

### 4. 启动前端

```bash
# 管理后台
cd frontend/admin
pnpm install
pnpm dev         # dev :16800；演示账号 admin / admin（core 首次启动自动播种）

# Flutter App
cd frontend/app
flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:7700   # 安卓模拟器缺省 10.0.2.2
```

> 游客边界：Feed / 详情 / 搜索 / 主页 / 评论列表允许游客访问（App 端 401 静默降级），发布 / 点赞 / 评论 / 关注需登录；管理后台全部需登录。

## 已知限制（开源基础版）

- **单码率直出**：无转码集群，视频按上传原样播放（商业版提供多码率转码 + 内容安全审核）
- **通知为站内信形态**：管理端 SSE（:7601）实时推送 + App 端拉取，无邮件 / 短信 / Push 通道
- **人工审核**：审核闭环为人工操作，未接机审
- **Feed 排序**：三路召回为规则加权，非模型排序
- **前端 AES key**：登录密码传输加密的 dev 缺省 key 为基座公开缺省（仅限本地），生产必须前后端同步更换（`AES_KEY` / `VITE_AES_KEY`）
- **依赖服务自备**：PostgreSQL / Redis / MinIO / etcd 需自备实例（容器或托管），本仓库不编排它们

### 常用命令

```bash
cd backend

make init        # 安装 protoc 插件与 CLI（首次）
make api         # buf generate（proto → Go）
make openapi     # 生成 admin/app OpenAPI 文档到 assets/
make ent         # 生成 ent 代码（各服务）
make gen         # ent + api + openapi 一键生成
make build       # 全服务构建
make test        # go test ./...
make lint        # golangci-lint
```

### 容器化部署

```bash
cd backend
docker compose up -d --build
```

> 更多开发工作流请参考 [后端开发规范](./backend/AGENTS.md)。

## 文档

- 根 README（三语）：[README.md](./README.md) / [README.en-US.md](./README.en-US.md) / [README.ja-JP.md](./README.ja-JP.md)
- 后端开发规范：[backend/AGENTS.md](./backend/AGENTS.md) — AI 编码工具与人类贡献者共同遵守
- 管理后台：[frontend/admin/AGENTS.md](./frontend/admin/AGENTS.md)
- Flutter App：[frontend/app/AGENTS.md](./frontend/app/AGENTS.md)
- REST API 契约摘要：[docs/API.md](./docs/API.md)
- 架构决策与服务拆分研判：[docs/ROADMAP.md](./docs/ROADMAP.md)
- 从基座同步上游改动：[docs/UPSTREAM.md](./docs/UPSTREAM.md)

## 联系我们

- 微信个人号：`yang_lin_bo`（备注：`go-wind-shortplay`）

## 参与贡献

我们欢迎各种形式的贡献，包括但不限于：

- 提交 [Issue](../../issues) 报告 Bug 或提出功能建议
- 提交 [Pull Request](../../pulls) 修复问题或添加新功能
- 完善文档和翻译
- 分享使用经验

详见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 开源许可

本项目基于 [MIT License](./LICENSE) 开源。

## 致谢

[![JetBrains](https://resources.jetbrains.com/storage/products/company/brand/logos/jb_beam.svg)](https://jb.gg/OpenSource)

感谢 [JetBrains](https://jb.gg/OpenSource) 提供的免费 GoLand & WebStorm 开源许可。
