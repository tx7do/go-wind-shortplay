import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/constants/index.dart' as constants;
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/widgets/app_bottom_nav_bar.dart';
import 'package:shortplay_app/src/core/widgets/not_found_page.dart';
import 'package:shortplay_app/src/app_router/route_names.dart';

export 'package:shortplay_app/src/app_router/route_names.dart';
export 'package:shortplay_app/src/core/constants/router_paths.dart';
import 'package:shortplay_app/src/features/auth/pages/login_page.dart';
import 'package:shortplay_app/src/features/common/widgets/login_guard.dart';
import 'package:shortplay_app/src/features/feed/bloc/feed_bloc.dart';
import 'package:shortplay_app/src/features/feed/pages/feed_page.dart';
import 'package:shortplay_app/src/features/notify/bloc/notify_bloc.dart';
import 'package:shortplay_app/src/features/notify/pages/notify_page.dart';
import 'package:shortplay_app/src/features/profile/pages/edit_profile_page.dart';
import 'package:shortplay_app/src/features/profile/pages/profile_page.dart';
import 'package:shortplay_app/src/features/profile/pages/user_profile_page.dart';
import 'package:shortplay_app/src/features/publish/pages/publish_page.dart';
import 'package:shortplay_app/src/features/search/pages/search_page.dart';
import 'package:shortplay_app/src/features/hot/pages/hot_page.dart';
import 'package:shortplay_app/src/features/profile/pages/creator_stats_page.dart';
import 'package:shortplay_app/src/features/series/pages/series_detail_page.dart';
import 'package:shortplay_app/src/features/settings/pages/settings_page.dart';
import 'package:shortplay_app/src/features/video_detail/pages/video_detail_page.dart';
import 'package:get_it/get_it.dart' show GetIt;

/// GoWind 短视频社区路由
///
/// 底部导航壳：首页（Feed）/ 发布 / 消息 / 我的（StatefulShellRoute 保持各 Tab 状态）。
/// 详情/搜索/他人主页/登录为全屏路由（不带底部导航）。
class AppRouter {
  static const initial = constants.AppRoutePath.initial;

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    initialLocation: initial,
    navigatorKey: _rootNavigatorKey,
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      // 底部导航壳
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _HomeShell(shell: shell),
        branches: [
          // 首页 Feed
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: constants.AppRoutePath.initial,
                name: RouteNames.home,
                builder: (context, state) => BlocProvider(
                  create: (_) => FeedBloc(),
                  child: const FeedPage(),
                ),
              ),
            ],
          ),
          // 发布
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: constants.AppRoutePath.publish,
                name: RouteNames.publish,
                builder: (context, state) => const PublishPage(),
              ),
            ],
          ),
          // 消息
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: constants.AppRoutePath.notify,
                name: RouteNames.notify,
                builder: (context, state) => const NotifyPage(),
              ),
            ],
          ),
          // 我的
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: constants.AppRoutePath.profile,
                name: RouteNames.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      // 搜索（全屏）
      GoRoute(
        path: constants.AppRoutePath.search,
        name: RouteNames.search,
        builder: (context, state) => SearchPage(
          initialKeyword: state.uri.queryParameters['keyword'],
        ),
      ),
      // 登录/注册（全屏）
      GoRoute(
        path: constants.AppRoutePath.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      // 单视频沉浸详情（全屏）
      GoRoute(
        path: constants.AppRoutePath.videoDetail,
        name: RouteNames.videoDetail,
        builder: (context, state) {
          final videoId =
              int.tryParse(state.pathParameters['videoId'] ?? '') ?? 0;
          return VideoDetailPage(videoId: videoId);
        },
      ),
      // 创作者数据（全屏，需登录）
      GoRoute(
        path: constants.AppRoutePath.creatorStats,
        name: RouteNames.creatorStats,
        builder: (context, state) => const CreatorStatsPage(),
      ),
      // 热榜（全屏，游客可看）
      GoRoute(
        path: constants.AppRoutePath.hotList,
        name: RouteNames.hotList,
        builder: (context, state) => const HotPage(),
      ),
      // 剧集详情（全屏）
      GoRoute(
        path: constants.AppRoutePath.seriesDetail,
        name: RouteNames.seriesDetail,
        builder: (context, state) {
          final seriesId =
              int.tryParse(state.pathParameters['seriesId'] ?? '') ?? 0;
          // from：来源视频（选集列表高亮当前播放集）
          final fromVideo =
              int.tryParse(state.uri.queryParameters['from'] ?? '');
          return SeriesDetailPage(
            seriesId: seriesId,
            currentVideoId: fromVideo,
          );
        },
      ),
      // 他人主页（全屏）
      GoRoute(
        path: constants.AppRoutePath.userProfile,
        name: RouteNames.userProfile,
        builder: (context, state) {
          final userId =
              int.tryParse(state.pathParameters['userId'] ?? '') ?? 0;
          return UserProfilePage(userId: userId);
        },
      ),
      // 编辑资料（全屏）
      GoRoute(
        path: '/settings/edit_profile',
        name: RouteNames.editProfile,
        builder: (context, state) => const EditProfilePage(),
      ),
      // 系统设置（全屏，游客可用：外观/语言为设备级偏好）
      GoRoute(
        path: constants.AppRoutePath.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
}

/// 底部导航壳：首页 / 发布 / 消息 / 我的
class _HomeShell extends StatelessWidget {
  final StatefulNavigationShell shell;

  const _HomeShell({required this.shell});

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);

    return BlocProvider<NotifyBloc>(
      create: (_) => NotifyBloc(),
      child: BlocBuilder<NotifyBloc, NotifyState>(
        builder: (context, notifyState) {
          return Scaffold(
            body: shell,
            // 底栏为实体栏（抖音口径：仅顶部沉浸），body 不延伸到栏后
            bottomNavigationBar: ValueListenableBuilder<bool>(
              valueListenable:
                  GetIt.instance<UserAuthCache>().loginStateNotifier,
              builder: (context, hasLogin, _) {
                return AppBottomNavBar(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: (index) =>
                      _onDestinationSelected(context, index),
                  items: [
                    BottomNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: loc.home,
                    ),
                    BottomNavItem(
                      icon: Icons.add_box_outlined,
                      activeIcon: Icons.add_box,
                      label: loc.publish,
                    ),
                    BottomNavItem(
                      icon: Icons.notifications_none,
                      activeIcon: Icons.notifications,
                      label: loc.message,
                      badgeCount: hasLogin ? notifyState.unreadCount : 0,
                    ),
                    BottomNavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: loc.me,
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onDestinationSelected(BuildContext context, int index) {
    // 发布 / 消息需要登录（游客点击引导登录）
    if (index == 1 && !hasLogin) {
      ensureLogin(context);
      return;
    }
    if (index == 2 && !hasLogin) {
      // 消息页自身有登录引导态，直接切过去
      shell.goBranch(index, initialLocation: shell.currentIndex == index);
      return;
    }
    shell.goBranch(
      index,
      initialLocation: index == shell.currentIndex,
    );
  }
}
