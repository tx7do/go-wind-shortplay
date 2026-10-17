import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:shortplay_app/src/core/utilities/convert.dart';

/// 环境变量
///
/// 优先级：--dart-define > .env 文件（debug 读 .dev.env，release 读 .env）。
///
/// 常用覆盖方式：
/// ```
/// flutter run --dart-define=API_BASE=http://192.168.1.100:7700
/// ```
class Environments {
  Environments._(); // Private constructor to prevent instantiation

  /// dart-define 注入值（必须是 const 表达式，键为字面量）
  static const String _apiBaseDefine = String.fromEnvironment('API_BASE');
  static const String _mediaBaseDefine = String.fromEnvironment('MEDIA_BASE');

  /// 初始化
  static Future<void> init() async {
    const String fileName = kDebugMode ? '.dev.env' : '.env';
    await dotenv.load(fileName: fileName);
  }

  /// API 网关根地址（app BFF，:7700；分享页 /s/{id} 与其同源）
  ///
  /// 安卓模拟器统一走 10.0.2.2 映射宿主机；
  /// iOS 模拟器与宿主机共享网络，用 127.0.0.1；
  /// 真机联调改成宿主机局域网 IP。
  static String get apiBaseUrl {
    if (_apiBaseDefine.isNotEmpty) return _apiBaseDefine;
    return dotenv.maybeGet('API_BASE_URL') ?? '';
  }

  /// App 接口基地址（dio baseUrl）：根地址 + `/app/v1`
  ///
  /// feature service 里的相对路径（如 `/feed`）都基于该前缀解析；
  /// 传入值已带 `/app/v1` 后缀时不再重复拼接。
  static String get appApiBaseUrl {
    final root = apiBaseUrl.replaceAll(RegExp('/+\$'), '');
    if (root.endsWith('/app/v1')) return root;
    return '$root/app/v1';
  }

  /// 媒体（MinIO）公开访问地址
  ///
  /// 后端返回的 videoUrl/coverUrl/avatarUrl 是对象键（如 videos/2026/10/x.mp4），
  /// 需要拼接该前缀才能播放/展示：`{MEDIA_BASE}/{key}`。
  static String get mediaBaseUrl {
    if (_mediaBaseDefine.isNotEmpty) return _mediaBaseDefine;
    return dotenv.maybeGet('MEDIA_BASE_URL') ?? '';
  }

  /// 连接超时时间（秒）
  static Duration get connectionTimeout =>
      secondStringToDuration(dotenv.maybeGet('CONNECTION_TIMEOUT') ?? '');

  /// 接收数据超时时间（秒）
  static Duration get receiveTimeout =>
      secondStringToDuration(dotenv.maybeGet('RECEIVE_TIMEOUT') ?? '');

  /// 分享 H5 页面基础地址（复制链接用）
  ///
  /// 与 API 网关同源：`GET /s/{videoId}`（无 /app/v1 前缀）。
  static String get shareBaseUrl {
    final api = Uri.tryParse(apiBaseUrl);
    if (api == null || api.host.isEmpty) return apiBaseUrl;
    final port = api.hasPort ? ':${api.port}' : '';
    return '${api.scheme}://${api.host}$port';
  }
}
