# AGENTS.md — go-wind-shortplay-admin

GoWind 短视频社区管理后台（shortplay），从 go-wind-cms/frontend/admin 底座裁剪适配。

## 约定

- **包管理器**：pnpm（`patches/` 依赖 pnpm patch，勿用 npm/yarn）。
- **接口前缀**：所有业务请求走 `src/api/client.ts` 的 `adminHttp`，统一 `admin/v1/*`；
  vite 代理把 `/admin` 原样转发到 `127.0.0.1:7600`（无 rewrite）。
- **protojson 铁律**：枚举字段是字符串全名（`"VIDEO_STATUS_PUBLISHED"`）；
  int64/uint64 是 JSON 字符串；uint32/int32 是数字。提交枚举必须传全名。
- **路由**：静态路由模式（`preferences.app.accessMode = "frontend"`）。
  业务路由放 `src/router/modules/*.tsx`，页面放 `src/pages/app/<module>/`，
  菜单名走 `routes:` 命名空间词条。
- **页面写法**：列表用 `ListTable`（底座封装的 ProTable）+ `ContentContainer`；
  表单用 pro-components（DrawerForm/ProForm）；状态枚举映射集中在各模块
  `constants.ts`；文案全部走 i18n（`src/locales/{zh-CN,en-US}/_modules/*.json`）。

## 鉴权

- `src/stores/auth.ts`：登录调 `POST admin/v1/login`，accessToken + userInfo 持久化于
  `auth-storage`；无 refresh 端点，401 由 transport 拦截器 forceLogout 回登录页。
- 角色固定 `super_admin`（登录时写入 userStore），路由未配置 authority 即全放行。

## 常用命令

```bash
pnpm dev         # http://localhost:16800
pnpm typecheck   # tsc -p tsconfig.app.json --noEmit
pnpm build       # vite build
pnpm lint        # eslint
```
