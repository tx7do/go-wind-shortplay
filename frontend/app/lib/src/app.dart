import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:shortplay_app/generated/l10n.dart' as l10n;

import 'package:shortplay_app/src/core/extensions/app_localizations_context.dart';
import 'package:shortplay_app/src/core/constants/breakpoints.dart';
import 'package:shortplay_app/src/core/themes/index.dart' as theme;
import 'package:shortplay_app/src/core/utilities/logger.dart' show debug;
import 'package:shortplay_app/src/core/utilities/platform.dart';

import 'app_router/app_router.dart' as pages;

/// 应用程序
class ShortPlayApp extends StatefulWidget {
  const ShortPlayApp({super.key});

  @override
  State<ShortPlayApp> createState() => _ShortPlayAppState();
}

class _ShortPlayAppState extends State<ShortPlayApp> {

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Breakpoints.designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      ensureScreenSize: true,
      builder: (ctx, child) {
        // Web / 桌面端：窗口尺寸可自由变化且远大于手机设计稿，
        // 动态将 designSize 设为当前视窗尺寸，使 .w/.h/.sp 始终 1:1，
        // 避免 375 设计稿在 1080p 窗口下整体放大 3 倍+。
        if (kIsWeb || PlatformUtils.isDesktop) {
          ScreenUtil.init(
            ctx,
            designSize: Size(
              MediaQuery.of(ctx).size.width,
              MediaQuery.of(ctx).size.height,
            ),
            minTextAdapt: false,
          );
        }
        return _buildMaterialApp(context);
      },
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildMaterialApp(BuildContext context) {
    final delegate = l10n.S.delegate;
    final cubit = context.read<theme.AppThemeCubit>();
    cubit.init();

    // 监听 Cubit 变化，获取最新的 seedColor
    final state = context.watch<theme.AppThemeCubit>().state;
    Color? seedColor;
    if (state is theme.AppThemeInitial) {
      seedColor = state.seedColor;
    } else if (state is theme.AppThemeModified) {
      seedColor = state.seedColor;
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.loc.appName,
      routerConfig: pages.AppRouter.router,
      theme: theme.getLightTheme(seedColor: seedColor),
      darkTheme: theme.getDarkTheme(seedColor: seedColor),
      themeMode: context.watch<theme.AppThemeCubit>().themeMode,
      locale: context.watch<theme.AppThemeCubit>().currentLocale,
      builder: (context, routerChild) {
        // EasyLoading 作为路由的外部包装
        final easyLoadingBuilder = EasyLoading.init();
        return easyLoadingBuilder(context, routerChild);
      },
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        delegate,
      ],
      supportedLocales: l10n.S.delegate.supportedLocales,
      localeListResolutionCallback: (locales, supportedLocales) {
        debug('locale list: $locales');
        if (locales == null || locales.isEmpty) {
          return supportedLocales.first;
        }
        for (final locale in locales) {
          // 精确匹配
          if (supportedLocales.contains(locale)) return locale;
          // 语言代码匹配（忽略国家代码差异，如 zh-CN → zh_CN）
          final match = supportedLocales.where(
            (sl) => sl.languageCode == locale.languageCode,
          );
          if (match.isNotEmpty) return match.first;
        }
        return supportedLocales.first;
      },
    );
  }
}
