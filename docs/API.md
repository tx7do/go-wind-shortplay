# REST API 契约（前端对接）

两个网关均由 proto 定义生成，本文是人工可读摘要。字段为 camelCase JSON。完整定义以 `backend/api/protos/` 为准；Swagger：`:7600/docs/`、`:7700/docs/`。

## 约定

- **Base URL**：App 端 `http://<host>:7700/app/v1`；Admin 端 `http://<host>:7600/admin/v1`
- **鉴权**：`Authorization: Bearer <accessToken>`；游客仅白名单接口（Feed/详情/搜索/主页/评论列表）
- **错误响应**（HTTP 状态码 + body）：`{"code":404,"reason":"VIDEO_NOT_FOUND","message":"video not found","metadata":{}}`；reason 枚举见各 `*_error.proto`
- **分页参数**：`page`（从 1 起）+ `pageSize`（缺省 10，上限 50）；部分新接口用 `pageNum/pageSize`（以下逐条标注）；分页响应含 `total`
- **令牌**：登录/注册返回 `authenticator{accessToken, refreshToken, expiresIn, tokenType:"Bearer"}` + `user`；刷新 `POST /app/v1/auth/refresh {refreshToken}`。access token（JWT HS256）claims：`sub`=用户名、`uid`=用户ID、`tid`=租户ID、`roc`=角色 code 数组、`jti`=令牌ID（登出/刷新即轮换绑定键，旧 access 立即失效）
- **登录密码传输加密**：`password` 字段须为 `base64(AES-CBC(明文, key=iv=<AES_KEY>))`；dev 缺省 key 见 `backend/.env.example`，与前端 `VITE_AES_KEY` 同源，生产必须更换

## App 端（:7700 /app/v1）

### 认证（基座兼容层 /auth/*，推荐）
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/auth/login` | `{grantType:"password", username, password(AES 密文)}` → **`{authenticator:{tokenType:"bearer", accessToken, refreshToken, expiresIn:900}, user:{id, username, nickname, avatarUrl}}`**（无需验证码；401 用户名密码错误） |
| POST | `/auth/register` | `{username, password(AES 密文), nickname}` → 同上包装（成功即登录；409 USERNAME_TAKEN；开放注册开关由 `/sysconf.registerEnabled` 决定） |
| POST | `/auth/refresh` | `{refreshToken}`（无 bearer）→ 同上包装；旧 refreshToken 轮换失效 |
| POST | `/auth/logout` | 需登录，吊销当前会话 |

旧契约面（基座前形状，仍可用）：`POST /login`（同 auth/login）、`POST /refresh-token`、`POST /logout`；响应为扁平 `LoginResponse`（access_token/refresh_token 下划线风格）。**Flutter 走 `/auth/*`**。

图片直传（需登录，app 端 token）：`POST /uploads/image`，body=图片原始字节（Content-Type: image/jpeg|png|webp|gif，≤2MB）→ `{"url":"http://<minio>/images/<hash>.png"}`（头像等通用能力，非分片上传）。

### Feed / 视频
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/feed?tag=&pageNum=&pageSize=` | 游客可访问；`items[]{video, reason:FOLLOW/HOT/LATEST}` + `hasMore`；登录态自动已看去重 |
| GET | `/videos/{videoId}` | 详情：`{video, author, authorStats, viewerState{liked,collected,following}}` |
| GET | `/search/videos?keyword=&pageNum=` | 标题模糊 + 标签精确 |
| GET | `/tags/{tag}/videos?pageNum=` | 标签聚合 |
| GET | `/tags?page=&pageSize=` | 标签列表（发布选择/搜索联想） |

`video` 对象：`{id,title,description,coverUrl,videoUrl,duration,width,height,status:1草稿/2审核中/3已发布/4驳回/5下架,authorId,tags[],likeCount,collectCount,commentCount,viewCount,rejectReason,publishedAt,createdAt}`

### 创作发布（需登录）
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/uploads` | `{fileName,fileSize,chunkSize?}` → UploadTask（task_id/chunk_size/total_chunks；413 FILE_TOO_LARGE / 415 FILE_TYPE_NOT_ALLOWED） |
| PUT | `/uploads/{taskId}/chunks/{chunkIndex}` | **body = 分片二进制原始字节**（Content-Type: application/octet-stream）→ `{uploadedChunks[]}` 顺序上传 |
| POST | `/uploads/{taskId}/complete` | `{title,description?,tags[],coverUrl?,duration,width,height,asDraft?}` → UploadTask（合并+抽帧封面；asDraft=true 存草稿） |
| GET | `/uploads/{taskId}` | 任务状态 |
| POST | `/drafts` / GET `/drafts` / GET·DELETE `/drafts/{id}` | 草稿 CRUD（upsert：带 id 即更新） |
| POST | `/drafts/{id}/submit` | 提交发布（人工审核开→status=2，关→3） |
| PUT | `/videos/{id}` | 编辑本人视频 `{title?,description?,coverUrl?,tags[]}` |
| DELETE | `/videos/{id}` | 删除本人视频 |
| GET | `/creator/overview` | 创作者中心：`{videoCount,totalViews,totalLikes,totalCollects,totalComments,followerCount}` |

### 互动（需登录，除批量状态查询）
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/likes` | `{targetType:1视频/2评论,targetId}` → `{liked,likeCount}`（幂等） |
| DELETE | `/likes/{targetType}/{targetId}` | 取消点赞 |
| POST·DELETE | `/videos/{videoId}/collect` | 收藏/取消 → `{collected,collectCount}` |
| POST | `/interactions/status` | `{videoIds[]}` → `statuses{[id]:{liked,collected}}`（游客全 false） |
| GET | `/collects?page=` | 我的收藏 |
| POST·DELETE | `/users/{userId}/follow` | 关注/取关 → `{following}`；409 CANNOT_FOLLOW_SELF |
| GET | `/following?page=` / `/followers?page=` | `{items:[{user,followedAt}],total}` |

### 评论
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/videos/{videoId}/comments` | `{content,parentId?}`（楼中楼传 parentId） |
| GET | `/videos/{videoId}/comments?pageNum=` | 评论列表（游客可访问） |
| GET | `/comments/{commentId}/replies?pageNum=` | 楼中楼回复列表 |
| DELETE | `/comments/{id}` | 本人可删；403 NOT_OWNER |

`comment` 对象：`{id,videoId,userId,user{id,nickname,avatarUrl},content,parentId,likeCount,replyCount,createdAt}`

### 用户主页 / 通知 / 举报 / 埋点
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/users/{id}` / `/users/{id}/stats` | 主页资料 / `{videoCount,followerCount,followingCount,likeReceivedCount}`（游客可访问） |
| PUT | `/profile` | `{nickname?,avatarUrl?,bio?}`（id 取令牌） |
| GET | `/users/{id}/videos?pageNum=` | 作品列表；本人含审核中/驳回/下架，他人仅已发布 |
| POST | `/notifications/list` | `{page?, pageSize?, unreadOnly?}` → 基座收件箱 `{items:[{id,messageId,status:UNREAD/READ,readAt,title,content,tenantId,createdAt,updatedAt}],total}`（基座 internal_message 承载；业务跳转标记以 `sp-biz:{videoId}` 尾缀附在 content，客户端解析后剔除） |
| POST | `/notifications/read` | `{recipientIds[]}` 标记已读 |
| POST | `/notifications/read-all` | 全部已读 |
| GET | `/notifications/unread-count` | `{"count":"3"}`（int64 字符串） |
| POST | `/reports` | `{targetType:1视频/2评论/3用户,targetId,reason,description?}`；409 DUPLICATE_REPORT |
| POST | `/uba/events` | `{events:[{eventType:1播放/2心跳/3完播/4划走/5赞/6藏/7评/8关注,videoId,durationMs,watchPercent,extra?,occurredAt?}]}`（游客可上报，尽力而为） |

### 分享 H5
`GET /s/{videoId}`（无 /app/v1 前缀）→ 内联 HTML 预览页（OG meta + video 标签）。

## Admin 端（:7600 /admin/v1，均需登录）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/login` / `/logout` | 管理员登录 |
| GET | `/videos?page=&pageSize=` / GET `/videos/{id}` | 视频列表（支持 `?query=` 关键字）/详情 |
| PUT | `/videos/{id}/status` | `{status:2重审/3通过/4驳回/5下架, reason?}`（驳回/下架必填 reason） |
| DELETE | `/videos/{id}` | 删除 |
| GET | `/comments?page=` / DELETE `/comments/{id}` | 评论管理 |
| GET | `/reports?page=&pageSize=&filter=1待处理/2已通过/3已驳回` / GET `/reports/{id}` | 举报工单 |
| PUT | `/reports/{id}/handle` | `{action:1通过处置/2驳回, note?}` |
| GET | `/users?page=&query=` / POST·PUT·DELETE `/users...` / PUT `/users/{id}/status` | 用户管理 |
| GET | `/dashboard/overview` | `{totalVideos,publishedVideos,totalViews,totalLikes,totalComments,totalUsers,todayPublished}` |
| GET | `/dashboard/top-videos?metric=METRIC_VIEW/METRIC_LIKE/METRIC_COLLECT/METRIC_COMMENT&limit=10`（注意：枚举字段用全名） | 排行 |
| GET·PUT | `/sysconf` | `{maxUploadSizeMb,maxDurationSeconds,manualReviewEnabled,registerEnabled,allowedVideoTypes[]}` |

## Admin 端 RBAC（基座原生契约，go-wind-cms 移植）

> 本节为**基座实际契约**（curl 实测口径）：角色/菜单/接口权限/部门（org-units）/组织人事（positions）/导航（routes）/权限码（perm-codes）。
> 端点均在 :7600 /admin/v1，除登录/验证码外需登录；写操作需对应接口权限（Casbin：角色→接口权限点 path+method，路径 `{xxx}` 占位通配匹配；`platform:admin` 为受保护系统角色，种子绑定全部权限点）。
> 列表响应统一 `{items:[...], total}`；枚举为字符串全名、int64 为字符串（protojson 铁律）；`status` 基本为 `ON`/`OFF`。
> CRUD 请求体约定（基座风格）：创建为 `{data:{...}}`，更新为 `{id, data:{...}}`（`data` 内字段可选，带 `updateMask` 可控更新字段）。

### 角色 roles
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/roles?page=&pageSize=` | `{items:[Role], total}`；**Role = `{id,name,code,sortOrder,status:"ON",description,isProtected,type:"SYSTEM"/"CUSTOM",permissions:[权限点id...],tenantId,createdAt,updatedAt}`**（`permissions` 即该角色绑定的接口/功能权限点 id，读随列表下发） |
| POST | `/roles` | `{data:{name,code,sortOrder?,status?,description?,permissions[]}}` |
| GET·PUT·DELETE | `/roles/{id}` | 详情同 Role；更新 `{id, data:{...permissions[]}}`（**permissions 全量覆盖**，权限树勾选提交走这里）；受保护角色（isProtected）禁删 |

### 菜单 menus（前端动态路由源）
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/menus` | **整树** `{items:[Menu], total}`；Menu 含 vben 风格字段：`{id,name,path,component,redirect?,type:CATALOG/MENU/BUTTON/EMBEDDED/LINK,status,meta:{title,icon,order,authority[],...},children[]}`（树形下发，非平铺） |
| POST | `/menus` | `{data:{...}}`；GET·PUT·DELETE `/menus/{id}` 同构 |

### 接口权限 apis（Casbin 策略源）
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/apis?page=&pageSize=&module=` | `{items:[{id,path(含 `{id}` 占位),method:GET/POST/PUT/DELETE,module,moduleDescription,operation,scope,status,description}], total}`（种子 175 条，经 `POST /apis/sync` 从 proto 路由同步） |
| POST | `/apis` · GET·PUT·DELETE `/apis/{id}` · POST `/apis/sync` | CRUD 与路由同步 |

### 权限点 permissions / 权限组 permission-groups / 权限码 perm-codes
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/permission-groups` | 权限组树：`[{id,name,path,module,sortOrder,status,parentId,children[]}]` |
| GET | `/permissions?permissionGroupId={id}` | 组内权限点：`[{id,name,code,description,status,groupId,groupName,menuIds[],apiIds[]}]`（`menuIds/apiIds` 为该权限点关联的菜单/接口；角色 `permissions` 存的是这里的权限点 id） |
| POST | `/permissions` · PUT·DELETE `/permissions/{id}` · POST `/permissions/sync:perms` | CRUD 与同步 |
| GET | `/perm-codes` | **当前登录者**的角色权限码集合：`{"codes":["sys:access_backend","biz:video_manage",...]}`（前端 vben `authority` 比对用） |

### 组织：部门 org-units / 岗位 positions
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/org-units` · POST `/org-units` · GET·PUT·DELETE `/org-units/{id}` | 部门（基座 org_unit 域；树形 parentId） |
| GET | `/positions?page=&pageSize=` · POST `/positions` · GET·PUT·DELETE `/positions/{id}` | 岗位 |
| GET·PUT | `/users/{id}` 详见用户管理；`GET /users/{id}/role-ids` → `{"roleIds":[3]}`；`PUT /users/{id}/roles` `{roleIds:[]}`（**全量覆盖**） | 用户↔角色 |

### 导航 routes / 聚合
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/routes` | **当前用户**可见前端路由树（按角色 authority 过滤，BUTTON 不下发）：`{items:[{path,name,component,children[],meta:{title,icon,order,authority[]}}]}`（前端动态注册路由源） |
| GET | `/initial-context` | 登录后首屏聚合（当前版本空体，预留基座扩展点） |
| GET | `/me` | 当前用户全量：`{id,tenantId,orgUnitIds[],orgUnitNames[],positionIds[],positionNames[],roleIds[],roles:[角色code],roleNames[],username,nickname,realname,email,mobile,gender,address,region,status,createdAt,updatedAt}` |
| PUT | `/me` · POST `/me/password` `{oldPassword,newPassword}` · POST `/me/contact` `/me/contact/verify` | 个人资料/改密/绑定联系方式 |
| POST | `/refresh-token` | 会话续期：HttpOnly 刷新 Cookie + uid/jti 绑定键轮换（80% 生命周期内前端静默续期；无 token 凭 Cookie 恢复会话） |

## Admin 端站内信（internal-message）与通知 SSE

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/internal-message/inbox?page=&pageSize=` | **本人收件箱**：`{items:[{id,messageId,recipientUserId,status:UNREAD/READ,readAt,title,content,tenantId,createdAt,updatedAt}],total}` |
| POST | `/internal-message/read` | `{recipientIds[]}`（空数组 = 全部已读）标记已读 |
| POST | `/internal-message/inbox/delete` | `{recipientIds[]}` 从收件箱移除 |
| GET·POST | `/internal-message/messages` · GET·PUT·DELETE `/internal-message/messages/{id}` | 站内消息管理 |
| POST | `/internal-message/send` | `{type?, recipientUserId?, categoryId?, targetUserIds[], targetAll?, title, content,...}` 发送（举报工单创建时自动向 platform:admin 用户推送） |
| POST | `/internal-message/revoke` · GET·POST·PUT·DELETE `/internal-message/categories...` | 撤回 / 分类管理 |

**通知实时推送（SSE）**：admin BFF 独立 SSE 端口 **:7601**，路径 `/events`（`text/event-stream`）。连接契约：`GET :7601/events?stream=<accessToken>`，且 `stream` 参数必须与 `Authorization: Bearer <accessToken>` 为**同一令牌**（不一致 403 FORBIDDEN "stream does not match token"），鉴权也接受 `X-Token` 头。前端登录成功后建立连接，站内信/通知经 Redis Pub/Sub 链路实时推送，前端 5 分钟轮询兜底。

## Admin 端增补（视觉与工作台）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/uploads/image` | 图片上传：body=图片原始字节（Content-Type: image/jpeg|png|webp|gif，≤2MB）→ `{url}`（MinIO 公网地址；需登录+接口权限）。App 端同款：`POST :7700/app/v1/uploads/image`（app 端 token） |
| GET | `/videos?authorId=` | 视频列表新增按作者过滤（用户管理"查看作品"用） |
| GET | `/dashboard/trends?days=7`（1-30，缺省 7） | 近 N 日趋势：`{items:[{date:"2026-10-18",published:0,plays:0,likes:0}]}`（published 按视频 published_at 落日统计；plays/likes 按 uba_events 当日事件计数：VIDEO_PLAY/VIDEO_LIKE） |

---

## Phase 2 移植说明（go-wind-cms 基座承载，2026-10-18）

> 上文契约形状**全部保持不变**（两个前端零改动兼容）。本节是 Phase 2 在基座上重写后的实现口径与已知差异。

### 兼容性保持
- App/Admin 全部业务路由、消息形状、枚举名、错误 reason 与旧版一致；`/app/v1/uploads/{taskId}/chunks/{i}` 仍为 **raw octet-stream**（手工路由）。
- 管理端新增/接管路由：`GET /admin/v1/routes`（动态菜单，形状见「Admin 端 RBAC」）、`GET /admin/v1/dashboard/trends`、`POST /admin/v1/uploads/image`、用户管理（基座 identity 域承载，形状 = 旧 AppUser 契约）、评论管理（interaction 域承载）。

### 已知差异（前端注意）
- **App 消息中心已接基座站内信**：`/app/v1/notifications/list|read|read-all|unread-count`（形状见「用户主页 / 通知 / 举报 / 埋点」节）；旧 notify 域的 `sender/videoId/commentId` 结构化字段不再下发，业务跳转改由 content 尾缀 `sp-biz:{videoId}` 标记承载。
- 管理端角色/菜单/权限点页面走基座 RBAC 契约（形状与旧版「RBAC 扩展」节不同，见重写后的「Admin 端 RBAC」节；动态菜单端点为 `GET /admin/v1/routes`，旧 `/navigation` 已不存在）。
- `GET /admin/v1/users` 的 `query` 按昵称模糊、`filter` 按状态（1禁用/2正常）；视频列表 `query`=标题模糊、`filter`=状态（1草稿/2审核中/3已发布/4驳回/5下架）、支持 `authorId=`；举报列表 `filter`=工单状态（1待处理/2已通过/3已驳回）。
