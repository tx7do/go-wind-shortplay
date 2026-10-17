import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:shortplay_app/src/core/config/environments.dart';
import 'package:shortplay_app/src/core/repositories/init.dart' as repos;
import 'package:shortplay_app/src/core/transport/init.dart' as transport;
import 'package:shortplay_app/src/core/widgets/error_page.dart';

import 'init_thirdparty_plugins.dart';

/// 应用初始化
Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Environments.init();

  await initThirdPartyPlugins();

  _initTransport();

  await repos.init();

  _initErrorWidget();
}

/// 初始化传输层（注册全局 Dio：baseUrl + 认证拦截器）
void _initTransport() {
  transport.init();
}

/// 自定义报错页面
void _initErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint(details.toString());

    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }

    return CustomErrorWidget(errorMessage: details.exceptionAsString());
  };
}

/// 清理
void globalDispose() {}
