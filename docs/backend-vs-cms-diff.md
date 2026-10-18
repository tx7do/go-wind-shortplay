# 后端机器比对取证报告：go-wind-shortplay vs go-wind-cms（基座）

| 项目 | 内容 |
|---|---|
| 被检对象（我方） | `D:\GoProject\go-wind-shortplay\backend`（module `go-wind-shortplay`，go 1.26.4） |
| 对照基座 | `D:\GoProject\go-wind-cms\backend`（module `go-wind-cms`，go 1.26.4） |
| 比对方式 | 纯机器比对：`find` 目录树对齐、`go.mod` 逐模块版本对照、`cmp` 字节级文件比对、proto/ent 源码逐行摘录。**本文所有断言均附来源路径，无推测性表述。** |
| 比对日期 | 2026-10-18 |
| 写入范围 | 仅本报告文件，未改动两边任何代码 |

---

## 一、目录结构层（深度 4）

### 1.1 总量数字

| 指标 | 我方 | 基座 |
|---|---|---|
| 目录数（相对路径，深度 ≤4） | **61** | **155** |
| 同名同位目录 | **44**（占我方 72.1%，两边共有） | 同左 |
| 仅我方有 | **17** | — |
| 仅基座有 | — | **111** |
| 源文件数（.go/.proto/.mk/Makefile/.yaml） | **487** | **2053** |
| 同相对路径文件 | **172**（占我方 35.3%，两边共有） | 同左 |
| 同路径文件中**字节级完全相同**（`cmp`） | **13**（占同路径 7.6%，两边共有） | 同左 |

> 统计口径：`find <backend> -maxdepth 4 -type d` 去根目录后按相对路径求交；文件比对 `find -type f` 后 `cmp -s`。

### 1.2 同名同位目录（44 个，即结构复用部分）

```
api、api/gen、api/gen/go、api/gen/go/{admin,app,identity,interaction,notify,stats}
api/protos、api/protos/{admin,app,identity,interaction,notify,stats}（各含 service 子目录）
app、app/{admin,app,core}、app/*/service、app/*/service/cmd、app/*/service/configs、app/*/service/internal
pkg、pkg/authorizer、pkg/middleware、pkg/middleware/auth、pkg/oss、pkg/serviceid
```
来源：`find` 两侧 `backend/` 交集（完整清单由比对脚本产出，上文 44 项逐一列出）。

### 1.3 仅我方有的目录（17 个，自建业务域）

```
api/protos/{feed,report,sysconf,uba,video}/service   （5 个域 ×2 含 gen 目录，共 10 目录）
api/gen/go/{feed,report,sysconf,uba,video}           （5 个）
bin/                                                  （1 个）
pkg/authctx/                                          （1 个）
```

### 1.4 仅基座有的目录（111 个，未采纳部分，按分支归组）

- **api 域（53 个）**：`api/gen/go/` 下 18 个域（ai/audit/authentication/comment/conf/content/dict/flow/graphql/internal_message/media/permission/site/social/storage/task/translator/webhook）；`api/protos/` 下 17 个域及其 service/v1 子目录（34 个）加 `api/protos/conf/v1`、`api/graphql`。
- **app 服务内部（3 个）**：`app/{admin,app,core}/service/bin`。
- **pkg（42 个）**：`pkg/{ai,constants,content,content/count,content/summary,crypto,dtmdriver-kratos,entgo,entgo/mixin,entgo/viewer,eventbus,jwt,lua,lua/api,lua/examples,lua/hook,lua/internal,lua/internal/convert,mailer,metadata,middleware/ent,middleware/logging,netutil,preview,social,social/{bluesky,devto,linkedin,mastodon,metaweblog,nostr,telegram,wechat,weibo,wordpress},sseevent,task,translator,translator/baidu,translator/mdprotect,utils,utils/converter}`。
- **工程配套（12 个）**：`build/`、`scripts/`（含 deploy/docker/docker/opensearch/e2e/e2e/__pycache__/env/env/lib 共 8 个子目录）、`sql/`、`tools/`、`tools/register/`。
- **其他（1 个）**：`.idea/`。

### 1.5 顶层文件对照

| 我方顶层（7 项） | 基座顶层（16 项） |
|---|---|
| AGENTS.md、Dockerfile、Makefile、app.mk、docker-compose.yaml、go.mod、go.sum | 我方 7 项 **全部同名同位**，基座另加：CLAUDE.md、README.md、_wire_flow.py、build/、docker-compose.libs.yaml、e2e_token.txt、scripts/、sql/、tools/ |

### 1.6 同路径文件的字节级比对（`cmp`）

同相对路径 172 个文件中，**逐字节相同的仅 13 个**：

| # | 文件 | 性质 |
|---|---|---|
| 1 | `api/buf.yaml` | 构建配置 |
| 2 | `app.mk` | 构建配置（Makefile 片段，逐字节相同） |
| 3 | `app/core/service/internal/data/ent/migrate/migrate.go` | ent 生成代码 |
| 4–13 | `api/gen/go/*/…pb.validate.go` ×10（admin 域 8 个 + interaction_error） | protoc 生成代码 |

根 `Makefile` 同路径但内容不同（`cmp` 判定 DIFFERENT）。**两边手写业务 .go / .proto 文件逐字节相同的数量：0。**

---

## 二、依赖层（go.mod）

来源：`backend/go.mod`（双方）。统计口径：解析全部 require 行（含 `// indirect` 标记），按「模块名 @ 版本号」字符串精确比对。

### 2.1 总量

| 指标 | 我方 | 基座 |
|---|---|---|
| 模块总数 | **156**（直接 27 + 间接 129） | **307**（直接 88 + 间接 219） |
| 同名同版本 | **127**（占我方模块 81.4%，两边共有） | 同左 |
| 同名不同版本 | **27**（两边共有） | 同左 |
| 仅基座有 | **153**（其中基座直接依赖 47） | — |
| 仅我方有 | **2**（均 indirect：`github.com/gogo/protobuf v1.3.2`、`github.com/stoewer/go-strcase v1.3.1`） | — |

### 2.2 我方直接依赖与基座直接依赖同名同版本（26 条，逐条版本号）

```
entgo.io/ent                                          v0.14.6
github.com/go-kratos/kratos/v2                        v2.9.2
github.com/go-sql-driver/mysql                        v1.10.0
github.com/google/uuid                                v1.6.0
github.com/jackc/pgx/v5                               v5.9.2
github.com/lib/pq                                     v1.12.3
github.com/minio/minio-go/v7                          v7.2.1
github.com/redis/go-redis/v9                          v9.22.0
github.com/tx7do/go-crud/api                          v0.0.7
github.com/tx7do/go-crud/entgo                        v0.0.52
github.com/tx7do/go-utils/password                    v0.0.2
github.com/tx7do/kratos-authn                         v1.1.11
github.com/tx7do/kratos-authn/engine/jwt              v1.1.11
github.com/tx7do/kratos-authz                         v1.1.8
github.com/tx7do/kratos-authz/engine/casbin           v1.1.12
github.com/tx7do/kratos-authz/middleware              v1.1.13
github.com/tx7do/kratos-bootstrap/api                 v0.0.45
github.com/tx7do/kratos-bootstrap/bootstrap           v0.1.16
github.com/tx7do/kratos-bootstrap/cache/redis         v0.1.1
github.com/tx7do/kratos-bootstrap/database/ent        v0.1.5
github.com/tx7do/kratos-bootstrap/oss/minio           v0.1.2
github.com/tx7do/kratos-bootstrap/registry/etcd       v0.2.2
github.com/tx7do/kratos-bootstrap/rpc                 v0.1.1
github.com/tx7do/kratos-bootstrap/tracer              v0.1.4
google.golang.org/grpc                                v1.83.2
google.golang.org/protobuf                            v1.36.12
```

另有 12 个模块两边**版本相同**但在我方为 indirect、基座为直接依赖：`golang-jwt/jwt/v5 v5.3.1`、`google/gnostic v0.7.1`、`jinzhu/copier v0.4.0`、`tx7do/go-crud/pagination v0.0.15`、`tx7do/go-crud/viewer v0.0.6`、`tx7do/go-utils v1.1.40`、`tx7do/go-utils/id v0.0.6`、`tx7do/go-utils/mapper v0.0.3`、`tx7do/kratos-bootstrap/{config v0.2.2, logger v0.1.2, registry v0.2.2}`、`golang.org/x/net v0.58.0`。

### 2.3 同名不同版本（27 条）

直接依赖 1 条：

| 模块 | 我方 | 基座 |
|---|---|---|
| `google.golang.org/genproto/googleapis/api` | v0.0.0-20260810153831-ec0a7760b754 | v0.0.0-20260825221802-da73d73af1c5 |

间接依赖 26 条（在我方 go.mod 中均标 `// indirect`；其中 `go.etcd.io/etcd/client/v3` 与 `go.opentelemetry.io/otel/trace` 在基座为直接依赖，其余 24 条两边均 indirect）：`buf.build/gen/go/bufbuild/protovalidate/...`（20251209… vs 20260209…）、`buf.build/go/protovalidate`（v1.1.0 vs v1.1.2）、`coreos/go-systemd/v22`（v22.6.0 vs v22.7.0）、`felixge/httpsnoop`（v1.0.4 vs v1.1.0）、`google/cel-go`（v0.26.1 vs v0.27.0）、`grpc-ecosystem/grpc-gateway/v2`（v2.27.7 vs v2.30.0）、`klauspost/compress`（v1.18.6 vs v1.19.2）、`klauspost/cpuid/v2`（v2.3.0 vs v2.4.0）、`lufia/plan9stats`、`mattn/go-isatty`（v0.0.22 vs v0.0.24）、`go.etcd.io/etcd/{api/v3,client/pkg/v3,client/v3}`（v3.6.7 vs v3.7.1）、`go.opentelemetry.io/otel` 系列 9 条（v1.44/1.45/1.39 vs v1.46）、`go.opentelemetry.io/proto/otlp`（v1.9.0 vs v1.11.0）、`go.uber.org/zap`（v1.27.1 vs v1.28.0）、`genproto/googleapis/rpc`、`gopkg.in/ini.v1`（v1.67.2 vs v1.67.3）。

### 2.4 基座直接依赖中我方未采纳（47 条，全部版本号照录）

```
github.com/99designs/gqlgen v0.17.89          github.com/alicebob/miniredis/v2 v2.38.0
github.com/disintegration/imaging v1.6.2      github.com/dtm-labs/dtm v1.19.0
github.com/dtm-labs/dtmdriver v0.0.6          github.com/envoyproxy/protoc-gen-validate v1.3.3
github.com/getkin/kin-openapi v0.146.0        github.com/hibiken/asynq v0.26.0
github.com/jinzhu/inflection v1.0.0           github.com/kolo/xmlrpc v0.0.0-20220921171641-a4b6fa1dd06b
github.com/mark3labs/mcp-go v0.58.0           github.com/mileusna/useragent v1.3.5
github.com/nbd-wtf/go-nostr v0.52.3           github.com/opensearch-project/opensearch-go/v4 v4.6.0
github.com/reearth/ygo v1.51.11               github.com/robfig/cron/v3 v3.0.1
github.com/sashabaranov/go-openai v1.41.2     github.com/stretchr/testify v1.12.1
github.com/tx7do/go-crud/opensearch v0.0.5    github.com/tx7do/go-utils/aggregator v0.0.5
github.com/tx7do/go-utils/captcha v0.0.4      github.com/tx7do/go-utils/copierutil v0.0.8
github.com/tx7do/go-utils/crypto v0.0.2       github.com/tx7do/go-utils/doctext v0.1.0
github.com/tx7do/go-utils/geoip v1.1.8        github.com/tx7do/go-utils/jwtutil v0.0.3
github.com/tx7do/go-utils/notify v0.0.6       github.com/tx7do/go-utils/slug v0.0.1
github.com/tx7do/go-utils/translator v1.1.3   github.com/tx7do/go-wind-plugins/ai/openai v0.0.1
github.com/tx7do/go-wind-toolkit/protoc-gen-go-redact v0.0.0-20260621140333-c4bf78d8d062
github.com/tx7do/kratos-authz/engine/opa v1.1.16
github.com/tx7do/kratos-bootstrap/database/opensearch v0.1.1
github.com/tx7do/kratos-bootstrap/transport/mcp v0.0.5
github.com/tx7do/kratos-bootstrap/transport/sse v0.0.4
github.com/tx7do/kratos-swagger-ui v0.0.1     github.com/tx7do/kratos-transport/broker v1.4.1
github.com/tx7do/kratos-transport/transport/asynq v1.3.13
github.com/tx7do/kratos-transport/transport/graphql v1.4.2-0.20261014230056-d5f78b017544
github.com/tx7do/kratos-transport/transport/mcp v1.3.4
github.com/tx7do/kratos-transport/transport/sse v1.3.8
github.com/vektah/gqlparser/v2 v2.5.33        github.com/xiaoqidun/entps v1.56.0
github.com/xuri/excelize/v2 v2.9.1            github.com/yuin/gopher-lua v1.1.2
golang.org/x/image v0.40.0                    google.golang.org/genproto v0.0.0-20260810153831-ec0a7760b754
```

---

## 三、ent schema 层（core 服务）

路径：`app/core/service/internal/data/ent/schema/`（双方）。

### 3.1 文件清单统计

| 指标 | 数字 |
|---|---|
| 我方 schema 文件 | **21** |
| 基座 schema 文件 | **94** |
| 同名文件 | **4**：`api.go`、`menu.go`、`role.go`、`user.go` |
| 仅我方有 | **17**：`department.go`、`notification.go`、`role_api_rel.go`、`role_menu_rel.go`、`sys_config.go`、`uba_event.go`、`upload_task.go`、`user_follow.go`、`user_role_rel.go`、`video.go`、`video_collect.go`、`video_comment.go`、`video_draft.go`、`video_like.go`、`video_report.go`、`video_tag.go`、`video_tag_rel.go` |
| 仅基座有 | **90**（含 `user_credential.go`、`login_policy.go`、`membership*.go` ×4、`permission_group.go`、6 个 audit log、tenant/org_unit/position、content/media/social/ai/task 全域等） |

### 3.2 抽样 1：`user.go`（我方 vs 基座，直接抄代码）

我方（`backend/app/core/service/internal/data/ent/schema/user.go`）：

```go
entsql.Annotation{ Table: "users", Charset: "utf8mb4", Collation: "utf8mb4_bin" }   // 表名 users

Fields()：username(String,Unique,NotEmpty)、password_hash(String,Sensitive,Optional,Nillable)、
          nickname(String,NotEmpty)、avatar_url(String,Optional,Nillable)、bio(String,Optional,Nillable)、
          status(Uint8,Default(2))、department_id(Uint32,Default(0))                      // 共 7 个字段

Mixin()：mixin.AutoIncrementId{}, mixin.TimeAt{}                                        // 共 2 个 mixin

Indexes()：index.Fields("status")                                                       // 共 1 个索引
```

基座（`go-wind-cms/backend/app/core/service/internal/data/ent/schema/user.go`）：

```go
entsql.Annotation{ Table: "sys_users", ... }                                       // 表名 sys_users

Fields()：username、nickname、realname、email(MaxLen 320)、mobile(MaxLen 255)、telephone、
          avatar、address、region、description(MaxLen 1023)、gender(Enum: SECRET/MALE/FEMALE)、
          last_login_at(Time)、last_login_ip(String)、locked_until(Time)、
          status(Enum: NORMAL/DISABLED/PENDING/LOCKED/EXPIRED/CLOSED)              // 共 15 个字段

Mixin()：mixin.AutoIncrementId{}, mixin.OperatorID{}, mixin.TimeAt{}, mixin.Remark{},
         mixin.TenantID[uint32]{}                                                   // 共 5 个 mixin

Indexes()：7 个索引，全部带 tenant_id 前缀（idx_sys_user_tenant_username 等）        // 共 7 个索引
```

字段名交集：`username`、`nickname`、`status`（3 个）；我方独有 `password_hash`、`avatar_url`、`bio`、`department_id`；基座独有 12 个。status 类型不同：我方 `Uint8`（1 禁用 2 正常），基座 `Enum` 6 态。

### 3.3 抽样 2：`role.go`

我方：

```go
Table: "sys_roles"
Fields()：name(String,NotEmpty)、code(String,NotEmpty,Unique)、remark(String,Optional)、
          status(Uint8,Default(2))                                                 // 4 个字段
Mixin()：AutoIncrementId{}, TimeAt{}                                               // 2 个 mixin
Indexes()：index.Fields("status")                                                  // 1 个索引
```

基座：

```go
Table: "sys_roles"                                                                 // 表名相同
Fields()：name、code、is_protected(Bool,Default false)、type(Enum: SYSTEM/TEMPLATE/TENANT)  // 4 个字段
Mixin()：AutoIncrementId{}, TimeAt{}, OperatorID{}, Remark{}, Description{},
         SortOrder{}, TenantID[uint32]{}, SwitchStatus{}                           // 8 个 mixin
Indexes()：10 个（uix_sys_roles_tenant_code 唯一索引等）
```

字段名交集：`name`、`code`（2 个）；我方 `remark`/`status(Uint8)` 对应基座 `Description` mixin/`SwitchStatus` mixin + `type`/`is_protected` 差异字段。

### 3.4 抽样 3：`menu.go`

我方：

```go
Table: "sys_menus"
Fields()：parent_id(Uint32)、name、path、component、icon、sort(Uint32)、type(Uint8: 1目录 2页面 3按钮)、
          permission(String)、visible(Bool)、status(Uint8)                          // 10 个字段
Mixin()：AutoIncrementId{}, TimeAt{}                                               // 2 个 mixin
Indexes()：parent_id、type、status                                                  // 3 个索引
```

基座：

```go
Table: "sys_menus"                                                                 // 表名相同
Fields()：type(Enum: CATALOG/MENU/BUTTON/EMBEDDED/LINK)、path、redirect、alias、name、component、
          meta(JSON, permissionV1.MenuMeta)                                         // 7 个字段
Mixin()：AutoIncrementId{}, TimeAt{}, OperatorID{}, Tree[Menu]{}, Remark{},
         SwitchStatus{}, TenantID[uint32]{}                                        // 7 个 mixin
Indexes()：10 个（idx_sys_menu_parent_name/parent_path 唯一等）
```

字段名交集：`name`、`path`、`component`、`type`（4 个）；基座独有 `redirect`、`alias`、`meta`，我方独有 `parent_id`(显式)、`icon`、`sort`、`permission`、`visible`、`status`。基座引用了生成包 `permissionV1 "go-wind-cms/api/gen/go/permission/service/v1"`（schema/menu.go 第 11 行），我方 schema 无任何 proto 包引用。

> 差异模式（三个抽样一致）：**表名与整体骨架沿用基座（sys_users/sys_roles/sys_menus、AutoIncrementId+TimeAt 起手式、utf8mb4_bin），字段集与 mixin 集为裁剪版**——我方 3 个抽样均只用 2 个 mixin，基座为 5/8/7 个；基座的 `TenantID`/`OperatorID`/`Remark`/`Tree`/`SwitchStatus` 等 mixin 在我方抽样中均未使用。

---

## 四、proto 层（`api/protos/`）

### 4.1 域目录清单对比

| | 清单 |
|---|---|
| 我方域目录（11） | `admin app feed identity interaction notify report stats sysconf uba video` |
| 基座域目录（23） | `admin ai app audit authentication comment conf content dict flow identity interaction internal_message media notify permission site social stats storage task translator webhook` |
| 两边同名域目录（6） | `admin app identity interaction notify stats` |
| 仅基座有（17） | `ai audit authentication comment conf content dict flow internal_message media permission site social storage task translator webhook` |
| 仅我方有（5） | `feed report sysconf uba video` |

### 4.2 proto 文件总量

| 指标 | 数字 |
|---|---|
| 我方 .proto 文件 | **52** |
| 基座 .proto 文件 | **186** |
| 同相对路径文件 | **17**：`admin/service/v1/{admin_error,i_api,i_authentication,i_comment,i_menu,i_navigation,i_role,i_stats,i_user}.proto`、`app/service/v1/{app_error,i_authentication,i_interaction}.proto`、`identity/service/v1/user.proto`、`interaction/service/v1/{interaction,interaction_error}.proto`、`stats/service/v1/{stats,stats_error}.proto` |
| 仅我方 / 仅基座 | **35** / **169** |
| 17 个同路径 proto 中字节相同数 | **0**（`cmp` 全部 DIFFERENT） |

### 4.3 identity 相关域逐文件对比（rpc 方法名清单）

我方 identity 域共 **10 个文件、46 个 rpc、64 个 message**；基座对应为 identity（12 文件/39 rpc）+ permission（13 文件/51 rpc）+ authentication（9 文件/50 rpc）三个域，合计 **34 文件、140 rpc、236 message**。

**UserService**（我方 `api/protos/identity/service/v1/user.proto` vs 基座 `api/protos/identity/service/v1/user.proto`）

| 我方 8 个 rpc | 基座 12 个 rpc |
|---|---|
| `GetUser` `GetUserByUsername` `ListUser` `CreateUser` `UpdateUser` `DeleteUser` `UpdateUserStatus` `GetUserStats` | `List` `Count` `Get` `Create` `BatchCreate` `Update` `Delete` `UserExists` `ListUserOrgUintIDs` `ListUserIDsByOrgUnitIDs` `ListUserPositionIDs` `ListUserIDsByPositionIDs` |

rpc 名称完全相同者：**0**（基座为无资源后缀短命名，我方带 `User` 后缀）。message 数：我方 11 vs 基座 27。

**AuthenticationService**（我方 `api/protos/identity/service/v1/authentication.proto` vs 基座 `api/protos/authentication/service/v1/authentication.proto`）

| 我方 4 个 rpc | 基座 13 个 rpc |
|---|---|
| `Login` `Register` `Logout` `RefreshToken` | `Login` `GetOidcAuthorizeUrl` `Logout` `RegisterUser` `RefreshToken` `ValidateToken` `GetAccessTokens` `RevokeTokenById` `BlockToken` `UnblockToken` `WhoAmI` `GenerateCaptcha` `VerifyCaptcha` |

rpc 名称相同者：`Login`、`Logout`、`RefreshToken`（3 个）；我方 `Register` vs 基座 `RegisterUser`。message 数：我方 6 vs 基座 19。基座 authentication 域另有 8 个文件我方无对应：`mfa.proto`(24 message)、`oauth.proto`(21)、`user_credential.proto`(12)、`login_policy.proto`(7)、`user_token.proto`(1)、`conf.proto`(2)、`operator.proto`(2)、`authentication_error.proto`(0)。

**RoleService**（我方 `api/protos/identity/service/v1/role.proto` vs 基座 `api/protos/permission/service/v1/role.proto`）

| 我方 14 个 rpc | 基座 18 个 rpc |
|---|---|
| `ListRole` `GetRole` `CreateRole` `UpdateRole` `DeleteRole` `SetRoleMenus` `SetRoleApis` `SetUserRoles` `GetRoleMenuIds` `GetRoleApiIds` `GetUserRoleIds` `GetUserRoles` `ListRoleCodesByUserId` `ListUserIdsByRoleCode` | `List` `Count` `Get` `Create` `BatchCreate` `Update` `Delete` `CreateTenantRoleFromTemplate` `ListPermissionIds` `ListRoleCodesByIds` `ListRoleIdsByCodes` `ListUserRoleIDs` `ListUserIDsByRoleIDs` `GetUserRoles` `AssignRolesToUser` `UnassignRolesFromUser` `AssignUsersToRole` `UnassignUsersFromRole` |

rpc 名称相同者：`GetUserRoles`（1 个）。message 数：我方 21 vs 基座 34。基座多出 `RoleOverride`、`RoleMetadata` 等 message。

**MenuService**（我方 `identity/service/v1/menu.proto` vs 基座 `permission/service/v1/menu.proto`）

| 我方 5 个 rpc | 基座 6 个 rpc |
|---|---|
| `ListMenu` `GetMenu` `CreateMenu` `UpdateMenu` `DeleteMenu` | `List` `Count` `Get` `Create` `Update` `Delete` |

rpc 名称相同者：**0**。message 数：我方 6 vs 基座 9（基座多 `MenuMeta`、`MenuRouteItem`、`CountMenuResponse`）。

**ApiService**（我方 `identity/service/v1/api.proto` vs 基座 `permission/service/v1/api.proto`）

| 我方 5 个 rpc | 基座 8 个 rpc |
|---|---|
| `ListApi` `GetApi` `CreateApi` `UpdateApi` `DeleteApi` | `List` `Count` `Get` `Create` `Update` `Delete` `SyncApis` `GetWalkRouteData` |

rpc 名称相同者：**0**。message 数：我方 6 vs 基座 8。我方 api.proto 文件头注释明示「命名沿用 cms：message 为 Api」（第 10–11 行）。

### 4.4 message 字段级 diff（User 与 Role）

**User**（我方 `identity/service/v1/user.proto:49` vs 基座 `identity/service/v1/user.proto:52`）

| 我方 8 个字段（含 tag） | 基座 42 个字段 + 2 个内嵌 enum |
|---|---|
| `id=1` `username=2` `nickname=3` `avatar_url=4` `bio=5` `status=6` `created_at=200` `updated_at=201` | `id=1` `tenant_id=2` `tenant_name=3` `org_unit_id=4` `org_unit_ids=5` `org_unit_name=6` `org_unit_names=7` `position_id=8` `position_ids=9` `position_name=10` `position_names=11` `role_id=12` `role_ids=13` `roles=14` `role_names=15` `username=20` `nickname=21` `realname=22` `avatar=23` `email=24` `mobile=25` `telephone=26` `gender=27` `address=28` `region=29` `description=30` `remark=31` `last_login_at=50` `last_login_ip=51` `status=52` `locked_until=53` `followers=80` `following=81` `post_count=90` `comment_count=91` `like_count=92` `created_by=100` `updated_by=101` `deleted_by=102` `created_at=200` `updated_at=201` `deleted_at=202`；内嵌 `enum Gender`、`enum Status(6 态)` |

字段名相同且 tag 相同者：`id=1`、`created_at=200`、`updated_at=201`；名字相同 tag 不同者：`username`(2 vs 20)、`nickname`(3 vs 21)、`status`(6 vs 52)；语义对应名不同：我方 `avatar_url` vs 基座 `avatar`、我方 `bio` vs 基座 `description`。基座独有 34 个字段（租户/组织/职位/角色冗余、联系方式、锁定、社交计数、软删除三兄弟）。基座字段带 `(gnostic.openapi.v3.property)` 与 `(redact.value)` 注解，我方仅 `[json_name=...]`。

**Role**（我方 `identity/service/v1/role.proto:63` vs 基座 `permission/service/v1/role.proto:67`）

| 我方 7 个字段 | 基座 17 个字段 + 2 个内嵌 enum |
|---|---|
| `id=1` `name=2` `code=3` `remark=4` `status=5` `created_at=200` `updated_at=201` | `id=1` `name=2` `code=3` `sort_order=4` `status=5` `description=6` `is_protected=7` `type=8` `permissions=10(repeated)` `tenant_id=40` `tenant_name=41` `created_by=100` `updated_by=101` `deleted_by=102` `created_at=200` `updated_at=201` `deleted_at=202`；内嵌 `enum Status`、`enum Type(SYSTEM/TEMPLATE/TENANT)` |

字段名+tag 完全相同者：`id=1`、`name=2`、`code=3`、`status=5`、`created_at=200`、`updated_at=201`（6 个）；我方 `remark=4` vs 基座 `description=6`；基座独有 11 个字段。

---

## 五、关键基建层

逐项检查结果（检索方式：`grep -r` 全量 + 文件清单对照；「无」= 全仓 0 命中）：

### 5.1 user_credential（用户凭据）

| | 结论 |
|---|---|
| 我方 | **无**。`grep -ril "user_credential\|UserCredential"` 于我方全部 `*.go/*.proto/*.yaml`：0 命中。 |
| 基座 | 有，4 处：`app/core/service/internal/data/ent/schema/user_credential.go`、`api/protos/authentication/service/v1/user_credential.proto`（12 message）、`internal/data/user_credential_repo.go`、`internal/service/user_credential_service.go`。 |

### 5.2 login_policy（登录策略）

| | 结论 |
|---|---|
| 我方 | **无**。`grep -ril "login_policy\|LoginPolicy"`：0 命中。 |
| 基座 | 有，5 处：`ent/schema/login_policy.go`、`api/protos/authentication/service/v1/login_policy.proto`（7 message）、`internal/data/login_policy_repo.go`、`internal/service/login_policy_service.go`、`api/protos/admin/service/v1/i_login_policy.proto`。 |

### 5.3 membership（成员组织体系）

| | 结论 |
|---|---|
| 我方 | **无**。`grep -ril "membership"`：0 命中。 |
| 基座 | 有：schema 4 个（`membership.go`、`membership_org_unit.go`、`membership_position.go`、`membership_role.go`）、proto 3 个（`identity/service/v1/membership{,_org_unit,_position}.proto`）、repo 4 个（`internal/data/membership*_repo.go`）。 |

### 5.4 permission_group（权限组）

| | 结论 |
|---|---|
| 我方 | **无**。`grep -ril "permission_group\|PermissionGroup"`：0 命中。 |
| 基座 | 有，3 处：`ent/schema/permission_group.go`、`api/protos/permission/service/v1/permission_group.proto`、`internal/service/permission_group_service.go`。 |

### 5.5 viewer / privacy 数据权限体系（ent privacy interceptor）

| | 结论 |
|---|---|
| 我方 | **代码生成层启用了 privacy 特性，但业务层零使用。** 我方 `app.mk:117-121` 与基座 `app.mk:117-121` 逐字节相同，均含 `--feature privacy --feature entql --feature sql/modifier --feature sql/upsert --feature sql/lock`；因此我方存在生成目录 `internal/data/ent/privacy/privacy.go`（生成物）。但在业务代码中（`app/`、`pkg/` 除生成 ent 外）`grep -rn "privacy\."`：仅命中生成文件本身，**无任何 privacy.Policy / privacy interceptor 注册**；`internal/data/client/ent_client.go` 中 `grep "Interceptor"`：0 命中。我方亦无 `pkg/entgo/viewer` 目录。 |
| 基座 | 有 `pkg/entgo/viewer/`、`pkg/entgo/mixin/` 目录；`internal/data/user_repo.go:871` 存在 `viewer.FromContext(ctx)` 调用；`github.com/tx7do/go-crud/viewer v0.0.6` 在基座为直接依赖（我方为 indirect）。 |
| 我方替代物 | `pkg/authctx/authctx.go`（86 行，手写，仅基座没有的同名包）：`UserIDFromContext` / `RolesFromContext` / `IsSuperAdmin` / `IsAuthenticated` / `ClientTypeFromContext` / `IsAdminCaller`，基于 `tx7do/kratos-authn` 的 claims 而非 ent viewer。 |

### 5.6 OperatorMetadata（pkg/metadata 或等价物）

| | 结论 |
|---|---|
| 我方 | **无**。`pkg/` 下目录为 `authctx authorizer middleware oss serviceid` 5 个，无 `metadata`；`grep -rl "OperatorMetadata\|pkg/metadata"`：0 命中。 |
| 基座 | 有：`pkg/metadata/`（`operator_metadata.go`、`operator.go`、`errors.go`、`operator_metadata_test.go`），并被 `internal/service/authentication_service.go` 引用。 |

### 5.7 审计日志（audit log）

| | 结论 |
|---|---|
| 我方 | **无**。`grep -rli "audit"`（*.go/*.proto 全仓，大小写不敏感）：**0 命中**——无 schema、无 proto、无 repo、无 service。 |
| 基座 | 有：schema 6 个（`api_audit_log.go`、`data_access_audit_log.go`、`login_audit_log.go`、`operation_audit_log.go`、`permission_audit_log.go`、`policy_evaluation_log.go`）、独立 proto 域 `api/protos/audit/service/v1/`（9 文件，含 common/device_info/geo_location）、repo 6 个、service 6 个（`internal/service/*_audit_log_service.go`、`policy_evaluation_log_service.go`）。 |

### 5.8 pkg/middleware/auth 实现对照（函数清单逐条）

| | 我方 | 基座 |
|---|---|---|
| 文件数 / 行数 | **1 个**：`auth.go`（198 行） | **6 个**：`auth.go`(131)、`context.go`(25)、`errors.go`(21)、`options.go`(145)、`token_checker.go`(63)、`utils.go`(73)，合计 458 行 |
| 函数清单 | `NewAuthenticator(signingKey)`、`NewServerMiddleware(authenticator, whiteList)`、`NewClientMiddleware()`、`NewClientMiddlewareFor(clientType)`、`NewCoreServerMiddleware()`、`NewAuthzMiddleware(authorizer, whiteList)`、`uint32ToString`、`parseUint32`（8 个） | `Server(opts...Option)`、`NewContext`、`FromContext`、`AccessTokenCheckerFunc.IsValidAccessToken`、`AccessTokenBlockerFunc.IsBlockedAccessToken`、`NewAccessTokenCheckerFromFuncs`、`composedChecker.{IsValidAccessToken,IsBlockedAccessToken}`、`With*` Option ×10（`WithAccessTokenChecker/FromFuncs/EnableCheckRefreshTokenExpiration/EnableCheckScopes/InjectOperatorId/InjectTenantId/InjectEnt/InjectMetadata/EnableAuthority/Logger`）、`NewTokenChecker`、`TokenChecker.{IsValidAccessToken,IsBlockedAccessToken}`、`processAuthz`、`setRequestOperationId`、`setRequestTenantId` |
| 函数名交集 | **0 个**（同名函数一个都没有） | |
| claims 类型 | `authnEngine.AuthClaims`（`tx7do/kratos-authn/engine`） | `authenticationV1.UserTokenPayload`（`go-wind-cms/api/gen/go/authentication`） |

同包异构：`pkg/authorizer/` 我方 1 文件 3 函数（`NewAuthorizer(logger, provider)` / `Engine()` / `ReloadPolicies`），基座 2 文件 11 函数（含 casbin/OPA/Zanzibar/noop 四种 engine 构造）。`pkg/oss/` 我方 1 文件 `minio.go`（122 行）vs 基座 5 文件（`minio.go` 472 行 + `upload_context.go` + `utils.go` + 2 测试），`cmp` 判定 minio.go **内容不同**。`pkg/serviceid/` 我方 1 文件（22 行）vs 基座 3 文件，内容不同。以上 4 个同路径 pkg 包：**无一个文件与基座逐字节相同**。

---

## 六、结论摘要（全部用上文数字作答）

**「后端是否基于基座源码？」——按文件级证据：工程骨架与依赖栈高度同源，但逐文件源码复用接近于零；属于「按基座模式重建（裁剪版）」，不是基座源码的复制或衍生修改。**

| 层 | 数字证据 |
|---|---|
| 目录结构 | 我方 61 个目录中 44 个（72.1%）与基座同名同位（三服务 `app/{admin,app,core}/service` 骨架、`api/protos` 域布局、`pkg/middleware/auth` 等完全对齐）；源文件同路径率 35.3%（172/487）。 |
| 依赖 | 我方 156 个模块中 127 个（81.4%）与基座同名同版本；27 个直接依赖中 26 个（96.3%）与基座直接依赖逐版本号一致；`app.mk` 逐字节相同（含 ent 五个 feature flag）。 |
| ent schema | 同名 schema 仅 4/21（19.0%）；同名者表名沿用（sys_users/sys_roles/sys_menus）但字段为我方裁剪版（User 7 vs 15 字段；mixin 2 vs 5/8/7），基座 TenantID/OperatorID/Tree 等多租户与组织 mixin 全部未用。 |
| proto | 同路径 proto 17/52（32.7%）且 0 个逐字节相同；identity 相关 5 个服务 rpc 命名交集 4 个（Login/Logout/RefreshToken/GetUserRoles），我方 46 rpc vs 基座对应三域 140 rpc；User message 8 vs 42 字段（tag 1/200/201 对齐）。 |
| 关键基建 | 8 项受检设施中 **6 项完全未采纳**（user_credential、login_policy、membership、permission_group、OperatorMetadata、审计日志，均为 0 命中）；viewer/privacy 仅停留在生成层（feature flag 开启、业务层 0 使用）；`pkg/middleware/auth` 与 `pkg/authorizer` 同路径同包名但函数交集为 0。 |
| 逐字节相同文件 | 全仓同路径 172 文件中仅 13 个逐字节相同，其中 12 个为生成代码或纯配置（10 个 `*.pb.validate.go`、`ent/migrate/migrate.go`、`api/buf.yaml`、`app.mk`），**手写业务源码逐字节相同数：0**。 |

一句话量化：**依赖栈 96.3% 对齐（直接依赖逐版本一致）+ 目录骨架 72.1% 对齐 + 生成配置逐字节相同，但手写源码层面 schema 同名率 19.0%、proto 同路径率 32.7%（内容 0% 相同）、中间件函数交集 0%、6/8 项基座数据层基建未引入——即：按基座的架构规约与工具链重建，而非基于基座源码修改。**
