import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/number_format.dart';
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/core/widgets/gradient_button.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/services/interaction_service.dart';
import 'package:shortplay_app/src/features/common/widgets/login_guard.dart';
import 'package:shortplay_app/src/features/common/widgets/paged_video_list.dart';
import 'package:shortplay_app/src/features/common/widgets/user_avatar.dart';
import 'package:shortplay_app/src/features/profile/services/user_service.dart';

/// 他人主页：资料 + 统计 + 作品（关注/取关）
class UserProfilePage extends StatefulWidget {
  final int userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final UserService _userService = UserService();
  final InteractionService _interaction = InteractionService();

  UserProfile? _profile;
  UserStats? _stats;
  bool _following = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _userService.getUser(widget.userId),
        _userService.getStats(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile;
        _stats = results[1] as UserStats;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = localizedErrorText(S.of(context), e);
      });
    }
  }

  Future<void> _toggleFollow() async {
    final loc = S.of(context);
    if (!await ensureLogin(context)) return;
    final following = !_following;
    setState(() => _following = following);
    try {
      if (following) {
        await _interaction.follow(widget.userId);
      } else {
        await _interaction.unfollow(widget.userId);
      }
    } on ApiStatusException catch (e) {
      if (!mounted) return;
      setState(() => _following = !following);
      if (e.status.reason == 'CANNOT_FOLLOW_SELF') {
        EasyLoading.showToast(loc.cannotFollowSelf);
      } else {
        EasyLoading.showToast(loc.errorDefault);
      }
    } catch (_) {
      if (mounted) setState(() => _following = !following);
    }
  }

  Future<void> _confirmUnfollow() async {
    final loc = S.of(context);
    if (!_following) {
      await _toggleFollow();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.unfollow),
        content: Text(loc.unfollowConfirm),
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
    if (confirmed == true) {
      await _toggleFollow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_profile?.nickname ?? '')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? EmptyState(
              icon: Icons.wifi_off_rounded,
              title: loc.errorOccurred,
              subtitle: _error!,
              actionLabel: loc.retry,
              onAction: _load,
            )
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  // 宽窗（桌面/平板横屏）下头部内容收窄居中
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 8.h),
                        child: Column(
                          children: [
                            // 渐变环头像
                            Container(
                              padding: EdgeInsets.all(3.r),
                              decoration: const BoxDecoration(
                                gradient: BrandColor.gradient,
                                shape: BoxShape.circle,
                              ),
                              child: UserAvatar(
                                avatarUrl: _profile?.avatarDisplayUrl ?? '',
                                nickname: _profile?.nickname ?? '',
                                radius: 38.r,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              _profile?.nickname ?? '',
                              style: TextStyle(
                                fontSize: 19.sp,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if ((_profile?.bio ?? '').isNotEmpty) ...[
                              SizedBox(height: 6.h),
                              Text(
                                _profile!.bio,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  height: 1.5,
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    170,
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(height: 14.h),
                            // 统计（横排）
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  NumberFormatUtils.formatCount(
                                    _stats?.followingCount ?? 0,
                                  ),
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  loc.followingCountLabel,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(140),
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Text(
                                  NumberFormatUtils.formatCount(
                                    _stats?.followerCount ?? 0,
                                  ),
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  loc.followers,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(140),
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Text(
                                  NumberFormatUtils.formatCount(
                                    _stats?.likeReceivedCount ?? 0,
                                  ),
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  loc.likeReceived,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(140),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 18.h),
                            // 关注按钮（已关注为浅底描边）
                            _following
                                ? OutlinedButton(
                                    onPressed: _confirmUnfollow,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: Size(160.w, 42.h),
                                      side: BorderSide(
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(60),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      loc.followed,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  )
                                : GradientButton(
                                    label: loc.follow,
                                    onPressed: _toggleFollow,
                                    height: 42,
                                    fontSize: 14,
                                    width: 160,
                                  ),
                            SizedBox(height: 8.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              body: PagedVideoList(
                loader: (query) => _userService.userVideos(
                  userId: widget.userId,
                  query: query,
                ),
                emptyText: loc.noWorksYet,
              ),
            ),
    );
  }
}
