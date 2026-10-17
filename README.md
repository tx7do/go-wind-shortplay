<div align="center">

# GoWind ShortPlay

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Go Version](https://img.shields.io/badge/Go-1.26+-00ADD8?logo=go&logoColor=white)](https://go.dev/)
[![React](https://img.shields.io/badge/React-19.x-61DAFB?logo=react&logoColor=white)](https://react.dev/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Kratos](https://img.shields.io/badge/Kratos-2.9-00ADD8?logo=go&logoColor=white)](https://go-kratos.dev/)

**风行短剧** — GoWind 生态企业级短视频社区（开源基础版 MVP）：上下滑沉浸式视频流、发布、互动、后台审核。

</div>

---

> ✅ **当前状态：开源版全量代码完成** —— 后端（含楼中楼评论/创作者统计/分享 H5/三路召回 Feed/UBA/举报闭环）、React 管理后台（视频审核/评论/举报/用户/看板/系统配置）、Flutter App（沉浸式播放器/发布/主页/消息/搜索）三端全部可构建。全量功能清单见 [docs/API.md](./docs/API.md)。

## 产品定位

- **B 端企业视频内容社区**，弱化「仿抖音」，只保留上下滑沉浸式视频体验
- 小流量企业内部场景**可直接上线**（docker compose 一键起）
- **不含**（归商业闭源增值包）：多码率转码集群、AI 推荐、内容安全审核、SaaS 多租户、直播

## 技术栈

| 层 | 技术 |
|----|------|
| 后端 | Go 1.26 + go-kratos v2.9 + entgo（Ent ORM）+ buf（protobuf-first） |
| 存储 | PostgreSQL / MySQL（双支持）+ Redis + MinIO |
| 媒体 | FFmpeg 单帧抽图封面（缺失静默降级）；原始单码率直出 |
| 管理后台 | React 18 + Ant Design 5 + Vite（frontend/admin） |
| 移动端 | Flutter + BLoC + media_kit（frontend/app） |

## 架构

```
React Admin ──▶ admin-service (BFF :6600) ──┐
                                            ├──gRPC──▶ core-service (:6900, 唯一数据落点)
Flutter App ──▶ app-service   (BFF :6700) ──┘              │
                                        PostgreSQL / Redis / MinIO / FFmpeg
```

- **admin / app 是瘦网关 BFF**（参数校验 + 转发），所有业务与数据操作收敛在 core
- 领域拆分体现在 proto 与 core 内部模块上（video / feed / interaction / report / uba / sysconf / notify / identity / stats），不体现在进程上
- 服务拆分研判与商业版扩展路径见 `docs/ROADMAP.md`

## 快速开始

### 移动端

```bash
cd frontend/app
flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:6700   # 安卓模拟器缺省 10.0.2.2
```

### 管理后台

```bash
cd frontend/admin
npm install
npm run dev    # 开发态经 Vite 代理访问 :6600；演示账号 admin / admin（core 首次启动自动播种）
```

### 后端

```bash
# 0) 初始化工具链（首次）
cd backend && make init

# 1) 起基础设施（PostgreSQL / Redis / MinIO）
docker compose -f docker-compose.libs.yaml up -d

# 2) 生成代码并启动三服务（三个终端）
make gen
cd app/core/service  && make run   # gRPC :6900（启动即自动建表）
cd app/admin/service && make run   # REST :6600
cd app/app/service   && make run   # REST :6700

# 3) 冒烟验证
curl -X POST http://127.0.0.1:6700/app/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo","password":"demo123","nickname":"Demo"}'
```

API 文档：服务启动后访问 `http://127.0.0.1:6600/docs/`、`http://127.0.0.1:6700/docs/`（Swagger）。

一键容器化部署：`docker compose up -d --build`。

## 功能清单（Phase 1 开源 MVP）

- **视频**：分片上传（断点续传友好）、合并入库 MinIO、FFmpeg 抽帧封面、草稿箱、状态机（草稿→审核→发布/驳回→下架）
- **Feed**：沉浸式上下滑、三路规则召回（关注最新 / 热门加权 / 最新兜底）、Redis 已看去重、标签聚合
- **互动**：点赞（视频/评论）、收藏、关注（粉丝列表）、评论（楼中楼字段预留）、通知（点赞/评论/粉丝/系统）
- **后台**：视频管理（审核/驳回/下架/删除）、评论管理、举报工单（通过即联动处置目标）、用户管理、数据看板、系统配置（上传限制/时长限制/人工审核开关）
- **通用**：JWT 认证（游客可浏览）、UBA 埋点（观看/完播/划走，服务 Feed 排序）、举报闭环、文件类型与大小校验（内容安全仅预留钩子）

## 里程碑

| 周 | 内容 | 状态 |
|----|------|------|
| 1 | Proto 契约、脚手架、鉴权、数据库表设计 | ✅ |
| 2 | 后台视频管理页面（React Admin）、上传转码异步化 | ✅ |
| 3 | 互动 + Feed + UBA | ✅ |
| 4 | Flutter 首页播放器、发布、个人主页 | ✅ |
| 5 | 评论弹窗（含楼中楼）、通知、举报联动 | ✅ |
| 6 | 文档、部署脚本、开源清理、发布 | ✅ 文档与部署脚本就绪，待端到端联调 |

## 文档

- [后端开发规范](./backend/AGENTS.md) — AI 编码工具与人类贡献者共同遵守
- [架构决策与服务拆分研判](./docs/ROADMAP.md)

## License

[MIT](./LICENSE)
