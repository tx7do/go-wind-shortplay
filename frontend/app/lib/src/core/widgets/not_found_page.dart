import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/widgets/brand_logo.dart';
import 'package:shortplay_app/src/core/widgets/gradient_button.dart';

/// 404 页面未找到
///
/// 当 GoRouter 路由匹配失败时展示，支持国际化。
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = S.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogoMark(size: 64),
                const SizedBox(height: 24),
                // 404 大字
                Text(
                  '404',
                  style: TextStyle(
                    fontSize: 72.sp,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface.withAlpha(36),
                    height: 1,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 16),
                // 标题
                Text(
                  loc.pageNotFound,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                // 描述
                Text(
                  loc.pageNotFoundDesc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
                const SizedBox(height: 32),
                // 返回首页按钮
                GradientButton(
                  label: loc.backToHome,
                  icon: Icons.home_outlined,
                  onPressed: () => context.go('/'),
                  height: 44,
                  fontSize: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

