import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
// media_kit_video 与 models/video.dart 都导出名为 Video 的类型，
// 这里给播放器库加前缀：Video 统一指业务模型，播放器组件用 media_video.Video。
import 'package:media_kit_video/media_kit_video.dart' as media_video;

import '../../core/config.dart';
import '../../models/user.dart';
import '../../models/video.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

/// 单视频页所需的动作接口：Feed 列表与单视频详情页各自实现，
/// 从而复用同一个沉浸式单页组件 [FeedVideoItem]。
abstract class VideoItemActions {
  /// 当前用户是否已点赞该视频。
  bool isLiked(Video video);

  /// 当前用户是否已收藏该视频。
  bool isCollected(Video video);

  /// 当前用户是否已关注作者。
  bool isFollowing(User author);

  /// 展示用点赞数（服务端计数 + 本地增量）。
  int likeCountOf(Video video);

  /// 展示用收藏数。
  int collectCountOf(Video video);

  /// 展示用评论数。
  int commentCountOf(Video video);

  /// 加载作者资料（实现方可缓存）。
  Future<User?> loadAuthor(int userId);

  Future<void> toggleLike(Video video);

  Future<void> toggleCollect(Video video);

  Future<void> toggleFollow(User author);

  void openComments(Video video);

  void share(Video video);

  void openAuthor(User author);
}

/// 沉浸式单视频页（Feed 的单页组件，也被单视频详情页复用）。
///
/// 播放器生命周期：进入可视页（isActive=true）时按需创建并播放；
/// 离开可视页时暂停并上报划走埋点；组件销毁时释放播放器，
/// 避免多实例常驻导致内存暴涨（PageView 滑出即销毁子页）。
class FeedVideoItem extends StatefulWidget {
  const FeedVideoItem({
    super.key,
    required this.video,
    required this.isActive,
    required this.actions,
    this.onBack,
    this.moreActions,
  });

  final Video video;

  /// 是否为当前可视页：true 播放，false 暂停。
  final bool isActive;

  final VideoItemActions actions;

  /// 单视频详情页显示返回按钮。
  final VoidCallback? onBack;

  /// 顶部右侧“更多”按钮（详情页用于举报等）。
  final List<Widget>? moreActions;

  @override
  State<FeedVideoItem> createState() => _FeedVideoItemState();
}

class _FeedVideoItemState extends State<FeedVideoItem> {
  Player? _player;
  media_video.VideoController? _controller;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  /// 完播判定：position / duration >= 95%。
  bool _completeReported = false;
  bool _playing = false;

  /// 本次观看时长计时（用于划走埋点 durationMs）。
  final Stopwatch _watch = Stopwatch();
  Duration _lastPosition = Duration.zero;
  Duration _mediaDuration = Duration.zero;

  bool get _isCurrent =>
      widget.isActive && widget.video.videoUrl.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isCurrent) _activate();
  }

  @override
  void didUpdateWidget(covariant FeedVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isCurrent && !oldWidget.isActive) {
      _activate();
    } else if (!widget.isActive && oldWidget.isActive) {
      _deactivate();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  /// 激活：按需创建播放器并播放；上报播放埋点。
  void _activate() {
    if (_player == null) {
      final player = Player();
      _controller = media_video.VideoController(player);
      _positionSub = player.stream.position.listen(_onPosition);
      _durationSub = player.stream.duration.listen(
        (d) {
          if (mounted) setState(() => _mediaDuration = d);
        },
      );
      player.open(Media(AppConfig.absolutize(widget.video.videoUrl)));
    } else {
      _player!.play();
    }
    // 新一轮观看会话。
    _completeReported = false;
    _watch
      ..reset()
      ..start();
    setState(() => _playing = true);
    // 埋点：播放（静默失败）。
    Services.uba.report(
      UbaEvent(eventType: UbaEventType.play, videoId: widget.video.id),
    );
  }

  /// 失活：暂停并上报划走埋点（durationMs + 观看进度）。
  void _deactivate() {
    _watch.stop();
    final watchedMs = _watch.elapsedMilliseconds;
    if (watchedMs > 500) {
      final percent = _mediaDuration > Duration.zero
          ? (_lastPosition.inMilliseconds / _mediaDuration.inMilliseconds)
              .clamp(0.0, 1.0)
          : 0.0;
      Services.uba.report(
        UbaEvent(
          eventType: UbaEventType.swipeAway,
          videoId: widget.video.id,
          durationMs: watchedMs,
          watchPercent: percent,
        ),
      );
    }
    _player?.pause();
    if (mounted) setState(() => _playing = false);
  }

  /// 完播检测：观看进度 >= 95% 记一次完播。
  void _onPosition(Duration pos) {
    _lastPosition = pos;
    if (_completeReported || _mediaDuration <= Duration.zero) return;
    if (pos.inMilliseconds >= _mediaDuration.inMilliseconds * 0.95) {
      _completeReported = true;
      Services.uba.report(
        UbaEvent(
          eventType: UbaEventType.complete,
          videoId: widget.video.id,
          durationMs: _watch.elapsedMilliseconds,
          watchPercent: 1.0,
        ),
      );
    }
  }

  void _togglePlay() {
    final player = _player;
    if (player == null) return;
    if (player.state.playing) {
      player.pause();
      _watch.stop();
      if (mounted) setState(() => _playing = false);
    } else {
      player.play();
      _watch.start();
      if (mounted) setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 封面占位（视频首帧渲染前显示）。
        if (video.coverUrl.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: AppConfig.absolutize(video.coverUrl),
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        // 视频层（铺满全屏，object-fit: cover）。
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
            child: _controller != null
                ? media_video.Video(
                    controller: _controller!,
                    fit: BoxFit.cover,
                    controls: (state) => const SizedBox.shrink(),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        // 暂停指示。
        if (!_playing)
          const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              size: 88,
              color: Colors.white70,
            ),
          ),
        // 顶部：返回 / 更多。
        if (widget.onBack != null || widget.moreActions != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Row(
                children: [
                  if (widget.onBack != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                      onPressed: widget.onBack,
                    ),
                  const Spacer(),
                  if (widget.moreActions != null)
                    Row(mainAxisSize: MainAxisSize.min, children: widget.moreActions!),
                ],
              ),
            ),
          ),
        // 右侧操作栏。
        Positioned(
          right: 10,
          bottom: 110,
          child: _RightRail(item: widget, state: this),
        ),
        // 底部信息区。
        Positioned(
          left: 14,
          right: 74,
          bottom: 24,
          child: _BottomInfo(item: widget, state: this),
        ),
      ],
    );
  }
}

/// 右侧操作栏：作者头像 + 关注、点赞、评论、收藏、分享。
class _RightRail extends StatelessWidget {
  const _RightRail({required this.item, required this.state});

  final FeedVideoItem item;
  final _FeedVideoItemState state;

  @override
  Widget build(BuildContext context) {
    final video = item.video;
    final actions = item.actions;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 作者头像 + 关注角标。
        FutureBuilder<User?>(
          future: actions.loadAuthor(video.authorId),
          builder: (context, snapshot) {
            final author = snapshot.data;
            final following = author != null && actions.isFollowing(author);
            return Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(
                      url: author?.avatarUrl ?? '',
                      name: author?.displayName ?? '',
                      radius: 22,
                      borderColor: Colors.white,
                      onTap: author == null ? null : () => actions.openAuthor(author),
                    ),
                    if (author != null && !following)
                      Positioned(
                        bottom: -8,
                        left: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => actions.toggleFollow(author),
                          child: const Icon(
                            Icons.add_circle,
                            size: 18,
                            color: Color(0xFFFF4D67),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        // 点赞。
        _RailButton(
          icon: Icons.favorite,
          label: formatCount(actions.likeCountOf(video)),
          active: actions.isLiked(video),
          activeColor: const Color(0xFFFF4D67),
          onTap: () => actions.toggleLike(video),
        ),
        const SizedBox(height: 18),
        // 评论。
        _RailButton(
          icon: Icons.chat_bubble_rounded,
          label: formatCount(actions.commentCountOf(video)),
          onTap: () => actions.openComments(video),
        ),
        const SizedBox(height: 18),
        // 收藏。
        _RailButton(
          icon: Icons.star_rounded,
          label: formatCount(actions.collectCountOf(video)),
          active: actions.isCollected(video),
          activeColor: const Color(0xFFFFC53D),
          onTap: () => actions.toggleCollect(video),
        ),
        const SizedBox(height: 18),
        // 分享。
        _RailButton(
          icon: Icons.share,
          label: '分享',
          onTap: () => actions.share(video),
        ),
      ],
    );
  }
}

/// 操作栏单个按钮。
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: active ? activeColor : Colors.white),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部信息区：@昵称 / 标题 / 简介 / 标签。
class _BottomInfo extends StatelessWidget {
  const _BottomInfo({required this.item, required this.state});

  final FeedVideoItem item;
  final _FeedVideoItemState state;

  @override
  Widget build(BuildContext context) {
    final video = item.video;
    final actions = item.actions;
    return GestureDetector(
      // 信息区点击不触发播放/暂停。
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // @昵称（点击进作者主页）。
          FutureBuilder<User?>(
            future: actions.loadAuthor(video.authorId),
            builder: (context, snapshot) {
              final name = snapshot.data?.displayName ?? '';
              if (name.isEmpty) return const SizedBox.shrink();
              return InkWell(
                onTap: () => actions.openAuthor(snapshot.data!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '@$name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          if (video.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (video.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                video.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ),
          if (video.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: video.tags
                    .take(5)
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '#$t',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
