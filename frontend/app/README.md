# GoWind 短视频社区 — Flutter App（shortplay_app）

GoWind 短视频社区的移动端 App。**基于 [go-wind-cms](../../go-wind-cms) 的 Flutter 底座（flutter_app）裁剪适配而来**：保留底座基建（Dio 传输层/认证拦截器/偏好与令牌仓储/主题/通用 cubit/国际化机制），裁掉 CMS 内容业务，按既有 feature 范式新增短剧业务。开发规范见 [AGENTS.md](AGENTS.md)。

## 功能清单

| 模块 | 说明 |
|---|---|
| 沉浸式 Feed（首页） | 上下滑 PageView；当前页自动播放/离开暂停/点击暂停；右侧操作栏（作者头像+关注、点赞、评论数、收藏、分享复制 `http://<API_BASE>/s/{videoId}`）；底部标题/简介/标签/召回原因；游客可刷，互动引导登录；UBA 埋点（PLAY/SWIPE_AWAY/COMPLETE/HEARTBEAT，失败静默） |
| 视频详情 | 单视频沉浸页（复用 feed 播放组件）；更多菜单：举报（原因 BottomSheet + `POST /reports`，409 DUPLICATE_REPORT 提示）；作者本人可删除视频 |
| 评论 | 底部弹窗评论列表；楼中楼（`/comments/{id}/replies`）；发表/删自己评论/评论点赞 |
| 发布 | image_picker 相册选/拍摄 → 标题/简介/标签（标签联想 `GET /tags`）→ 分片上传进度（`POST /uploads` → 循环 `PUT /uploads/{taskId}/chunks/{i}`（octet-stream）→ `POST /uploads/{taskId}/complete`）→ 提交发布或存草稿；草稿箱（列表/提交/删除） |
| 我的 | 统计（`/users/{id}/stats`）+ 创作者中心（`/creator/overview`）+ 作品 Tab（`/users/{id}/videos`，含状态角标）+ 收藏 Tab（`/collects`）+ 编辑资料（`PUT /profile`）+ 退出登录 |
| 他人主页 | 资料/统计/作品 + 关注/取关（409 CANNOT_FOLLOW_SELF 提示） |
| 消息 | 通知列表（赞/评论/关注/系统四类型图标文案）、未读角标（底部导航「消息」Tab）、全部已读、点击带 videoId 通知进视频详情 |
| 搜索 | 关键词搜索（标题模糊+标签精确）+ 热门标签联想；`#标签` 走标签聚合；封面卡片列表进详情 |
| 认证 | 登录/注册（`/auth/login|register|refresh|logout`）；token + 用户信息持久化（SharedPreferences）；401 自动刷新令牌并重放请求 |

## 运行

```bash
cd frontend/app
flutter pub get

# 安卓模拟器（默认 .dev.env 已指向 http://10.0.2.2:7700）
flutter run

# iOS 模拟器（宿主机网络，改用 127.0.0.1）
flutter run --dart-define=API_BASE=http://127.0.0.1:7700 \
            --dart-define=MEDIA_BASE=http://127.0.0.1:9100/shortplay

# 真机（宿主机局域网 IP）
flutter run --dart-define=API_BASE=http://192.168.x.x:7700 \
            --dart-define=MEDIA_BASE=http://192.168.x.x:9100/shortplay
```

- 真机验证要点：手机与后端宿主机需在同一局域网；Android 已开 `usesCleartextTraffic`、iOS 已加 ATS 例外（http 联调用）。
- 测试与静态检查：`flutter analyze`（应 No issues found）、`flutter test`。

## 环境配置

优先级：`--dart-define` > `.env` 文件（debug 读 `.dev.env`，release 读 `.env`）。

| 变量 | 说明 | 默认（debug） |
|---|---|---|
| `API_BASE` / `API_BASE_URL` | app BFF 网关（:7700，路径前缀 /app/v1 由 dio baseUrl 拼好） | `http://10.0.2.2:7700` |
| `MEDIA_BASE` / `MEDIA_BASE_URL` | MinIO 公开访问前缀（对象键拼接），默认桶 `shortplay` | `http://10.0.2.2:9100/shortplay` |
| `CONNECTION_TIMEOUT` / `RECEIVE_TIMEOUT` | 连接/接收超时（秒） | 15 / 30 |

## 目录结构

```
lib/
├── main.dart                # 入口（init → Environments/三方插件/transport/repositories）
├── generated/               # intl_utils 生成的 S 类（勿手改）
├── l10n/                    # intl_zh_CN.arb / intl_en_US.arb（新增文案在此，然后 dart run intl_utils:generate）
└── src/
    ├── app.dart             # ShortPlayApp（MaterialApp.router + EasyLoading + 主题）
    ├── init.dart            # 初始化编排
    ├── app_router/          # GoRouter：底部导航壳（首页/发布/消息/我的）+ 全屏路由
    ├── core/                # 底座基建：config/constants/logic/preference/repositories/services/themes/transport/utilities/widgets
    └── features/            # Feature-First（data/models + services + bloc + pages + widgets）
        ├── auth/            # 登录/注册
        ├── common/          # 共享模型（Video/UserBrief/UserStats…）+ 互动/UBA/举报/标签服务 + 通用组件
        ├── feed/            # 沉浸式 Feed
        ├── video_detail/    # 单视频详情 + 举报
        ├── comment/         # 评论
        ├── publish/         # 发布（分片上传/草稿）
        ├── profile/         # 我的 / 他人主页 / 编辑资料
        ├── notify/          # 消息通知
        └── search/          # 搜索
```

## 与 cms 底座（go-wind-cms/frontend/app/flutter_app）的关系

| 项 | 处理 |
|---|---|
| 项目身份 | 包名 `flutter_app` → `shortplay_app`；Android applicationId/namespace `com.gowind.shortplay`；iOS/macOS Bundle `com.gowind.shortplay`；应用名「GoWind 短视频社区」 |
| 保留 | core 全部基建（transport 拦截器链、UserAuthCache 令牌持久化、主题 cubit、通用 cubit、widgets、工具集）、feature-first 组织范式、cached_query Mutation 写操作范式、flutter_intl 国际化机制 |
| 裁剪 | `features/cms` 整个领域、swagger_parser 生成的 CMS API 客户端（`lib/generated/api`）、租户/验证码/AES 密码加密/SSE/NTP/Sentry 等 CMS 专用配置、cms 遗留文档与测试 |
| 新增 | media_kit 播放内核、image_picker、feed/publish/profile/notify/search/video_detail/comment 七大业务 feature、protojson 解析工具（`jsonInt` 等）、`MediaUrl` 媒体键解析、UBA 埋点服务 |

## 常用命令

```bash
flutter pub get                    # 依赖安装
dart run intl_utils:generate       # arb 变更后重新生成 S 类
flutter analyze                    # 静态检查（须 0 issues）
flutter test                       # 冒烟测试
flutter build apk                  # 安卓打包
flutter build ios --no-codesign    # iOS 打包（不签名）
```
