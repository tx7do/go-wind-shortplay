# AGENTS.md — go-wind-shortplay-admin

GoWind 短视频社区管理后台（shortplay），从 go-wind-cms/frontend/admin 底座源码裁剪适配。

## 约定

- **包管理器**：pnpm（`patches/` 依赖 pnpm patch，勿用 npm/yarn）。
- **接口前缀**：所有业务请求走 `src/api/client.ts` 的 `adminHttp`，统一 `admin/v1/*`；
  vite 代理把 `/admin` 原样转发到 `127.0.0.1:7600`（无 rewrite，`.env.development` 的 `VITE_PROXY`）。
- **protojson 铁律**：枚举字段是字符串全名（`"VIDEO_STATUS_PUBLISHED"`）；
  int64/uint64 是 JSON 字符串；uint32/int32 是数字。提交枚举必须传全名。
- **路由**：**后端动态菜单模式为主**（`src/core/preferences/config/default.ts` 的
  `app.accessMode = "backend"`）。登录后拉取 `GET admin/v1/navigation`（shortplay 自定义
  菜单契约）映射本地页面组件（`layoutMap`/`pageMap`，键为 normalize 后的页面路径；
  后端复数 component 标识与本仓单数目录名靠 `COMPONENT_ALIAS_KEYS` 兼容）；
  **navigation 拉取失败 / 为空时整树回退静态路由**（前端模式，`src/router/modules/*.tsx`
  + `src/router/config/static.ts`），登录不闪断。页面放 `src/pages/app/<module>/`，
  菜单名走 `routes:`/`menu:` 命名空间词条。
- **页面写法**：列表用 `ListTable`（底座封装的 ProTable）+ `ContentContainer`；
  表单用 pro-components（DrawerForm/ProForm）；状态枚举映射集中在各模块
  `constants.ts`；文案全部走 i18n（`src/locales/{zh-CN,en-US}/_modules/*.json`）。

## 鉴权与会话

- **登录链路（基座同款，`src/stores/auth.ts`）**：登录页先 `GET admin/v1/captcha`
  取图形验证码 → `POST admin/v1/login`，验证码经 `X-Captcha-Id` / `X-Captcha-Value`
  请求头一次性携带，密码经 AES-128-CBC 加密（`src/utils/crypto.ts`，key=iv=
  `VITE_AES_KEY`，未注入时回退 dev key「f51d66a73d8a0927」，须与后端 `AES_KEY`
  一致）后传输；登录成功后拉 `/me`（角色/资料）与 `/perm-codes`（权限码集合，
  供 vben `authority` 比对），accessToken + userInfo 持久化于 `auth-storage`。
- **会话续期（`src/hooks/useTokenRefresh.ts`）**：access token 到期前（剩余时间的
  80% 减安全垫）静默 `POST admin/v1/refresh-token`（凭 HttpOnly 刷新 Cookie，
  `refresh_exp` cookie 只含过期时间戳）；缺失或临期 → forceLogout 回登录页。
  401 由 transport 拦截器 forceLogout。
- **SSE 实时通知**：登录成功后连 `VITE_SSE_URL`（缺省 `http://localhost:7601/events`），
  契约 `?stream=<accessToken>` 且与 `Authorization: Bearer` 同一令牌；token 刷新后
  重连，登出断开（`src/core/transport/sse/` + `useTokenRefresh`）。
- 权限码：种子角色 `platform:admin` 绑定全部权限点（`sys:*` + `biz:*`，见
  `pkg/constants/permission.go`）；路由/按钮 authority 用 `perm-codes` 返回的码比对。

## eslint 配置降级策略

`eslint.config.js` 在基座规则之上追加两段：

1. `@typescript-eslint/no-unused-vars`：下划线前缀（`_x`）视为有意不用，不上报。
2. **基座拷贝代码豁免**：`src/core/**`、`src/layouts/**`、`src/components/**`、
   `src/utils/**`、`src/locales/**`、`src/pages/app/permission/**` 等与上游
   go-wind-cms 基座对齐的目录，`no-explicit-any`、`no-unused-vars`、
   `react-hooks/exhaustive-deps`、`set-state-in-effect`、`rules-of-hooks`、
   `react-hooks/refs`、`react-hooks/immutability`、`no-useless-assignment`
   降为 **warn**（不 off，保留可观测性）——避免为消告警制造与上游的巨 diff。
   本仓自写代码（`pages/app/**` 业务页、`api/**`、`stores`、`router/index`、
   登录页等）不在豁免范围，仍按 error 档逐条真修。

## 常用命令

```bash
pnpm dev         # http://localhost:16800（.env.development 的 VITE_SERVER_PORT）
pnpm typecheck   # tsc -p tsconfig.app.json --noEmit
pnpm build       # vite build（生产模式）
pnpm lint        # eslint .
```

门禁：`pnpm run typecheck` + `pnpm run lint` 全绿（新增告警一律按自己引入处理）。
