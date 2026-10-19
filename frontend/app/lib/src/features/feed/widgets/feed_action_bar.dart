import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/config/environments.dart';
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/utilities/number_format.dart';
import 'package:shortplay_app/src/features/common/services/interaction_service.dart';
import 'package:shortplay_app/src/features/common/services/uba_service.dart';
import 'package:shortplay_app/src/features/common/widgets/login_guard.dart';
import 'package:shortplay_app/src/features/common/widgets/user_avatar.dart';
import 'package:get_it/get_it.dart' show GetIt;
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/src/app_router/app_router.dart' show RouteNames;
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 右侧操作栏：作者头像+关注、点赞、评论、收藏、分享
class FeedActionBar extends StatefulWidget {
  final Video video;

  /// 作者昵称（feed 接口不回传作者信息，由详情接口补充；空则显示默认）
  final String authorNickname;
  final String authorAvatarUrl;

  final VoidCallback? onCommentTap;
  final ValueChanged<Video>? onVideoUpdated;

  const FeedActionBar({
    super.key,
    required this.video,
    this.authorNickname = '',
    this.authorAvatarUrl = '',
    this.onCommentTap,
    this.onVideoUpdated,
  });

  @override
  State<FeedActionBar> createState() => _FeedActionBarState();
}

class _FeedActionBarState extends State<FeedActionBar> {
  final _interaction = InteractionService();
  final _uba = UbaService();

  late bool _liked = widget.video.liked;
  late bool _collected = widget.video.collected;
  late bool _following = widget.video.followingAuthor;
  late int _likeCount = widget.video.likeCount;
  late int _collectCount = widget.video.collectCount;

  /// 外部视频数据变化时同步本地状态（详情/互动回写等）
  @override
  void didUpdateWidget(covariant FeedActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.video.liked != widget.video.liked ||
        oldWidget.video.collected != widget.video.collected ||
        oldWidget.video.followingAuthor != widget.video.followingAuthor ||
        oldWidget.video.likeCount != widget.video.likeCount ||
        oldWidget.video.collectCount != widget.video.collectCount) {
      _liked = widget.video.liked;
      _collected = widget.video.collected;
      _following = widget.video.followingAuthor;
      _likeCount = widget.video.likeCount;
      _collectCount = widget.video.collectCount;
    }
  }

  bool get isMine =>
      GetIt.instance<UserAuthCache>().userId == widget.video.authorId &&
      GetIt.instance<UserAuthCache>().userId > 0;

  Future<void> _toggleLike() async {
    if (!await ensureLogin(context)) return;
    final liked = !_liked;
    setState(() {
      _liked = liked;
      _likeCount += liked ? 1 : -1;
    });
    try {
      final result = liked
          ? await _interaction.like(
              targetType: LikeTargetType.video,
              targetId: widget.video.id,
            )
          : await _interaction.unlike(
              targetType: LikeTargetType.video,
              targetId: widget.video.id,
            );
      if (liked && result.liked) {
        _uba.report(UbaEvent(
          eventType: UbaEventType.videoLike,
          videoId: widget.video.id,
        ));
      }
      _syncVideo();
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = !liked;
          _likeCount += liked ? -1 : 1;
        });
      }
    }
  }

  Future<void> _toggleCollect() async {
    if (!await ensureLogin(context)) return;
    final collected = !_collected;
    setState(() {
      _collected = collected;
      _collectCount += collected ? 1 : -1;
    });
    try {
      final result = collected
          ? await _interaction.collect(videoId: widget.video.id)
          : await _interaction.uncollect(videoId: widget.video.id);
      if (collected && result.collected) {
        _uba.report(UbaEvent(
          eventType: UbaEventType.videoCollect,
          videoId: widget.video.id,
        ));
      }
      _syncVideo();
    } catch (_) {
      if (mounted) {
        setState(() {
          _collected = !collected;
          _collectCount += collected ? -1 : 1;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (isMine) return;
    if (!await ensureLogin(context)) return;
    final following = !_following;
    setState(() => _following = following);
    try {
      if (following) {
        await _interaction.follow(widget.video.authorId);
        _uba.report(UbaEvent(
          eventType: UbaEventType.followAuthor,
          videoId: widget.video.id,
          targetUserId: widget.video.authorId,
        ));
      } else {
        await _interaction.unfollow(widget.video.authorId);
      }
    } catch (_) {
      if (mounted) setState(() => _following = !following);
    }
  }

  /// 复制分享链接：`http://<API_BASE 域名>/s/{videoId}`
  void _share() {
    final loc = S.of(context);
    // 分享链接：http://<API_BASE 域名>/s/{videoId}（H5 分享页与网关同源）
    final link = '${Environments.shareBaseUrl}/s/${widget.video.id}';
    unawaited(Clipboard.setData(ClipboardData(text: link)));
    EasyLoading.showToast(loc.shareCopied);
  }

  void _syncVideo() {
    widget.onVideoUpdated?.call(widget.video.copyWith(
      liked: _liked,
      collected: _collected,
      followingAuthor: _following,
      likeCount: _likeCount,
      collectCount: _collectCount,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        // 作者头像 + 关注
        GestureDetector(
          onTap: () {
            if (widget.video.authorId > 0) {
              context.pushNamed(
                RouteNames.userProfile,
                pathParameters: {'userId': '${widget.video.authorId}'},
              );
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar(
                avatarUrl: widget.authorAvatarUrl,
                nickname: widget.authorNickname,
                radius: 24.r,
              ),
              if (!isMine)
                Positioned(
                  bottom: -8.h,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _toggleFollow,
                    child: Container(
                      width: 20.r,
                      height: 20.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _following
                            ? null
                            : BrandColor.gradient,
                        color: _following
                            ? theme.colorScheme.surface
                            : null,
                        border: _following
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 1.2,
                              )
                            : null,
                      ),
                      child: Icon(
                        _following ? Icons.check : Icons.add,
                        size: 14.r,
                        color: _following
                            ? theme.colorScheme.primary
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 18.h),
        _ActionButton(
          icon: _liked ? Icons.favorite : Icons.favorite_border,
          color: _liked
              ? (theme.brightness == Brightness.dark
                  ? BrandColor.roseBright
                  : BrandColor.rose)
              : Colors.white,
          label: NumberFormatUtils.formatCount(_likeCount),
          onTap: _toggleLike,
        ),
        SizedBox(height: 18.h),
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          color: Colors.white,
          label: NumberFormatUtils.formatCount(widget.video.commentCount),
          onTap: () => widget.onCommentTap?.call(),
          semanticLabel: loc.comment,
        ),
        SizedBox(height: 18.h),
        _ActionButton(
          icon: _collected
              ? Icons.bookmark
              : Icons.bookmark_border_rounded,
          color: _collected ? BrandColor.collect : Colors.white,
          label: NumberFormatUtils.formatCount(_collectCount),
          onTap: _toggleCollect,
        ),
        SizedBox(height: 18.h),
        _ActionButton(
          icon: Icons.share_outlined,
          color: Colors.white,
          label: loc.share,
          onTap: _share,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final String? semanticLabel;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: Column(
          children: [
            Icon(icon, size: 32.r, color: color, shadows: [
              Shadow(color: Colors.black.withAlpha(90), blurRadius: 6),
            ]),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.black.withAlpha(90), blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
