import 'package:dio/dio.dart';

/// 统一业务异常：后端错误响应为 `{"code":..,"reason":"..","message":".."}`。
///
/// 网络层（超时/断网等）也会被归一化为 [ApiException]，reason 使用
/// `NETWORK_ERROR` 等内置枚举，UI 层只需捕获本异常展示 [message]。
class ApiException implements Exception {
  ApiException({
    this.statusCode,
    required this.reason,
    required this.message,
  });

  final int? statusCode;
  final String reason;
  final String message;

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return ApiException(
        statusCode: (data['code'] as num?)?.toInt() ?? e.response?.statusCode,
        reason: (data['reason'] as String?) ?? 'UNKNOWN',
        message: (data['message'] as String?) ?? '请求失败，请稍后重试',
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return ApiException(
          statusCode: null,
          reason: 'NETWORK_ERROR',
          message: '网络连接失败，请检查网络后重试',
        );
      case DioExceptionType.badCertificate:
        return ApiException(
          reason: 'BAD_CERTIFICATE',
          message: '证书校验失败',
        );
      case DioExceptionType.cancel:
        return ApiException(reason: 'CANCELLED', message: '请求已取消');
      case DioExceptionType.badResponse:
        return ApiException(
          statusCode: e.response?.statusCode,
          reason: 'BAD_RESPONSE',
          message: '服务异常（${e.response?.statusCode}），请稍后重试',
        );
      default:
        return ApiException(
          reason: 'UNKNOWN',
          message: e.error?.toString() ?? '请求失败，请稍后重试',
        );
    }
  }

  /// 判断是否为指定错误原因（如 DUPLICATE_REPORT、NOT_OWNER）。
  bool isReason(String r) => reason == r;

  @override
  String toString() => 'ApiException($statusCode, $reason, $message)';
}
