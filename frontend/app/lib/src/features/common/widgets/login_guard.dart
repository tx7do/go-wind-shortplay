import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart' show RouteNames;
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:get_it/get_it.dart' show GetIt;

/// 登录守卫：游客触发互动时引导登录
///
/// 用法：
/// ```dart
/// if (!await ensureLogin(context)) return; // 用户取消或已是游客
/// doLike();
/// ```
Future<bool> ensureLogin(BuildContext context) async {
  if (GetIt.instance<UserAuthCache>().hasLogin) return true;

  final loc = S.of(context);
  final goLogin = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_person_outlined,
                size: 40.sp,
                color: theme.colorScheme.primary,
              ),
              SizedBox(height: 12.h),
              Text(
                loc.guestInteractionTitle,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                loc.guestInteractionDesc,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 44.h,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text(loc.goLogin),
                ),
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text(loc.cancel),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (goLogin != true) return false;
  if (!context.mounted) return false;
  await context.pushNamed(RouteNames.login);
  return GetIt.instance<UserAuthCache>().hasLogin;
}

/// 当前是否已登录
bool get hasLogin => GetIt.instance<UserAuthCache>().hasLogin;
