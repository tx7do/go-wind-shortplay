import 'package:shortplay_app/src/core/config/environments.dart';

/// 媒体地址解析工具
///
/// 后端 protojson 返回的 videoUrl / coverUrl / avatarUrl 是对象存储的对象键
/// （如 `videos/2026/10/xxx.mp4`），需要拼接 MEDIA_BASE 前缀才能访问；
/// 若本身已是完整 http(s) 地址则原样返回。
class MediaUrl {
  MediaUrl._();

  /// 解析媒体对象键为可访问 URL
  static String resolve(String? keyOrUrl) {
    final value = keyOrUrl ?? '';
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final base = Environments.mediaBaseUrl;
    if (base.isEmpty) return value;

    final baseUri = Uri.tryParse(base);
    if (baseUri == null || !baseUri.hasScheme) return value;

    return '${base.replaceAll(RegExp(r'/+$'), '')}/${value.replaceAll(RegExp('^/+'), '')}';
  }
}
