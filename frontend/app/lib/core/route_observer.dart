import 'package:flutter/material.dart';

/// 全局路由观察者：注册到 MaterialApp.navigatorObservers，
/// Feed 页借此感知“页面被上层路由覆盖”，自动暂停当前视频。
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
