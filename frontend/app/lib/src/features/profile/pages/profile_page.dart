import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart'
    show AppRoutePath, RouteNames;
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/utilities/number_format.dart';
import 'package:shortplay_app/src/features/auth/services/authentication_service.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/widgets/login_guard.dart';
import 'package:shortplay_app/src/features/common/widgets/paged_video_list.dart';
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
          if (_hasLogin)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: loc.editProfile,
              onPressed: () async {
                await context.pushNamed(RouteNames.editProfile);
                if (mounted) _load();
              },
            ),
        ],
      ),
      body: !_hasLogin ? _buildGuest(theme, loc) : _buildProfile(theme, loc),
    );
  }

  Widget _buildGuest(ThemeData theme, S loc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: 56.sp,
            color: theme.colorScheme.onSurface.withAlpha(90),
          ),
          SizedBox(height: 12.h),
          Text(
            loc.loginToViewProfile,
            style: TextStyle(
              fontSize: 14.sp,
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
          SizedBox(height: 16.h),
          FilledButton(
            onPressed: () => ensureLogin(context),
            child: Text(loc.login),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(ThemeData theme, S loc) {
    final profile = _profile;
    final stats = _stats;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        children: [
          // 资料头
          Row(
            children: [
              UserAvatar(
                avatarUrl: profile?.avatarDisplayUrl ?? '',
                nickname: _auth.userNickname,
                radius: 32.r,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _auth.userNickname,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
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
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: loc.logout,
                onPressed: _logout,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // 统计条
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: loc.followingCountLabel,
                value:
                    NumberFormatUtils.formatCount(stats?.followingCount ?? 0),
              ),
              _StatItem(
                label: loc.followers,
                value:
                    NumberFormatUtils.formatCount(stats?.followerCount ?? 0),
              ),
              _StatItem(
                label: loc.likeReceived,
                value: NumberFormatUtils.formatCount(
                    stats?.likeReceivedCount ?? 0),
              ),
              _StatItem(
                label: loc.videoCountLabel,
                value: NumberFormatUtils.formatCount(stats?.videoCount ?? 0),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // 创作者中心（数据总览）
          _CreatorCenterCard(overview: _overview),
          SizedBox(height: 16.h),
          // 作品 / 收藏 Tab
          DefaultTabController(
            length: 2,
            child: SizedBox(
              height: 480.h,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: loc.works),
                      Tab(text: loc.collects),
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
                        PagedVideoList(
                          loader: _userService.collects,
                          emptyText: loc.noCollectedVideos,
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
    );
  }

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
          style: TextStyle(
            fontSize: 11.sp,
            color: theme.colorScheme.onSurface.withAlpha(130),
          ),
        ),
      ],
    );
  }
}

/// 创作者中心卡片（数据总览）
class _CreatorCenterCard extends StatelessWidget {
  final CreatorOverview? overview;

  const _CreatorCenterCard({this.overview});

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);
    final data = overview;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights,
                size: 16.sp,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 6.w),
              Text(
                loc.creatorCenter,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: loc.totalViews,
                value: NumberFormatUtils.formatCount(data?.totalViews ?? 0),
              ),
              _StatItem(
                label: loc.totalLikes,
                value: NumberFormatUtils.formatCount(data?.totalLikes ?? 0),
              ),
              _StatItem(
                label: loc.totalCollects,
                value: NumberFormatUtils.formatCount(data?.totalCollects ?? 0),
              ),
              _StatItem(
                label: loc.totalComments,
                value: NumberFormatUtils.formatCount(data?.totalComments ?? 0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
