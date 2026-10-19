import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/services/interaction_service.dart';
import 'package:shortplay_app/src/features/common/services/uba_service.dart';
import 'package:shortplay_app/src/features/common/widgets/login_guard.dart';

/// 双击点赞（抖音口径）：红心爆开动画 + 真实点赞
///
/// - 未点赞：播动画 + 震动 + ensureLogin 后调点赞接口，经 [onUpdated] 回写状态
/// - 已点赞：只播动画（与抖音一致，不取消点赞）
Future<void> runDoubleTapLike(
  BuildContext context, {
  required Video video,
  required ValueChanged<Video> onUpdated,
}) async {
  HapticFeedback.lightImpact();
  if (video.liked) return;

  if (!await ensureLogin(context)) return;
  try {
    final result = await InteractionService().like(
      targetType: LikeTargetType.video,
      targetId: video.id,
    );
    if (result.liked) {
      UbaService().report(UbaEvent(
        eventType: UbaEventType.videoLike,
        videoId: video.id,
      ));
      onUpdated(video.copyWith(
        liked: true,
        likeCount: video.likeCount + 1,
      ));
    }
  } catch (_) {
    // 双击点赞失败静默（右侧操作栏仍可点赞，错误不阻塞刷视频）
    if (context.mounted) {
      EasyLoading.showToast(S.of(context).errorDefault);
    }
  }
}

/// 红心爆开动画层：放在宿主 Stack 顶层的 IgnorePointer 层内。
///
/// 用法：宿主持 [LikeBurstController]（State 内唯一），
/// 双击回调里 `controller.burst(localPosition)`。
class LikeBurstController {
  final List<_BurstHeart> _hearts = [];
  void Function()? _listener;

  void burst(Offset position) {
    final heart = _BurstHeart(position);
    _hearts.add(heart);
    _listener?.call();
  }

  void _remove(_BurstHeart heart) {
    _hearts.remove(heart);
    _listener?.call();
  }

  void dispose() {
    _hearts.clear();
    _listener = null;
  }
}

class _BurstHeart {
  final Offset position;
  _BurstHeart(this.position);
}

/// 动画层（放进宿主 Stack：Positioned.fill(child: LikeBurstLayer(controller))）
class LikeBurstLayer extends StatefulWidget {
  final LikeBurstController controller;

  const LikeBurstLayer({super.key, required this.controller});

  @override
  State<LikeBurstLayer> createState() => _LikeBurstLayerState();
}

class _LikeBurstLayerState extends State<LikeBurstLayer> {
  @override
  void initState() {
    super.initState();
    widget.controller._listener = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void didUpdateWidget(covariant LikeBurstLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._listener = null;
      widget.controller._listener = () {
        if (mounted) setState(() {});
      };
    }
  }

  @override
  void dispose() {
    widget.controller._listener = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final heart in List.of(widget.controller._hearts))
            _HeartWidget(
              key: ObjectKey(heart),
              position: heart.position,
              onDone: () => widget.controller._remove(heart),
            ),
        ],
      ),
    );
  }
}

class _HeartWidget extends StatefulWidget {
  final Offset position;
  final VoidCallback onDone;

  const _HeartWidget({super.key, required this.position, required this.onDone});

  @override
  State<_HeartWidget> createState() => _HeartWidgetState();
}

class _HeartWidgetState extends State<_HeartWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // 弹出（0~0.25 easeOutBack 放大）→ 上飘 + 淡出
        final scale =
            t < 0.25 ? Curves.easeOutBack.transform(t / 0.25) : 1.0;
        final rise = t < 0.25
            ? 0.0
            : Curves.easeOut.transform((t - 0.25) / 0.75) * 56.h;
        final opacity = t < 0.55 ? 1.0 : (1 - t) / 0.45;

        return Positioned(
          left: widget.position.dx - 36.r,
          top: widget.position.dy - 36.r - rise,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Icon(
                Icons.favorite_rounded,
                size: 72.r,
                color: BrandColor.rose,
                shadows: [
                  Shadow(color: BrandColor.rose.withAlpha(120), blurRadius: 18),
                  Shadow(color: Colors.black.withAlpha(90), blurRadius: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
