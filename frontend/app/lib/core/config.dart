/// 全局配置：API 地址等编译期常量。
///
/// 通过 `--dart-define` 覆盖后端地址：
/// ```
/// flutter run --dart-define=API_BASE=http://127.0.0.1:6700
/// ```
///
/// 缺省值说明：
/// - `http://10.0.2.2:6700` 是 Android 模拟器访问宿主机回环地址的专用别名；
/// - iOS 模拟器请显式传入 `--dart-define=API_BASE=http://127.0.0.1:6700`
///   （iOS 模拟器与宿主机共享网络栈，直接用 127.0.0.1 即可）。
class AppConfig {
  AppConfig._();

  /// 后端 App 网关根地址（不含路径）。
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:6700',
  );

  /// REST 接口前缀，所有业务请求都挂在该前缀下。
  static const String apiPrefix = '$apiBase/app/v1';

  /// 分享短链基地址（对应后端 `GET /s/{videoId}` H5 页，无 /app/v1 前缀）。
  static const String shareBase = apiBase;

  /// 服务端返回的媒体地址可能是相对路径，统一补全为绝对 URL。
  static String absolutize(String url) {
    if (url.isEmpty || url.startsWith('http')) return url;
    return apiBase + (url.startsWith('/') ? url : '/$url');
  }
}
