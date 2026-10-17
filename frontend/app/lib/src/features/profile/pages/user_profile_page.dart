import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/number_format.dart';
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
        _error = '$e';
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
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      FilledButton(
                        onPressed: _load,
                        child: Text(loc.retry),
                      ),
                    ],
                  ),
                )
              : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                UserAvatar(
                                  avatarUrl:
                                      _profile?.avatarDisplayUrl ?? '',
                                  nickname: _profile?.nickname ?? '',
                                  radius: 36.r,
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _profile?.nickname ?? '',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        '${loc.followers} ${NumberFormatUtils.formatCount(_stats?.followerCount ?? 0)} · ${loc.likeReceived} ${NumberFormatUtils.formatCount(_stats?.likeReceivedCount ?? 0)}',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: theme
                                              .colorScheme.onSurface
                                              .withAlpha(140),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonal(
                                  onPressed: _confirmUnfollow,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _following
                                        ? theme.colorScheme.surfaceContainerHighest
                                        : theme.colorScheme.primary,
                                    foregroundColor: _following
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onPrimary,
                                  ),
                                  child: Text(
                                    _following ? loc.followed : loc.follow,
                                    style: TextStyle(fontSize: 13.sp),
                                  ),
                                ),
                              ],
                            ),
                            if ((_profile?.bio ?? '').isNotEmpty) ...[
                              SizedBox(height: 12.h),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _profile!.bio,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(170),
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(height: 8.h),
                          ],
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
