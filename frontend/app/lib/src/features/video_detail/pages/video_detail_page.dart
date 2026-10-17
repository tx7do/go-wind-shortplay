import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/features/comment/widgets/comment_sheet.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart'
    show ApiStatusException;
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/services/report_service.dart'
    show ReportTargetType;
import 'package:shortplay_app/src/features/common/services/uba_service.dart';
import 'package:shortplay_app/src/features/feed/widgets/feed_action_bar.dart';
import 'package:shortplay_app/src/features/feed/widgets/feed_video_info.dart';
import 'package:shortplay_app/src/features/feed/widgets/video_player_item.dart';
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

  VideoDetail? _detail;
  String? _error;
  bool _loading = true;
  Video? _current;

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
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _current = detail.video;
        _loading = false;
      });
    } on ApiStatusException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.status.reason == 'VIDEO_NOT_FOUND'
            ? S.of(context).videoNotFound
            : e.status.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
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
      EasyLoading.showToast(e.status.message ?? loc.errorDefault);
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

  Widget _buildError(S loc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 56.sp,
            color: Colors.white.withAlpha(120),
          ),
          SizedBox(height: 12.h),
          Text(
            _error ?? loc.videoNotFound,
            style: TextStyle(fontSize: 14.sp, color: Colors.white.withAlpha(180)),
          ),
          SizedBox(height: 16.h),
          FilledButton(onPressed: _load, child: Text(loc.retry)),
        ],
      ),
    );
  }

  Widget _buildPlayer(VideoDetail detail) {
    final video = _current ?? detail.video;
    final uba = UbaService();

    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayerItem(
          key: ValueKey('detail-video-${video.id}'),
          video: video,
          isActive: true,
          onPlayStart: (_) => uba.report(
            UbaEvent(eventType: UbaEventType.videoPlay, videoId: video.id),
          ),
          onSwipeAway: (progress) => uba.report(UbaEvent(
            eventType: UbaEventType.videoSwipeAway,
            videoId: video.id,
            durationMs: progress.watchMs,
            watchPercent: progress.percent,
          )),
          onComplete: (progress) => uba.report(UbaEvent(
            eventType: UbaEventType.videoComplete,
            videoId: video.id,
            durationMs: progress.watchMs,
            watchPercent: 100,
          )),
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
          child: FeedVideoInfo(video: video, reason: ''),
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
      ],
    );
  }
}
