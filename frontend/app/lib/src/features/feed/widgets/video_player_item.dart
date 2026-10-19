import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart'
    show Media, Player, PlayerConfiguration, PlaylistMode;
import 'package:media_kit_video/media_kit_video.dart' as media_video;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:shortplay_app/src/features/common/data/models.dart';

/// 播放进度摘要（供埋点上报）
class PlaybackProgress {
  /// 累计观看毫秒数
  final int watchMs;

  /// 观看百分比 0-100
  final int percent;

  const PlaybackProgress({required this.watchMs, required this.percent});
}

/// 沉浸式单视频播放组件（media_kit 内核）
///
/// - [isActive] 为 true 时自动播放，false 时自动暂停（Feed 上下滑联动）
/// - 单击切换播放/暂停；双击点赞（回调宿主，见 [onDoubleTapLike]）
/// - 按住 2 倍速快进，松手恢复
/// - 通过回调向宿主抛出 播放/划走/完播/心跳 事件（宿主自行上报 UBA）
class VideoPlayerItem extends StatefulWidget {
  final Video video;

  /// 是否当前活跃页（自动播放/暂停）
  final bool isActive;

  /// 播放开始（每次从暂停/切页进入播放时触发一次）
  final ValueChanged<PlaybackProgress>? onPlayStart;

  /// 划走/离开（未完播）
  final ValueChanged<PlaybackProgress>? onSwipeAway;

  /// 完播
  final ValueChanged<PlaybackProgress>? onComplete;

  /// 周期心跳（默认 10s）
  final ValueChanged<PlaybackProgress>? onHeartbeat;

  /// 双击点赞（参数为点击位置，组件局部坐标，宿主用于播放心形动画）
  final ValueChanged<Offset>? onDoubleTapLike;

  /// 播放器就绪（宿主可取 [Player] 渲染进度条/自定义控制）
  final ValueChanged<Player>? onPlayerReady;

  const VideoPlayerItem({
    super.key,
    required this.video,
    required this.isActive,
    this.onPlayStart,
    this.onSwipeAway,
    this.onComplete,
    this.onHeartbeat,
    this.onDoubleTapLike,
    this.onPlayerReady,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  late final Player _player;
  late final media_video.VideoController _controller;

  StreamSubscription<bool>? _completedSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _bufferSub;
  Timer? _heartbeatTimer;

  bool _isBuffering = true;
  bool _opened = false;

  /// 播放状态（流监听里 setState 同步，驱动暂停角标显隐）
  bool _isPlaying = false;

  /// 2 倍速快进中（按住屏幕）
  bool _boostRate = false;

  // ─── 单击/双击手势判定（抖音口径：单击秒切换，双击点赞并回退单击）───
  static const Duration _doubleTapWindow = Duration(milliseconds: 300);
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 上一次单击是否切换了播放状态（双击时需回退）
  bool _toggledByLastTap = false;
  Timer? _tapMarkTimer;

  /// 是否静音（仅 Web 有意义：浏览器禁止非静音自动播放，进页面须静音起播）
  bool _isMuted = kIsWeb;

  /// 累计观看毫秒（位置差分累加，seek 跳变不计）
  int _watchMs = 0;
  Duration _lastPosition = Duration.zero;
  int _durationMs = 0;

  @override
  void initState() {
    super.initState();
    // Web 端以静音内核起播（规避浏览器自动播放策略）；移动端内核不受限，等价默认构造
    _player = Player(configuration: PlayerConfiguration(muted: kIsWeb));
    _controller = media_video.VideoController(_player);

    _completedSub = _player.stream.completed.listen(_onCompleted);
    _playingSub = _player.stream.playing.listen(_onPlayingChanged);
    _positionSub = _player.stream.position.listen(_onPositionChanged);
    _bufferSub = _player.stream.buffering.listen((buffering) {
      if (mounted && buffering != _isBuffering) {
        setState(() => _isBuffering = buffering);
      }
    });

    unawaited(_open(widget.video.playUrl));

    // 播放器就绪后交给宿主（渲染进度条等）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPlayerReady?.call(_player);
    });
  }

  @override
  void didUpdateWidget(covariant VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 离开当前页：暂停并上报划走（顺带收掉倍速/单击判定）
    if (oldWidget.isActive && !widget.isActive) {
      unawaited(_player.pause());
      final progress = _snapshot();
      if (progress.percent < 95) {
        widget.onSwipeAway?.call(progress);
      }
      _stopHeartbeat();
      _resetGestures();
    }
    // 进入当前页：恢复播放
    if (!oldWidget.isActive && widget.isActive) {
      unawaited(_player.play());
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _tapMarkTimer?.cancel();
    _completedSub?.cancel();
    _playingSub?.cancel();
    _positionSub?.cancel();
    _bufferSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  /// 离开当前页/组件销毁时，收掉倍速与单击判定状态
  void _resetGestures() {
    _tapMarkTimer?.cancel();
    _tapMarkTimer = null;
    _toggledByLastTap = false;
    if (_boostRate) {
      _boostRate = false;
      unawaited(_player.setRate(1.0));
    }
  }

  /// 单击/双击统一处理（抖音口径）：
  /// - 单击立即切换播放/暂停（秒响应，无 300ms 延迟）
  /// - 双击点赞，并回退第一次单击造成的播放切换（双击不改变播放状态）
  void _onTapUp(TapUpDetails details) {
    final now = DateTime.now();
    final isDoubleTap = now.difference(_lastTapAt) < _doubleTapWindow;
    _lastTapAt = now;
    _tapMarkTimer?.cancel();

    if (isDoubleTap) {
      if (_toggledByLastTap) {
        // 撤销第一次单击的切换，回到双击前的播放状态
        _toggledByLastTap = false;
        unawaited(
          _player.state.playing ? _player.pause() : _player.play(),
        );
      }
      widget.onDoubleTapLike?.call(details.localPosition);
      return;
    }

    unawaited(_player.state.playing ? _player.pause() : _player.play());
    _toggledByLastTap = true;
    _tapMarkTimer = Timer(_doubleTapWindow, () {
      _toggledByLastTap = false;
    });
  }

  /// 按住 2 倍速快进（仅播放中生效，抖音口径）
  void _onLongPressStart(LongPressStartDetails details) {
    if (!_player.state.playing) return;
    unawaited(_player.setRate(2.0));
    if (mounted) setState(() => _boostRate = true);
  }

  void _onLongPressEnd(LongPressEndDetails details) => _stopBoostRate();

  void _onLongPressCancel() => _stopBoostRate();

  void _stopBoostRate() {
    if (!_boostRate) return;
    unawaited(_player.setRate(1.0));
    if (mounted) setState(() => _boostRate = false);
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) {
      if (mounted) setState(() => _isBuffering = false);
      return;
    }
    // 单视频无限循环（抖音口径）：播完自动重头播，不会冻在末帧
    await _player.setPlaylistMode(PlaylistMode.loop);
    await _player.open(Media(url), play: widget.isActive);
    _opened = true;
    if (mounted) setState(() {});
  }

  void _onPlayingChanged(bool playing) {
    if (!mounted) return;
    // 同步本地状态触发重建，否则暂停角标不随播放状态显隐
    if (playing != _isPlaying) {
      setState(() => _isPlaying = playing);
    }
    if (playing) {
      if (widget.isActive) {
        unawaited(WakelockPlus.enable());
      }
      widget.onPlayStart?.call(_snapshot());
      _startHeartbeat();
    } else {
      _stopHeartbeat();
    }
  }

  void _onPositionChanged(Duration position) {
    // 位置差分累计观看时长（处理 seek 跳变：仅累计正向小增量）
    final delta = position.inMilliseconds - _lastPosition.inMilliseconds;
    if (delta > 0 && delta < 2000) {
      _watchMs += delta;
    }
    _lastPosition = position;
    if (_durationMs <= 0) {
      _durationMs = _player.state.duration.inMilliseconds;
    }
  }

  void _onCompleted(bool completed) {
    if (!completed || !mounted) return;
    widget.onComplete?.call(
      PlaybackProgress(watchMs: _watchMs, percent: 100),
    );
    _stopHeartbeat();
  }

  PlaybackProgress _snapshot() {
    if (_durationMs <= 0) {
      _durationMs = _player.state.duration.inMilliseconds;
    }
    final percent = _durationMs > 0
        ? ((_lastPosition.inMilliseconds / _durationMs) * 100).round()
        : 0;
    return PlaybackProgress(
      watchMs: _watchMs,
      percent: percent.clamp(0, 100),
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    if (widget.onHeartbeat == null) return;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_player.state.playing) {
        widget.onHeartbeat?.call(_snapshot());
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 静音切换（仅 Web 暴露按钮）。media_kit 无 setMuted，用音量 0/100 表达；
  /// Web 端 setVolume 内部会先解除 <video> 的 muted 属性，故 100 即恢复声音。
  Future<void> _toggleMuted() async {
    await _player.setVolume(_isMuted ? 100.0 : 0.0);
    if (mounted) setState(() => _isMuted = !_isMuted);
  }

  @override
  Widget build(BuildContext context) {
    final showPlayBadge = _opened && !_isPlaying && !_isBuffering;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _onTapUp,
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 黑底兜底（视频尚未出帧）
          const ColoredBox(color: Colors.black),
          media_video.Video(
            controller: _controller,
            fit: BoxFit.contain,
            controls: (media_video.VideoState state) =>
                const SizedBox.shrink(),
          ),
          // 缓冲指示
          if (_isBuffering && widget.isActive)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          // 暂停角标
          if (showPlayBadge)
            Center(
              child: Icon(
                Icons.play_arrow_rounded,
                size: 80.sp,
                color: Colors.white.withAlpha(200),
              ),
            ),
          // 2x 快进提示（按住屏幕时，顶部中央）
          if (_boostRate)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12.h,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fast_forward_rounded,
                            size: 15.sp, color: Colors.white),
                        SizedBox(width: 5.w),
                        Text(
                          '2x 快进中',
                          style: TextStyle(
                            fontSize: 12.sp,
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
          // 静音切换（仅 Web：自动播放须静音，声音由用户手动开启）
          if (kIsWeb)
            Positioned(
              right: 12.w,
              top: 12.h,
              child: IconButton(
                onPressed: _toggleMuted,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withAlpha(80),
                ),
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 22.sp,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
