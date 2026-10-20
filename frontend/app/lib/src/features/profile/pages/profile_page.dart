import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart'
    show AppRoutePath, RouteNames;
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/utilities/number_format.dart';
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/auth/services/authentication_service.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/widgets/login_guard.dart';
import 'package:shortplay_app/src/features/common/widgets/paged_video_list.dart';
import 'package:shortplay_app/src/features/series/services/series_service.dart';
import 'package:shortplay_app/src/features/series/widgets/paged_series_list.dart';
import 'package:shortplay_app/src/features/history/widgets/paged_history_list.dart';
import 'package:shortplay_app/src/features/common/widgets/user_avatar.dart';
import 'package:shortplay_app/src/features/profile/services/user_service.dart';

/// 我的（登录态：资料+统计+创作者中心+作品/收藏 Tab；游客：登录引导）
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  final UserAuthCache _auth = GetIt.instance<UserAuthCache>();
  final UserService _userService = UserService();
  final SeriesService _seriesService = SeriesService();

  bool _hasLogin = false;
  UserProfile? _profile;
  UserStats? _stats;
  CreatorOverview? _overview;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _hasLogin = _auth.hasLogin;
    _auth.loginStateNotifier.addListener(_onLoginStateChanged);
    if (_hasLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _auth.loginStateNotifier.removeListener(_onLoginStateChanged);
    super.dispose();
  }

  void _onLoginStateChanged() {
    if (!mounted) return;
    setState(() => _hasLogin = _auth.hasLogin);
    if (_hasLogin) {
      _load();
    } else {
      setState(() {
        _profile = null;
        _stats = null;
        _overview = null;
      });
    }
  }

  Future<void> _load() async {
    if (_loading || !_auth.hasLogin) return;
    setState(() => _loading = true);
    try {
      final userId = _auth.userId;
      final profile = await _userService.getUser(userId);
      final stats = await _userService.getStats(userId);
      CreatorOverview? overview;
      try {
        overview = await _userService.creatorOverview();
      } catch (_) {
        overview = null; // 创作者总览失败不阻塞主页
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _stats = stats;
        _overview = overview;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final loc = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.logout),
        content: Text(loc.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AuthenticationService().logoutMutation().mutate(null);
    } catch (_) {
      // 服务端登出失败也要清理本地登录态
      await _auth.clearTokens();
    }
    if (!mounted) return;
    context.go(AppRoutePath.initial);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.me),
        actions: [
          // 系统设置（外观/语言为设备级偏好，游客也可用）
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 21),
            tooltip: loc.settings,
            onPressed: () => context.pushNamed(RouteNames.settings),
          ),
        ],
      ),
      body: !_hasLogin ? _buildGuest(theme, loc) : _buildProfile(theme, loc),
    );
  }

  Widget _buildGuest(ThemeData theme, S loc) {
    return EmptyState(
      icon: Icons.person_outline,
      title: loc.loginToViewProfile,
      actionLabel: loc.login,
      onAction: () => ensureLogin(context),
    );
  }

  Widget _buildProfile(ThemeData theme, S loc) {
    final profile = _profile;
    final stats = _stats;
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            children: [
              // 资料头：渐变环头像 + 昵称/简介 + 操作
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 渐变环头像
                  Container(
                    padding: EdgeInsets.all(2.5.r),
                    decoration: const BoxDecoration(
                      gradient: BrandColor.gradient,
                      shape: BoxShape.circle,
                    ),
                    child: UserAvatar(
                      avatarUrl: profile?.avatarDisplayUrl ?? '',
                      nickname: _auth.userNickname,
                      radius: 30.r,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _auth.userNickname,
                          style: TextStyle(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (_auth.userBio.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            _auth.userBio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: theme.colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // 编辑（浅底圆钮）
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    tooltip: loc.editProfile,
                    onPressed: () async {
                      await context.pushNamed(RouteNames.editProfile);
                      if (mounted) _load();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.onSurface.withAlpha(
                        14,
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  // 退出（浅底圆钮）
                  IconButton(
                    icon: Icon(
                      Icons.logout_rounded,
                      size: 19,
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                    tooltip: loc.logout,
                    onPressed: _logout,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.onSurface.withAlpha(
                        14,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              // 统计条（大数字重字重，国内「我的」页范式）
              Row(
                children: [
                  _StatItem(
                    label: loc.followingCountLabel,
                    value: NumberFormatUtils.formatCount(
                      stats?.followingCount ?? 0,
                    ),
                  ),
                  _statDivider(theme),
                  _StatItem(
                    label: loc.followers,
                    value: NumberFormatUtils.formatCount(
                      stats?.followerCount ?? 0,
                    ),
                  ),
                  _statDivider(theme),
                  _StatItem(
                    label: loc.likeReceived,
                    value: NumberFormatUtils.formatCount(
                      stats?.likeReceivedCount ?? 0,
                    ),
                  ),
                  _statDivider(theme),
                  _StatItem(
                    label: loc.videoCountLabel,
                    value: NumberFormatUtils.formatCount(
                      stats?.videoCount ?? 0,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              // 创作者中心（品牌渐变卡）
              _CreatorCenterCard(overview: _overview, onDark: isDark),
              SizedBox(height: 16.h),
              // 作品 / 剧集 / 收藏 / 历史 Tab
              DefaultTabController(
                length: 4,
                child: SizedBox(
                  height: 480.h,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(text: loc.works),
                          Tab(text: loc.seriesTab),
                          Tab(text: loc.collects),
                          Tab(text: loc.historyTab),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            PagedVideoList(
                              loader: (query) => _userService.userVideos(
                                userId: _auth.userId,
                                query: query,
                              ),
                              badgeOf: _workBadgeLabel,
                            ),
                            PagedSeriesList(
                              loader: (query) => _seriesService.listSeries(
                                authorId: _auth.userId,
                                paging: query,
                              ),
                              emptyText: loc.seriesEmptyMine,
                            ),
                            PagedVideoList(
                              loader: _userService.collects,
                              emptyText: loc.noCollectedVideos,
                            ),
                            PagedHistoryList(
                              emptyText: loc.historyEmpty,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statDivider(ThemeData theme) => Container(
    width: 0.5,
    height: 26.h,
    color: theme.colorScheme.onSurface.withAlpha(24),
  );

  String? _workBadgeLabel(Video video) {
    final loc = S.of(context);
    switch (video.status) {
      case VideoStatus.reviewing:
        return loc.statusReviewing;
      case VideoStatus.rejected:
        return loc.statusRejected;
      case VideoStatus.offline:
        return loc.statusOffline;
      case VideoStatus.draft:
        return loc.statusDraft;
      default:
        return null;
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: theme.colorScheme.onSurface.withAlpha(130),
            ),
          ),
        ],
      ),
    );
  }
}

/// 创作者中心卡片（品牌渐变点缀的数据总览）
class _CreatorCenterCard extends StatelessWidget {
  final CreatorOverview? overview;
  final bool onDark;

  const _CreatorCenterCard({this.overview, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);
    final data = overview;
    final cardColor = onDark
        ? Colors.white.withAlpha(14)
        : BrandColor.rose.withAlpha(14);
    final secondaryColor = theme.colorScheme.onSurface.withAlpha(140);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: onDark
              ? Colors.white.withAlpha(16)
              : BrandColor.rose.withAlpha(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 渐变小方标
              Container(
                width: 22.r,
                height: 22.r,
                decoration: BoxDecoration(
                  gradient: BrandColor.gradient,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(Icons.insights, size: 13.r, color: Colors.white),
              ),
              SizedBox(width: 8.w),
              Text(
                loc.creatorCenter,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _OverviewStat(
                label: loc.totalViews,
                value: NumberFormatUtils.formatCount(data?.totalViews ?? 0),
                color: secondaryColor,
              ),
              _OverviewStat(
                label: loc.totalLikes,
                value: NumberFormatUtils.formatCount(data?.totalLikes ?? 0),
                color: secondaryColor,
              ),
              _OverviewStat(
                label: loc.totalCollects,
                value: NumberFormatUtils.formatCount(data?.totalCollects ?? 0),
                color: secondaryColor,
              ),
              _OverviewStat(
                label: loc.totalComments,
                value: NumberFormatUtils.formatCount(data?.totalComments ?? 0),
                color: secondaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _OverviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, color: color),
        ),
      ],
    );
  }
}
