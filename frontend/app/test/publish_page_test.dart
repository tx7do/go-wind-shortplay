import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/features/publish/pages/publish_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 发布页未选视频的引导态（已登录，避免弹登录引导框）
  testWidgets('发布页引导态渲染大区块引导与入口按钮', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cache = UserAuthCache();
    GetIt.I.registerSingleton<SharedPreferences>(prefs);
    GetIt.I.registerSingleton<UserAuthCache>(cache);
    await cache.saveAccessToken('test-token');

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          locale: const Locale('zh', 'CN'),
          home: const PublishPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('发布'), findsWidgets); // 标题栏 + 底部导航语义
    expect(find.text('选择一段视频开始创作'), findsOneWidget);
    expect(find.text('支持 5 分钟以内的短视频'), findsOneWidget);
    expect(find.text('从相册选择'), findsOneWidget);
    expect(find.text('草稿箱'), findsOneWidget);
    // 「拍摄」仅移动端提供（image_picker 桌面实现只支持文件选择）
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      expect(find.text('拍摄视频'), findsOneWidget);
    }
  });
}
