import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart' show Player;

/// 沉浸式播放页底部细进度条（抖音样式）
///
/// 白色细条 + 拖动 seek + 拖动时显示时间气泡；触摸区高于视觉条便于操作。
/// 自带 [Positioned] 贴底，必须放在 Stack 中。
class FeedProgressBar extends StatefulWidget {
  final Player player;

  /// 距 Stack 底部的距离（一般传宿主的安全区 + 与底导的间距）
  final double bottomInset;

  const FeedProgressBar({
    super.key,
    required this.player,
    required this.bottomInset,
  });

  @override
  State<FeedProgressBar> createState() => _FeedProgressBarState();
}

class _FeedProgressBarState extends State<FeedProgressBar> {
  bool _dragging = false;
  double _dragValue = 0;

  String _format(int ms) {
    final total = (ms / 1000).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _onDragStart(DragStartDetails details, BoxConstraints constraints) {
    final durationMs = widget.player.state.duration.inMilliseconds;
    if (durationMs <= 0) return;
    setState(() {
      _dragging = true;
      _dragValue =
          (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    });
  }

  void _onDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (widget.player.state.duration.inMilliseconds <= 0) return;
    setState(() {
      _dragValue = (_dragValue + details.delta.dx / constraints.maxWidth)
          .clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    final durationMs = widget.player.state.duration.inMilliseconds;
    if (durationMs > 0) {
      unawaited(
        widget.player.seek(
          Duration(milliseconds: (_dragValue * durationMs).round()),
        ),
      );
    }
    setState(() => _dragging = false);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12.w,
      right: 12.w,
      bottom: widget.bottomInset,
      child: StreamBuilder<Duration>(
        stream: widget.player.stream.position,
        initialData: widget.player.state.position,
        builder: (context, snapshot) {
          final positionMs = snapshot.data?.inMilliseconds ?? 0;
          final durationMs = widget.player.state.duration.inMilliseconds;
          final value = _dragging
              ? _dragValue
              : durationMs > 0
                  ? (positionMs / durationMs).clamp(0.0, 1.0)
                  : 0.0;

          return LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 拖动时的时间气泡（当前 / 总时长）
                  if (_dragging)
                    Align(
                      alignment: Alignment(
                        value * 2 - 1,
                        0,
                      ),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${_format((value * durationMs).round())} / ${_format(durationMs)}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  // 触摸区（高于视觉条）
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (d) =>
                        _onDragStart(d, constraints),
                    onHorizontalDragUpdate: (d) =>
                        _onDragUpdate(d, constraints),
                    onHorizontalDragEnd: _onDragEnd,
                    onHorizontalDragCancel: () =>
                        setState(() => _dragging = false),
                    child: SizedBox(
                      height: 22.h,
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // 底轨
                            Container(
                              height: _dragging ? 4.r : 2.5.r,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(70),
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                            // 已播
                            FractionallySizedBox(
                              widthFactor: value,
                              child: Container(
                                height: _dragging ? 4.r : 2.5.r,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                            ),
                            // 拖动圆点
                            if (_dragging)
                              Positioned(
                                left: 0,
                                right: 0,
                                child: Align(
                                  alignment: Alignment(value * 2 - 1, 0),
                                  child: Container(
                                    width: 12.r,
                                    height: 12.r,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black38,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
