import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart' show Player;

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart'
    show AppRoutePath, RouteNames;
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/comment/widgets/comment_sheet.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart'
    show ApiStatusException, localizedErrorText;
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/services/report_service.dart'
    show ReportTargetType;
import 'package:shortplay_app/src/features/common/services/uba_service.dart';
import 'package:shortplay_app/src/features/feed/widgets/feed_action_bar.dart';
import 'package:shortplay_app/src/features/feed/widgets/feed_progress_bar.dart';
import 'package:shortplay_app/src/features/feed/widgets/feed_video_info.dart';
import 'package:shortplay_app/src/features/feed/widgets/like_burst.dart';
import 'package:shortplay_app/src/features/feed/widgets/video_player_item.dart';
import 'package:shortplay_app/src/features/series/services/series_service.dart';
import 'package:shortplay_app/src/features/video_detail/services/video_service.dart';
import 'package:shortplay_app/src/features/video_detail/widgets/report_sheet.dart';
import 'package:get_it/get_it.dart' show GetIt;

/// 单视频沉浸详情页（复用 feed 播放组件）
///
/// 更多菜单：举报（视频）；作者本人可删除视频。
class VideoDetailPage extends StatefulWidget {
  final int videoId;

  const VideoDetailPage({super.key, required this.videoId});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final VideoService _videoService = VideoService();
  final SeriesService _seriesService = SeriesService();
  final LikeBurstController _burst = LikeBurstController();

  VideoDetail? _detail;
  String? _error;
  bool _loading = true;
  Video? _current;
  Player? _player;

  // 剧集上下文（挂靠剧时加载，用于剧集入口与自动连播；尽力而为）
  SeriesDetail? _seriesCtx;
  bool _advancing = false;

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail =
          await _videoService.getDetail(videoId: widget.videoId);
      // 挂靠剧时拉选集上下文（连播/入口），失败不阻断播放
      SeriesDetail? seriesCtx;
      if (detail.video.seriesId > 0) {
        try {
          seriesCtx = await _seriesService.getSeries(detail.video.seriesId);
        } catch (_) {
          seriesCtx = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _current = detail.video;
        _seriesCtx = seriesCtx;
        _loading = false;
      });
    } on ApiStatusException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = localizedErrorText(S.of(context), e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = localizedErrorText(S.of(context), e);
        _loading = false;
      });
    }
  }

  bool get _isMine =>
      GetIt.instance<UserAuthCache>().userId > 0 &&
      GetIt.instance<UserAuthCache>().userId == _detail?.video.authorId;

  Future<void> _deleteVideo() async {
    final loc = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.deleteVideo),
        content: Text(loc.deleteVideoConfirm),
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
      await _videoService.delete(widget.videoId);
      if (!mounted) return;
      EasyLoading.showToast(loc.videoDeletedSuccess);
      context.pop(true);
    } on ApiStatusException catch (e) {
      EasyLoading.showToast(localizedErrorText(loc, e));
    } catch (_) {
      EasyLoading.showToast(loc.errorDefault);
    }
  }

  Future<void> _openComments() async {
    final video = _current;
    if (video == null) return;
    await showCommentSheet(
      context,
      videoId: video.id,
      onCommentCountChanged: (delta) {
        if (!mounted || _current == null) return;
        setState(() {
          _current = _current!.copyWith(
            commentCount: (_current!.commentCount + delta).clamp(0, 1 << 40),
          );
        });
      },
    );
  }

  void _showMoreMenu() {
    final loc = S.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      // 桌面宽窗下收窄居中（手机端无感）
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(loc.report),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showReportSheet(
                    context,
                    targetType: ReportTargetType.video,
                    targetId: widget.videoId,
                  );
                },
              ),
              if (_isMine)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    loc.deleteVideo,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _deleteVideo();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final detail = _detail;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: loc.report,
            onPressed: _showMoreMenu,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null || detail == null
              ? _buildError(loc)
              : _buildPlayer(detail),
    );
  }

  /// 下一集（剧集上下文内当前视频的后续一集）
  Video? get _nextEpisode {
    final ctx = _seriesCtx;
    if (ctx == null) return null;
    final index = ctx.items.indexWhere((v) => v.id == widget.videoId);
    if (index < 0 || index + 1 >= ctx.items.length) return null;
    return ctx.items[index + 1];
  }

  /// 播完自动连播：短暂提示后整页替换为下一集详情
  Future<void> _playNextEpisode() async {
    final next = _nextEpisode;
    if (next == null || _advancing) return;
    _advancing = true;
    if (mounted) setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    context.pushReplacement(AppRoutePath.videoPath(next.id));
  }

  Widget _buildError(S loc) {
    return EmptyState(
      icon: Icons.videocam_off_outlined,
      title: _error ?? loc.videoNotFound,
      actionLabel: loc.retry,
      onAction: _load,
      onDark: true,
    );
  }

  Widget _buildPlayer(VideoDetail detail) {
    final video = _current ?? detail.video;
    final uba = UbaService();
    final loc = S.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayerItem(
          key: ValueKey('detail-video-${video.id}'),
          video: video,
          isActive: true,
          // 剧集且有下一集：关单集循环，播完由 [_playNextEpisode] 切集
          loop: _nextEpisode == null,
          onPlayerReady: (player) {
            if (mounted) setState(() => _player = player);
          },
          onDoubleTapLike: (position) {
            _burst.burst(position);
            unawaited(runDoubleTapLike(
              context,
              video: video,
              onUpdated: (updated) {
                if (mounted) setState(() => _current = updated);
              },
            ));
          },
          onPlayStart: (_) => uba.report(
            UbaEvent(eventType: UbaEventType.videoPlay, videoId: video.id),
          ),
          onSwipeAway: (progress) => uba.report(UbaEvent(
            eventType: UbaEventType.videoSwipeAway,
            videoId: video.id,
            durationMs: progress.watchMs,
            watchPercent: progress.percent,
          )),
          onComplete: (progress) {
            uba.report(UbaEvent(
              eventType: UbaEventType.videoComplete,
              videoId: video.id,
              durationMs: progress.watchMs,
              watchPercent: 100,
            ));
            // 剧集连播：播完自动切下一集
            unawaited(_playNextEpisode());
          },
          onHeartbeat: (progress) => uba.report(UbaEvent(
            eventType: UbaEventType.videoHeartbeat,
            videoId: video.id,
            durationMs: progress.watchMs,
            watchPercent: progress.percent,
          )),
        ),
        Positioned(
          left: 16.w,
          right: 88.w,
          bottom: 24.h,
          child: FeedVideoInfo(
            video: video,
            reason: '',
            authorNickname: detail.author?.nickname ?? '',
          ),
        ),
        Positioned(
          right: 12.w,
          bottom: 24.h,
          child: FeedActionBar(
            video: video,
            authorNickname: detail.author?.nickname ?? '',
            authorAvatarUrl: detail.author?.avatarDisplayUrl ?? '',
            onCommentTap: _openComments,
            onVideoUpdated: (updated) {
              if (mounted) setState(() => _current = updated);
            },
          ),
        ),
        // 底部细进度条（拖动 seek + 时间气泡）
        if (_player != null)
          FeedProgressBar(player: _player!, bottomInset: 16.h),
        // 双击点赞红心动画层
        Positioned.fill(
          child: LikeBurstLayer(controller: _burst),
        ),
        // 剧集入口 chip（挂靠剧时展示，点击进剧集详情选集）
        if (_seriesCtx?.series != null)
          Positioned(
            top: kToolbarHeight + 4.h,
            left: 16.w,
            child: _SeriesChip(
              title: _seriesCtx!.series!.title,
              episodeNumber: video.episodeNumber,
              onTap: () => context.pushNamed(
                RouteNames.seriesDetail,
                pathParameters: {'seriesId': '${_seriesCtx!.series!.id}'},
                queryParameters: {'from': '${video.id}'},
              ),
            ),
          ),
        // 自动连播提示浮层
        if (_advancing)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withAlpha(110),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        loc.autoNextTip,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 顶部剧集入口 chip：剧名 + 当前集号（半透明黑底白字）
class _SeriesChip extends StatelessWidget {
  final String title;
  final int episodeNumber;
  final VoidCallback onTap;

  const _SeriesChip({
    required this.title,
    required this.episodeNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    return Material(
      color: Colors.black.withAlpha(110),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_outlined, size: 15, color: Colors.white),
              SizedBox(width: 5.w),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 180.w),
                child: Text(
                  episodeNumber > 0
                      ? '${loc.episodeN(episodeNumber)} · $title'
                      : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
