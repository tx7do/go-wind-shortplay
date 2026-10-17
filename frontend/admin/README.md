# GoWind 短播社区 · 管理后台前端

`go-wind-shortplay` 的管理后台（Admin）前端，基于 **Vite + React 18 + TypeScript + Ant Design 5 + React Router 6 + axios** 构建，对接 Admin 网关 `http://<host>:6600/admin/v1`（REST 契约见 `docs/API.md`）。

## 功能页面

| 菜单 | 路由 | 说明 |
| --- | --- | --- |
| 数据看板 | `/dashboard` | 运营总览统计卡片（总视频/在线视频/总播放/总点赞/总评论/用户数/今日发布）+ 视频 TOP10 排行（按播放/点赞/收藏/评论切换） |
| 视频管理 | `/videos` | 视频列表（分页、状态 Tab 筛选、标题关键字搜索）；状态 Tag（1 草稿 / 2 审核中 / 3 已发布 / 4 驳回 / 5 下架）；详情抽屉（`<video>` 在线预览、封面、简介、标签、驳回原因）；审核通过、驳回 / 下架（必填原因）、删除 |
| 评论管理 | `/comments` | 全量评论列表（分页），删除违规评论（二次确认） |
| 举报管理 | `/reports` | 举报工单列表（状态 Tab：待处理 / 已通过 / 已驳回）；工单详情；处理（通过并处置 / 驳回，可填备注） |
| 用户管理 | `/users` | 用户列表（分页、关键字搜索）；创建用户（用户名/密码/昵称）；编辑（昵称/简介/重置密码）；启用 / 禁用；删除 |
| 系统配置 | `/sysconf` | 上传大小上限、时长上限、人工审核开关、开放注册开关、允许的视频类型（逗号分隔输入，保存时解析为数组） |

## 快速开始

```bash
cd frontend/admin
npm install            # 若默认源不通，可换：npm install --registry=https://registry.npmmirror.com
npm run dev            # 启动开发服务器 http://localhost:5173
npm run build          # 类型检查（tsc）+ 生产构建，输出到 dist/
npm run preview        # 本地预览生产构建
```

### 演示账号

登录页已注明演示账号：**admin / admin**。

> 注意：后端没有预置管理员账号，需要先注册该账号（可通过 App 端接口 `POST /app/v1/auth/register`，body：`{"username":"admin","password":"admin","nickname":"管理员"}`），否则登录返回用户不存在。

### 后端地址与跨域

- 默认请求基地址为 `http://127.0.0.1:6600`（Admin 网关），可用环境变量 `VITE_API_BASE` 覆盖。
- 开发态（`.env.development`）默认 `VITE_API_BASE=/api`：后端网关未开启 CORS，Vite 开发服务器将 `/api` 代理转发到 `http://127.0.0.1:6600`（见 `vite.config.ts`），浏览器无跨域问题。
- 若生产部署前端与网关不同源，请在网关侧开启 CORS，或将静态资源与网关同域部署，并通过 `VITE_API_BASE` 指定网关地址后重新构建。

## 鉴权说明

- 登录成功后 `accessToken` 与用户信息存入 `localStorage`（`admin_token` / `admin_user`）。
- 所有请求自动携带 `Authorization: Bearer <token>`。
- 收到 `401` 时自动清除本地登录态并跳回登录页。
- 后端错误结构 `{"code":..,"reason":"..","message":".."}` 中的 `message` 通过 antd message 统一弹出提示。

## 目录结构

```
frontend/admin
├── index.html                  # HTML 入口
├── vite.config.ts              # Vite 配置（@ 别名、/api 开发代理）
├── .env.development            # 开发态环境变量（VITE_API_BASE=/api）
└── src
    ├── main.tsx                # 应用入口（antd 中文 locale + AuthProvider）
    ├── App.tsx                 # 路由与登录守卫（HashRouter）
    ├── index.css               # 全局样式
    ├── api/                    # 接口封装（axios 统一 request + 各资源 API）
    │   ├── request.ts          # axios 实例：baseURL、Token 注入、错误提示、401 处理
    │   ├── page.ts             # 分页响应归一化
    │   ├── auth.ts             # 登录 / 登出
    │   ├── video.ts            # 视频列表 / 详情 / 状态流转 / 删除
    │   ├── comment.ts          # 评论列表 / 删除
    │   ├── report.ts           # 举报工单列表 / 详情 / 处理
    │   ├── user.ts             # 用户 CRUD / 启用禁用
    │   ├── dashboard.ts        # 看板总览 / TOP 排行
    │   └── sysconf.ts          # 系统配置读写
    ├── components/
    │   └── VideoDetailDrawer.tsx   # 视频详情抽屉（含视频预览）
    ├── layouts/
    │   └── MainLayout.tsx      # 主布局（左侧菜单 + 顶栏用户名/退出）
    ├── pages/
    │   ├── login/              # 登录页
    │   ├── dashboard/          # 数据看板
    │   ├── videos/             # 视频管理（审核 / 驳回 / 下架 / 删除）
    │   ├── comments/           # 评论管理
    │   ├── reports/            # 举报管理
    │   ├── users/              # 用户管理
    │   └── sysconf/            # 系统配置
    ├── types/                  # 与后端契约对应的共享类型
    └── utils/                  # 登录态 Context（auth.tsx）与格式化工具（format.ts）
```

## 已知说明

- 视频列表的「状态 Tab」与「关键字搜索」按契约以 `filter` / `query` 查询参数发送；当前后端 `ListVideo` 实现未消费这两个参数（仅分页返回全量），筛选生效需等后端支持，前端无需改动。
- React 采用 18.3（而非 19）：antd v5 对 React 19 需要额外兼容补丁，为保证构建与运行时稳定直接使用 React 18.3。
