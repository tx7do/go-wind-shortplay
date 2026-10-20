# AGENTS.md — GoWind 短视频社区 Flutter App 开发指南

> 本文件是 `frontend/app` 子项目（包名 `shortplay_app`）的 AI 编码规范单一事实源，适用于所有支持 AGENTS.md 的 AI 编码工具。

## 项目概览

GoWind 短视频社区（shortplay）移动端 App。**基于 go-wind-cms 的 Flutter 底座裁剪适配而来**：保留底座基建（transport/preference/repositories/themes/logic/widgets 组织范式），裁掉 CMS 内容业务，按既有 feature 范式新增短剧业务。

**核心技术栈**：Flutter 3.x (Dart 3.12+) + flutter_bloc/Cubit（状态管理）+ GoRouter（StatefulShellRoute 底部导航）+ GetIt（IoC）+ Dio（HTTP）+ media_kit（短视频播放）+ image_picker（拍摄/选视频）+ cached_query（缓存/Mutation）+ flutter_screenutil（响应式）+ encrypt（登录密码 AES 传输加密）+ flutter_intl/intl_utils（i18n）+ Material 3（仅作骨架，其上叠加品牌设计语言，见硬性约束 7）

## 硬性约束

1. **不要绕开底座自建简化结构**。新功能必须遵循既有范式：
   - service 继承 `core/services/base_service.dart` 的 `BaseService`（获得 logger / currentUserId / `handleDioError`）；
   - 写操作用 `cached_query` 的 `Mutation`，列表读用 bloc/cubit + 分页；
   - 网络一律走 GetIt 里的全局 `Dio`（baseUrl、认证拦截器已配好）。
2. **protojson 序列化铁律**（后端为 protojson）：
   - `int64/uint64` 字段是 **JSON 字符串**（likeCount/collectCount/commentCount/viewCount/total/unreadCount/fileSize/durationMs 等）→ 用 `core/utilities/convert.dart` 的 `jsonInt` 解析，发送时 `'$value'`；
   - `uint32` 是数字（id/videoId/duration/width/height/pageNum/watchPercent 等）；
   - 枚举是**字符串全名**（`VIDEO_STATUS_PUBLISHED`、`TARGET_TYPE_VIDEO`、`REPORT_TARGET_TYPE_VIDEO`、`EVENT_TYPE_VIDEO_PLAY`、`FEED_REASON_LATEST`…），请求也要传全名（见各 feature 常量类）。
3. **登录密码传输加密**：`/auth/login|register` 的 password 字段为 `base64(AES-CBC(明文, key=iv=AES_KEY))`（PKCS7），实现在 `features/auth/services/authentication_service.dart` 的 `_encryptPassword`，密钥来自 `Environments.aesKey`（`.dev.env` 的 `AES_KEY`，缺省回退 dev key「f51d66a73d8a0927」，**须与后端 `AES_KEY` 一致**）。
4. 后端契约以 `docs/API.md`「App 端（:7700 /app/v1）」为准；错误响应为 HTTP 状态码 + `{code,reason,message,metadata}`，用 `ApiStatusException(handleDioError(e))` 抛出、UI 层用 `localizedApiErrorMessage` 转文案。
5. 新增/修改文案必须进 `lib/l10n/intl_zh_CN.arb` 与 `intl_en_US.arb`，然后 `dart run intl_utils:generate`（生成到 `lib/generated`，已从 analyze 排除）。
6. `flutter analyze` 必须保持 **No issues found**；平台目录（android/ios）改动要真实可用，不留 TODO 占位。
7. **品牌设计语言**（`docs/design-language.md` §5，权威值表）：去 MD3 化——品牌色/语义色板只取
   `core/themes/app_colors.dart`（`BrandColor` / `LightPalette` / `DarkPalette`），组件内禁止裸色值；
   页面级 CTA 用 `GradientButton`、空态用 `EmptyState`、底导只用 `AppBottomNavBar`（自绘、无 MD3 胶囊
   指示器）；品牌标用 `BrandLogoMark`。新页面必须沿用，改视觉值先改文档再改代码。

## 目录结构

```
lib/
├── main.dart                      # 入口（init + AppThemeCubit + ShortPlayApp）
├── generated/                     # intl_utils 生成（勿手改，analyze 已排除）
├── l10n/                          # intl_zh_CN.arb / intl_en_US.arb（文案单一事实源）
└── src/
    ├── app.dart                   # ShortPlayApp（MaterialApp.router）
    ├── init.dart                  # Environments → 三方插件 → transport → repositories
    ├── app_router/                # GoRouter：StatefulShellRoute 四 Tab + 全屏路由
    │   ├── app_router.dart        #   （export RouteNames/AppRoutePath）
    │   └── route_names.dart
    ├── core/                      # 底座基建（与业务无关，勿放业务代码）
    │   ├── config/environments.dart   # API_BASE/MEDIA_BASE/AES_KEY：dart-define > .env
    │   ├── constants/                 # router_paths / breakpoints / global
    │   ├── logic/                     # 通用 cubit（api/page/connectivity/text_changed）
    │   ├── preference/                # 用户偏好（语言/主题）
    │   ├── repositories/              # UserAuthCache（token+用户信息+JWT userId）/偏好缓存
    │   ├── services/                  # BaseService / PaginationQuery+PageData
    │   ├── themes/                    # 亮暗主题 / AppThemeCubit / app_colors（品牌设计令牌）
    │   ├── transport/http/            # Dio 封装 / 认证拦截器 / Status / ApiStatusException
    │   ├── utilities/                 # convert(jsonInt…) / media_url / number_format / logger…
    │   └── widgets/                   # AppBottomNavBar(自绘底导) / GradientButton / EmptyState / BrandLogo / error / not_found
    └── features/                  # Feature-First（data/models + services + bloc + pages + widgets）
        ├── auth/                  # 登录/注册（/auth/login|register|refresh|logout，密码 AES 加密）
        ├── common/                # 跨 feature：models(Video/UserBrief/UserStats…) + 互动/UBA/举报/标签服务 + 通用组件
        ├── feed/                  # 沉浸式 Feed（PageView + media_kit + UBA 埋点）
        ├── video_detail/          # 单视频沉浸页（复用 feed 播放组件）+ 举报
        ├── comment/               # 评论面板（楼中楼/发表/删除/点赞）
        ├── publish/               # 发布（分片上传/草稿/挂靠剧集选择）
        ├── series/                # 剧集（详情选集/我的剧集列表/发布选剧弹层）
        ├── profile/               # 我的 + 他人主页 + 编辑资料（头像直传 /uploads/image）
        ├── notify/                # 消息（基座收件箱 notifications/*；sp-biz 尾标记解析 videoId 直达视频）
        └── search/                # 搜索（关键词/标签聚合）
```

另有 `features/settings/`（系统设置页 `/settings`：外观/语言设备级偏好，游客可用）。

## 后端联调

- App BFF：`http://<host>:7700/app/v1`；媒体（MinIO 公开读）：`http://<host>:9000/shortplay`（bucket 缺省 `shortplay`，与后端 `OSS_PUBLIC_ENDPOINT` 同源口径）。
- 默认 `.dev.env` 指向安卓模拟器（10.0.2.2）；覆盖方式：
  ```
  flutter run --dart-define=API_BASE=http://<局域网IP>:7700 --dart-define=MEDIA_BASE=http://<局域网IP>:9000/shortplay
  ```
- 后端返回的 `videoUrl/coverUrl/avatarUrl` 是对象键（个别场景是完整 URL），展示/播放前必须过 `MediaUrl.resolve()`（完整 http(s) 地址原样返回）。
- 游客白名单：Feed/详情/搜索/主页（资料/统计/作品）/评论列表/互动状态/标签/UBA 上报；互动写/发布/通知/头像直传需登录（UI 层用 `ensureLogin(context)` 引导）。
- 租户无客户端概念：注册租户由服务端定为缺省业务租户（`constants.DefaultTenantCode`），App 不传也不需要传。
