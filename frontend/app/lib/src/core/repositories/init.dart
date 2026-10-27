import 'package:get_it/get_it.dart';

import 'index.dart';
import 'package:shortplay_app/src/core/preference/preference.dart';
import 'package:shortplay_app/src/core/transport/sse/sse_client.dart'
    show sseClient;

Future<void> init() async {
  final getIt = GetIt.instance;

  getIt.registerLazySingleton<UserAuthCache>(() => UserAuthCache());
  getIt.registerLazySingleton<UserPreferenceCache>(() => UserPreferenceCache());
  getIt.registerLazySingleton<LanguageListRepository>(
    () => LanguageListRepository(),
  );

  await GetIt.instance<UserAuthCache>().init();
  await GetIt.instance<UserPreferenceCache>().init();

  // SSE 实时通道：监听登录态，登录即连、登出即断（私信推送/通知推送共用）
  sseClient.attach();
}
