import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'blocs/auth_cubit.dart';
import 'blocs/notify_cubit.dart';
import 'core/network/api_client.dart';
import 'core/route_observer.dart';
import 'core/storage/token_store.dart';
import 'core/theme.dart';
import 'pages/main_shell.dart';
import 'services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // media_kit 原生库初始化（Android/iOS 必需，桌面端也依赖它）。
  MediaKit.ensureInitialized();
  final authCubit = await bootstrap();
  runApp(ShortplayApp(authCubit: authCubit));
}

/// 初始化全局服务并恢复登录态（main 与冒烟测试共用）。
Future<AuthCubit> bootstrap() async {
  final prefs = await SharedPreferences.getInstance();
  final tokens = TokenStore(prefs);
  final authCubit = AuthCubit();
  final api = ApiClient(
    tokenStore: tokens,
    // 会话失效（401）时由网络层触发强制登出。
    onUnauthorized: authCubit.forceLogout,
  );
  Services.init(apiClient: api, tokenStore: tokens);
  await authCubit.init();
  return authCubit;
}

/// 应用根组件：装配全局 Bloc（登录态 / 消息角标）与主题。
class ShortplayApp extends StatelessWidget {
  const ShortplayApp({super.key, required this.authCubit});

  final AuthCubit authCubit;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<NotifyCubit>(create: (_) => NotifyCubit()),
      ],
      child: MaterialApp(
        title: 'GoWind 短视频',
        theme: AppTheme.dark(),
        // Feed 页依赖路由观察者感知被覆盖并暂停视频。
        navigatorObservers: [routeObserver],
        home: const MainShell(),
      ),
    );
  }
}
