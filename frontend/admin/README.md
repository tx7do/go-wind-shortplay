# GoWind 短视频社区 · 管理后台（go-wind-shortplay-admin）

基于 go-wind-cms 的 Ant Design Pro v6 管理后台底座裁剪适配而来：
保留外壳与基建（布局 / 路由 / 鉴权 / 偏好设置 / i18n / 传输层），裁掉 CMS 业务模块，
按底座既有模式新增短视频社区业务模块。

## 技术栈

React 19 + Vite + TypeScript + Ant Design 6 + @ant-design/pro-components +
@tanstack/react-query + zustand + react-router-dom 6 + 自研
router/access/preferences/i18n 体系。

## 启动

```bash
pnpm install          # 必须用 pnpm（patches/ 有 pnpm patch 依赖）
pnpm dev              # 开发模式，端口 15999（.env VITE_SERVER_PORT）
pnpm typecheck        # tsc 类型检查
pnpm build            # 生产构建
```

> Node 版本要求 ≥ 20.19（Vite 8 / rolldown 需要；本机系统默认 20.10 时可用
> scoop 的 nodejs/current ≥20.19 提升 PATH 后再执行 pnpm dev / build）。
> 端口被占用时 vite 会自动顺延（如 16001）。

- 后端联调：`.env.development` 的 `VITE_PROXY` 将 `/admin` 前缀请求代理到
  `http://127.0.0.1:6600`（不做 rewrite，与后端 `/admin/v1` 路由前缀天然对齐）。
- 演示账号：`admin / admin`。

## 模块清单

| 菜单 | 路由 | 说明 |
| --- | --- | --- |
| 数据看板 | `/dashboard` | 7 统计卡 + 视频 TOP10 排行（播放/点赞/收藏/评论指标切换） |
| 视频管理 | `/videos` | 状态 Tab + 标题搜索 + 详情抽屉（video 预览）+ 审核/驳回/下架/恢复发布/删除 |
| 评论管理 | `/comments` | 全量评论列表 + 删除 |
| 举报管理 | `/reports` | 状态 Tab + 工单详情 + 通过处置/驳回（备注） |
| 用户管理 | `/users` | 用户列表 + 新建/编辑（重置密码）+ 启用禁用 + 删除 |
| 系统配置 | `/sysconf` | 上传上限/时长上限/人工审核/开放注册/允许的视频格式 |

接口契约见 `docs/API.md` 的「Admin 端（:6600 /admin/v1）」一节。

## 与 CMS 底座的关系

- 目录约定、页面写法（ProTable/ListTable/ProForm/Drawer/Modal）、
  布局与偏好设置、静态路由 + 权限过滤机制全部沿用底座。
- 登录/鉴权已适配 shortplay Admin BFF（`POST /admin/v1/login`，无 MFA/SSE/refresh 链路，
  401 直接回登录页）。
- CMS 业务（内容/媒体/协作/租户/权限/日志/AI 等）已整体裁剪。
