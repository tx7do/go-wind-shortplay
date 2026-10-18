# 从基座同步上游改动（go-wind-cms → go-wind-shortplay）

> 本仓库不是从零开发：后端是 [go-wind-cms](https://github.com/tx7do/go-wind-cms) `backend/` 的**源码移植裁剪版**，管理后台是 `go-wind-cms/frontend/admin`（Ant Design Pro / vben 底座）的裁剪适配版，Flutter App 遵循同一套生态约定。本文说明两边的目录映射、裁剪清单、以及再同步上游改动的方法。机器比对取证详见 [backend-vs-cms-diff.md](./backend-vs-cms-diff.md)（2026-10-18 快照）。

## 一、上游基座清单

| 上游 | 用途 | 映射到本仓库 |
|---|---|---|
| `go-wind-cms/backend` | 后端基座（kratos-bootstrap 三服务 + ent + 基建域） | `backend/`（module 名 `go-wind-shortplay`） |
| `go-wind-cms/frontend/admin` | 管理后台底座（布局/路由/鉴权/i18n/传输层） | `frontend/admin/` |
| `go-wind-admin`（tx7do） | 管理后台样式/组件上游（样式修复批同步） | `frontend/admin/src/`（历史同步：`f053ec11..b903f851` → 提交 52fe497） |
| `tx7do/*` 依赖族（kratos-bootstrap、go-crud、go-utils、kratos-authn/authz） | 框架库（正常 go.mod 依赖，无源码映射） | `backend/go.mod` |

## 二、目录映射（cms → shortplay）

后端目录**同名同位**，直接 `diff <base> <ours>` 即可比对；差异集中在模块与端口：

| 维度 | go-wind-cms | go-wind-shortplay | 说明 |
|---|---|---|---|
| module 名 | `go-wind-cms` | `go-wind-shortplay` | import 路径相应替换 |
| admin REST / SSE | :6600 / :6601 | **:7600 / :7601** | 端口整体迁移（避开本机其它 GoWind 项目冲突，提交 6d684e1） |
| app REST / SSE | :6700 / :6701 | **:7700 / :7701** | 同上 |
| core gRPC | `:0`（随机） | **:7900** | 固定端口，etcd 注册名 `ProjectName/AppId` |
| Redis 库 | 缺省 db | asynq 队列专库 **db2** | 防多项目共用 db1 抢任务（`ASYNQ_REDIS_URI`） |
| 验证码 Redis 键前缀 | `gowind-cms:` | `gowind-shortplay:` | `pkg/serviceid` / 种子常量 |

### 2.1 基建域（跟随基座，同步时以基座为准）

identity / permission / authentication / audit / dict / media / storage / task / notify / internal_message / interaction / comment / stats —— 三服务骨架（`app/{admin,app,core}/service`）、`pkg/`（authorizer、middleware/auth、oss、mailer、constants…）、`Makefile`/`app.mk`/`Dockerfile` 均属此类。

### 2.2 shortplay 自有域（基座没有，同步时**必须保留**）

- proto：`api/protos/{video,feed,report,sysconf,uba}/service/v1`（+ `api/gen/go/` 同名）
- core：`internal/data/{video,feed,comment_report,business_tenant,...}_repo.go`、`internal/service/{video,feed,report,...}_service.go`
- BFF：`app/{admin,app}/service/internal/server/` 的业务路由挂载、`image_upload.go`、`rest_server.go` 白名单
- `pkg/authctx/`（viewer 身份提取）、`pkg/crypto/`（凭据落库加密，A/B 类引入）
- Flutter App：`frontend/app/`（基座无此端）

### 2.3 基座有而本项目**未采纳**（同步时跳过）

CMS 内容业务域：`ai/ content/ site/ social/ flow/ translator/ webhook/ graphql/ preview/` 及 `pkg/{ai,content,social,lua,translator,eventbus,dtmdriver-kratos,preview,sseevent,...}` 等（完整 111 项清单见 backend-vs-cms-diff.md §1.4）。若上游改动落在这些目录，**直接忽略**。

### 2.4 本项目对基座的**有意偏离**（同步冲突高发点，勿被上游覆盖）

| 文件/位置 | 偏离内容 |
|---|---|
| `app/*/service/configs/*.yaml` | 端口、`${VAR:placeholder}` 占位缺省（开源脱敏）、`config.yaml`（env 配置源开关） |
| `app/core/service/configs/server.yaml` | asynq URI 单层插值 `${ASYNQ_REDIS_URI:...}`、:7900 |
| `app/*/service/cmd/server/main.go` | `configenv.OverrideAESKeyFromEnv()` 启动钩子 |
| `pkg/configenv/` | env 覆盖链路（kratos-bootstrap 只注册 file source，环境变量默认**不生效**，本项目经远程配置源工厂扩展点接通） |
| `app.mk` | 追加装载仓库根 `backend/.env`（服务目录 .env 可覆盖） |
| `app/admin/service/configs/server.yaml` | CORS 白名单 :16800 |
| 种子数据（`pkg/constants/`、core 幂等补种） | 短剧角色/菜单/权限码（`biz:*`）、admin/admin |

## 三、再同步方法（基座有新改动时）

1. **判定归属**：`cd go-wind-cms && git log --oneline <since>.. -- backend/ frontend/admin`，按 §2.1/§2.3 分类——基建域取，CMS 业务域弃。
2. **后端同步**（文件级手工搬移，不直接 merge——module 名/端口/裁剪差异使自动合并噪音大）：
   - 逐文件 `diff go-wind-cms/backend/<path> backend/<path>`，把上游修复套用到我方版本（保留 §2.4 偏离）；
   - 涉及 `.proto` / ent schema 的改动：搬源码后必须 `make gen`（ent + api + openapi）并**连同生成产物一并提交**；
   - 冲突高发文件优先人工比对：`Makefile`、`app.mk`、`app/*/service/cmd/server/{main,wiring}.go`、`configs/*.yaml`、`pkg/constants/`。
3. **前端同步**：`frontend/admin/src` 顶层结构与基座一致；上游修复通常落在 `src/{core,components,layouts,locales,utils}`（基建），逐目录 diff 套用；`src/pages/{app,core}` 下我方业务页与基座 CMS 页同名不同内容，**不要整目录覆盖**（样式修复提交 52fe497 是同步范例）。
4. **回归门禁**：后端 `make lint && go test ./...`；admin `pnpm run typecheck && pnpm run lint`；app `flutter analyze && flutter test`。再起三服务跑一遍登录 / Feed（见根 README 快速开始）。
5. **记录**：在提交信息注明上游区间（如 `sync: 上游 go-wind-cms <a1b2c3>..<d4e5f6> 基建域修复`），方便下次增量。
