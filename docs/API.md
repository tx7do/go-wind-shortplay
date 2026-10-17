# REST API 契约（前端对接）

两个网关均由 proto 定义生成，本文是人工可读摘要。字段为 camelCase JSON。完整定义以 `backend/api/protos/` 为准；Swagger：`:6600/docs/`、`:6700/docs/`。

## 约定

- **Base URL**：App 端 `http://<host>:6700/app/v1`；Admin 端 `http://<host>:6600/admin/v1`
- **鉴权**：`Authorization: Bearer <accessToken>`；游客仅白名单接口（Feed/详情/搜索/主页/评论列表）
- **错误响应**（HTTP 状态码 + body）：`{"code":404,"reason":"VIDEO_NOT_FOUND","message":"video not found","metadata":{}}`；reason 枚举见各 `*_error.proto`
- **分页参数**：`page`（从 1 起）+ `pageSize`（缺省 10，上限 50）；部分新接口用 `pageNum/pageSize`（以下逐条标注）；分页响应含 `total`
- **令牌**：登录/注册返回 `authenticator{accessToken, refreshToken, expiresIn, tokenType:"Bearer"}` + `user`；刷新 `POST /app/v1/auth/refresh {refreshToken}`

## App 端（:6700 /app/v1）

### 认证
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/auth/login` | `{username,password}` → LoginResponse |
| POST | `/auth/register` | `{username,password,nickname}` → LoginResponse（409 USERNAME_TAKEN） |
| POST | `/auth/refresh` | `{refreshToken}` |
| POST | `/auth/logout` | 需登录 |

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
| GET | `/notifications?unreadOnly=&pageNum=` | `{items:[{type:LIKE/COMMENT/FOLLOW/SYSTEM,sender,videoId,commentId,content,isRead,createdAt}],total,unreadCount}` |
| PUT | `/notifications/read` `{ids[]}` / PUT `/notifications/read-all` / GET `/notifications/unread-count` | |
| POST | `/reports` | `{targetType:1视频/2评论/3用户,targetId,reason,description?}`；409 DUPLICATE_REPORT |
| POST | `/uba/events` | `{events:[{eventType:1播放/2心跳/3完播/4划走/5赞/6藏/7评/8关注,videoId,durationMs,watchPercent,extra?,occurredAt?}]}`（游客可上报，尽力而为） |

### 分享 H5
`GET /s/{videoId}`（无 /app/v1 前缀）→ 内联 HTML 预览页（OG meta + video 标签）。

## Admin 端（:6600 /admin/v1，均需登录）

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
