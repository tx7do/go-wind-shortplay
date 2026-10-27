import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart' show Player;

import 'package:shortplay_app/src/features/danmaku/services/danmaku_service.dart';

/// 弹幕轨道数（半屏密度，观演不遮挡主体）
const int _kTracks = 4;

/// 单条弹幕飞行时长（横穿屏幕）
const Duration _kFlyDuration = Duration(seconds: 6);

/// 时间轴容差：位置越过发射点不超过该窗口才补发（防 seek/卡顿堆积）
const int _kSpawnWindowMs = 2500;

/// 沉浸式弹幕层：监听播放器位置流，按时间轴偏移沿轨道从右向左平移。
///
/// - [items] 须按 timeOffsetMs 升序（服务端已排序；本地新发弹幕按偏移插入）
/// - 进度回退（seek 回看）超过 1s 时清空在飞弹幕并重置发射指针
/// - 纯自绘（无第三方依赖），宿主负责开关与列表获取
class DanmakuOverlay extends StatefulWidget {
  final Player player;
  final List<DanmakuItem> items;

  const DanmakuOverlay({super.key, required this.player, required this.items});

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay> {
  /// 在飞弹幕
  final List<_FlyingDanmaku> _flying = [];
  final math.Random _random = math.Random();

  int _nextKey = 1;
  int _cursor = 0;
  int _lastPositionMs = 0;
  final List<int> _trackLastSpawnAtMs = List.filled(_kTracks, -0x7fffffff);

  @override
  void initState() {
    super.initState();
    widget.player.stream.position.listen(_onPosition);
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 弹幕列表整体替换（切换视频）时重置发射状态
    if (!identical(oldWidget.items, widget.items)) {
      _reset();
    }
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _flying.clear();
      _cursor = 0;
      _trackLastSpawnAtMs.fillRange(0, _kTracks, -0x7fffffff);
    });
  }

  void _onPosition(Duration position) {
    if (!mounted) return;
    final nowMs = position.inMilliseconds;

    // 回退（seek 回看）：清空重放
    if (nowMs < _lastPositionMs - 1000) {
      _lastPositionMs = nowMs;
      _reset();
      return;
    }
    _lastPositionMs = nowMs;

    final spawn = <_FlyingDanmaku>[];
    while (_cursor < widget.items.length &&
        widget.items[_cursor].timeOffsetMs <= nowMs) {
      final item = widget.items[_cursor];
      _cursor++;
      // 容差窗口外（如 seek 跳过的大段）不再补发
      if (nowMs - item.timeOffsetMs > _kSpawnWindowMs) continue;
      final track = _pickTrack(nowMs);
      final key = ValueKey<int>(_nextKey++);
      spawn.add(
        _FlyingDanmaku(
          key: key,
          item: item,
          track: track,
          onCompleted: () {
            if (mounted) {
              setState(() => _flying.removeWhere((f) => f.key == key));
            }
          },
        ),
      );
    }
    if (spawn.isEmpty) return;
    setState(() => _flying.addAll(spawn));
  }

  /// 选轨道：优先「该轨道上一条已飞出足够距离」，否则取最近发射最早者
  int _pickTrack(int nowMs) {
    var best = _random.nextInt(_kTracks);
    var bestAt = _trackLastSpawnAtMs[best];
    for (var i = 0; i < _kTracks; i++) {
      if (_trackLastSpawnAtMs[i] < bestAt) {
        best = i;
        bestAt = _trackLastSpawnAtMs[i];
      }
    }
    _trackLastSpawnAtMs[best] = nowMs;
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final flying in _flying)
                _DanmakuFlyWidget(
                  key: flying.key,
                  text: flying.item.content,
                  track: flying.track,
                  tracks: _kTracks,
                  containerWidth: width,
                  duration: _kFlyDuration,
                  onCompleted: flying.onCompleted,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 一次发射（key 唯一；onCompleted 由飞行组件回调移除）
class _FlyingDanmaku {
  final Key key;
  final DanmakuItem item;
  final int track;
  final VoidCallback onCompleted;

  const _FlyingDanmaku({
    required this.key,
    required this.item,
    required this.track,
    required this.onCompleted,
  });
}

/// 单条飞行弹幕：TweenAnimationBuilder 驱动右→左平移，结束即回调移除
class _DanmakuFlyWidget extends StatelessWidget {
  final String text;
  final int track;
  final int tracks;
  final double containerWidth;
  final Duration duration;
  final VoidCallback onCompleted;

  const _DanmakuFlyWidget({
    super.key,
    required this.text,
    required this.track,
    required this.tracks,
    required this.containerWidth,
    required this.duration,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    // 文本宽度预估（弹幕白字带描边，字号 13）
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 13.sp,
          color: Colors.white,
          shadows: const [
            Shadow(blurRadius: 2, color: Colors.black54, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final textWidth = tp.width;
    // 轨道纵向位置：顶部安全区内均分
    final top = MediaQuery.paddingOf(context).top + 8.h + track * 24.h;
    // 起点右缘外，终点左缘外
    final travel = containerWidth + textWidth;

    return Positioned(
      top: top,
      left: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 0.0),
        duration: duration,
        onEnd: onCompleted,
        builder: (context, t, child) {
          return Transform.translate(
            offset: Offset(travel * t - textWidth, 0),
            child: child,
          );
        },
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.white,
            shadows: const [
              Shadow(
                blurRadius: 2,
                color: Colors.black54,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
