import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/src/core/themes/app_colors.dart';

/// 品牌渐变主按钮（CTA 用；普通实心按钮走 FilledButton 主题）
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// 渐变底上的文字/图标色
  final Color foregroundColor;
  final double height;
  final double fontSize;
  final double radius;

  /// 为空时按钮宽度包裹内容（左右留 24 padding）；
  /// 传 [double.infinity] 可在父容器内撑满，或传具体宽度。
  final double? width;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.foregroundColor = Colors.white,
    this.height = 48,
    this.fontSize = 16,
    this.radius = 100,
    this.width,
  });

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _enabled ? BrandColor.gradient : null,
        color: _enabled
            ? null
            : Theme.of(context).colorScheme.onSurface.withAlpha(30),
        borderRadius: borderRadius,
        boxShadow: _enabled
            ? [
                BoxShadow(
                  color: BrandColor.rose.withAlpha(60),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Container(
            // 不传 width 时包裹内容（避免在宽松约束的父级里被拉伸到全宽）
            width: width,
            height: height.h,
            padding: width == null ? EdgeInsets.symmetric(horizontal: 24.w) : null,
            alignment: width == null ? null : Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: fontSize + 4.sp, color: foregroundColor),
                  SizedBox(width: 6.w),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize.sp,
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
