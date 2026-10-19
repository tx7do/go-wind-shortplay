import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/src/core/widgets/gradient_button.dart';

/// 统一空态 / 引导态（图标软底圆 + 标题 + 副标题 + 渐变操作）
///
/// [onDark] 为真时用于视频黑底沉浸页（图标/文案反白）。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool onDark;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseWhite = theme.colorScheme.onSurface;

    final iconColor = onDark ? Colors.white.withAlpha(200) : theme.colorScheme.primary;
    final iconBg = onDark
        ? Colors.white.withAlpha(26)
        : theme.colorScheme.primary.withAlpha(22);
    final titleColor = onDark ? Colors.white : baseWhite;
    final subtitleColor = onDark ? Colors.white.withAlpha(170) : baseWhite.withAlpha(140);

    // 矮窗口（如桌面端小窗下的 Tab 区）高度不足时可滚动，避免 RenderFlex 溢出
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88.r,
              height: 88.r,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 40.r, color: iconColor),
            ),
            SizedBox(height: 18.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 13.sp, color: subtitleColor),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 22.h),
              GradientButton(
                label: actionLabel!,
                onPressed: onAction,
                height: 42,
                fontSize: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
