# GoWind 短视频 App（shortplay_app）

GoWind 短视频社区的移动端（Flutter），对应后端 App 网关 `:6700 /app/v1`。
核心体验是**上下滑沉浸式短视频 Feed**，配套发布、互动（点赞/收藏/评论/关注）、
消息通知、个人主页、搜索与举报等社区能力。UI 与文案均为中文。

## 功能清单

| 模块 | 说明 |
|---|---|
| 首页 Feed | 「关注 / 热门」渠道切换；垂直上下滑沉浸流；播放/完播/划走等 UBA 埋点；右上角搜索入口 |
| 播放器 | media_kit，按需创建、滑出即释放；被上层路由覆盖自动暂停 |
| 评论 | 底部弹窗；楼中楼（回复/展开/加载更多）；删除自己的评论（长按）；评论点赞 |
| 发布 | 相册选片 / 拍摄 → 预览 + 标题/简介/标签 → 分片上传（进度）→ 发布或存草稿 |
| 消息 | LIKE/COMMENT/FOLLOW/SYSTEM 四类通知（图标与文案区分）；未读角标（底部 Tab 红点）；单条已读 / 全部已读；带 videoId 的通知点击进单视频详情 |
| 我的 | 未登录引导登录；头像/昵称/简介 + 编辑资料（PUT /profile）；统计（作品/粉丝/关注/获赞）；创作者中心卡片（GET /creator/overview）；作品 / 收藏九宫格（分页）；退出登录 |
| 他人主页 | 资料 + 统计 + 作品列表；关注/取关（游客引导登录） |
| 单视频详情 | 沉浸式单页播放 + 右侧操作栏（点赞/评论/收藏/分享）+ 底部信息；「更多」菜单 → 举报（原因单选 + 补充说明；409 DUPLICATE_REPORT 提示勿重复提交） |
| 搜索 | 标题模糊 + 标签精确；封面卡片结果列表，点击进详情 |
| 会话 | 登录/注册；token 持久化（shared_preferences）；401 自动清 token 引导重新登录 |

## 运行方式

```bash
cd frontend/app
flutter pub get

# Android 模拟器（10.0.2.2 即宿主机回环）
flutter run

# 真机 / iOS 模拟器：显式指定后端地址
flutter run --dart-define=API_BASE=http://<你的后端IP>:6700
```

- `API_BASE` 缺省为 `http://10.0.2.2:6700`（Android 模拟器访问宿主机）。
- 冒烟测试：`flutter test`。

## 目录结构

```
lib/
├── main.dart                  # 入口：服务初始化 + 全局 Bloc + 主题
├── core/
│   ├── config.dart            # API_BASE（--dart-define）等编译期配置
│   ├── route_observer.dart    # 路由观察者（Feed 感知被覆盖暂停视频）
│   ├── theme.dart             # 深色主题
│   ├── network/               # ApiClient（dio + token 拦截器）、ApiException
│   └── storage/               # TokenStore（token/用户缓存持久化）
├── models/                    # user / video / comment / notification / upload / common
├── services/                  # auth / feed / interaction / comment / user /
│                              # notification / report / uba / upload + 服务定位器
├── blocs/                     # auth / feed / comment / notify / profile /
│                              # publish / search / user_page / video_detail cubits
├── widgets/
│   ├── common.dart            # 轻提示 / 时间格式化 / 头像 / 空态 / 加载更多等
│   └── video_card.dart        # 九宫格视频封面卡片
└── pages/
    ├── main_shell.dart        # 主导航壳（首页/发布+/消息/我的）
    ├── feed/                  # Feed 页 + 沉浸式单视频组件（详情页复用）
    ├── publish/               # 发布流程
    ├── comment/               # 评论弹窗
    ├── notify/                # 消息页
    ├── profile/               # 我的 + 编辑资料
    ├── user/                  # 他人主页
    ├── video_detail/          # 单视频详情（含举报）
    ├── search/                # 搜索页
    └── login/                 # 登录/注册
```

## 已知限制

- **头像编辑**为填写图片链接（后端无头像上传接口），无相册选图。
- **关注状态来源**依赖视频详情 `viewerState.following` 或 follow 接口返回，
  `GET /users/{id}` 未返回 viewerState 时他人主页首次进入显示「关注」，点击后由服务端纠正。
- **分享**为复制 H5 短链（`GET /s/{videoId}`）到剪贴板，未接系统分享面板。
- 草稿箱（`/drafts` 系列）与视频编辑/删除（`PUT·DELETE /videos/{id}`）
  接口已就绪但 App 未提供管理入口；发布页仅支持「存草稿 + 提交」。
- 评论点赞状态服务端无查询接口，仅本会话内维护。
- 未做令牌自动刷新（refreshToken 已持久化，401 直接引导重新登录）。
- 仅适配 Android / iOS；桌面端未验证（media_kit 依赖已包含）。
