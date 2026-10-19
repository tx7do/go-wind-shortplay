import 'package:dio/dio.dart' show DioException, DioExceptionType;
import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/transport/http/status.dart';
import 'package:shortplay_app/src/core/utilities/logger.dart';

abstract class BaseService {
  final Logger _logger;
  final bool _loadFromLocal = false;

  BaseService({String tag = 'Service'}) : _logger = Logger(tag);

  Logger get logger => _logger;

  bool get loadFromLocal => _loadFromLocal;

  /// 当前登录用户ID（未登录为 0）
  int get currentUserId {
    return GetIt.instance<UserAuthCache>().userId;
  }

  /// 是否已登录
  bool get hasLogin {
    return GetIt.instance<UserAuthCache>().hasLogin;
  }

  /// 将 DioException 统一转换为 Status 对象
  ///
  /// 所有继承 BaseService 的 service 都可直接使用。
  /// Retrofit/Dio 在服务端返回非 2xx 时会抛出 DioException，
  /// 通过此方法可将其转为业务层可判断的 Status。
  ///
  /// Kratos 错误体的 message 是开发向英文文本，不进用户可见链路
  /// （UI 层经 localizedApiErrorMessage 按 reason 取本地化文案）；
  /// 网关 5xx / 断网 / 超时等无错误体的场景，按 HTTP 状态码与异常类型
  /// 合成可本地化的 reason，Dio 原始异常文本只进日志。
  Status handleDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return Status(
        code: e.response?.statusCode,
        reason: data['reason'] as String?,
        message: data['message'] as String?,
        metadata: data['metadata'] != null
            ? Map<String, String>.from(data['metadata'] as Map)
            : null,
      );
    }

    logger.w('dio error without kratos body: '
        'type=${e.type.name} status=${e.response?.statusCode} message=${e.message}');
    return Status(
      code: e.response?.statusCode,
      reason: _reasonFromDioError(e),
    );
  }

  /// 非 Kratos 错误体时合成 reason（口径对齐 api_error_messages 映射表）
  String _reasonFromDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'TIMEOUT';
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return 'CONNECTION_ERROR';
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return 'UNKNOWN_ERROR';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code == 401) return 'UNAUTHORIZED';
        if (code == 403) return 'FORBIDDEN';
        if (code == 404) return 'NOT_FOUND';
        if (code == 429) return 'TOO_MANY_REQUESTS';
        if (code >= 500) {
          switch (code) {
            case 502:
              return 'BAD_GATEWAY';
            case 503:
              return 'SERVICE_UNAVAILABLE';
            case 504:
              return 'GATEWAY_TIMEOUT';
            default:
              return 'INTERNAL_SERVER_ERROR';
          }
        }
        return 'BAD_REQUEST';
    }
  }
}
