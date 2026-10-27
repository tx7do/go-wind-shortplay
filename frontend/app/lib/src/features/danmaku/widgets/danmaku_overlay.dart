import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart' show Player;

import 'package:shortplay_app/src/features/danmaku/services/danmaku_service.dart';

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

  /// 弹幕轨道数（显示区域：1=1/4 屏，2=半屏，4=全屏）
  final int tracks;

  /// 弹幕点击（宿主弹操作面板：举报等）；null 则弹幕层不可点
  final ValueChanged<DanmakuItem>? onDanmakuTap;

  const DanmakuOverlay({
    super.key,
    required this.player,
    required this.items,
    this.tracks = 4,
    this.onDanmakuTap,
  });

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
  late final List<int> _trackLastSpawnAtMs = List.filled(
    widget.tracks.clamp(1, 4),
    -0x7fffffff,
  );

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
      _trackLastSpawnAtMs.fillRange(0, _trackLastSpawnAtMs.length, -0x7fffffff);
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
    var best = _random.nextInt(_trackLastSpawnAtMs.length);
    var bestAt = _trackLastSpawnAtMs[best];
    for (var i = 0; i < _trackLastSpawnAtMs.length; i++) {
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
    // 不加 IgnorePointer：仅弹幕文本区域命中点击（举报入口），
    // 其余区域透明穿透到播放器手势
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final flying in _flying)
              _DanmakuFlyWidget(
                key: flying.key,
                item: flying.item,
                track: flying.track,
                tracks: _trackLastSpawnAtMs.length,
                containerWidth: width,
                duration: _kFlyDuration,
                onTap: widget.onDanmakuTap != null
                    ? () => widget.onDanmakuTap!(flying.item)
                    : null,
                onCompleted: flying.onCompleted,
              ),
          ],
        );
      },
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
  final DanmakuItem item;
  final int track;
  final int tracks;
  final double containerWidth;
  final Duration duration;

  /// 点击回调（举报入口；null 不可点）
  final VoidCallback? onTap;
  final VoidCallback onCompleted;

  const _DanmakuFlyWidget({
    super.key,
    required this.item,
    required this.track,
    required this.tracks,
    required this.containerWidth,
    required this.duration,
    required this.onCompleted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 文本宽度预估（弹幕白字带描边，字号 13）
    final tp = TextPainter(
      text: TextSpan(
        text: item.content,
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
    // 轨道纵向位置：显示区域内按轨道数均分（1 轨=1/4 屏、4 轨=全屏高度）
    final areaHeight = 240.h * (tracks / 4);
    final slot = areaHeight / tracks;
    final top = MediaQuery.paddingOf(context).top + 8.h + track * slot;
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
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Text(
            item.content,
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
      ),
    );
  }
}
