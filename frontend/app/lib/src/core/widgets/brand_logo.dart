import 'package:flutter/material.dart';

import 'package:shortplay_app/src/core/themes/app_colors.dart';

/// 品牌标（App 图标同款：渐变底 + 播放键），代码绘制免资产依赖
class BrandLogoMark extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius;

  const BrandLogoMark({
    super.key,
    this.size = 48,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: BrandColor.gradient,
        borderRadius: borderRadius ?? BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: BrandColor.rose.withAlpha(70),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        size: size * 0.62,
        color: Colors.white,
      ),
    );
  }
}
