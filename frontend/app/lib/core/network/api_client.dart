import 'package:dio/dio.dart';

import '../config.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';

/// 401 时回调（由 AuthCubit 注册，用于清 token 并引导重新登录）。
typedef UnauthorizedCallback = void Function();

/// Dio 网络客户端封装。
///
/// - baseURL 优先取编译期常量 `API_BASE`（见 [AppConfig]）；
/// - 请求拦截器自动附带 `Authorization: Bearer <token>`（shared_preferences 持久化）；
/// - 401 时清除本地 token 并触发 [UnauthorizedCallback]；
/// - 业务错误统一解析为 [ApiException]。
class ApiClient {
  ApiClient({
    required TokenStore tokenStore,
    required UnauthorizedCallback onUnauthorized,
  })  :
        // 字段私有，命名参数无法写成初始化形式（this._x），忽略该 lint。
        // ignore: prefer_initializing_formals
        _tokenStore = tokenStore,
        // ignore: prefer_initializing_formals
        _onUnauthorized = onUnauthorized {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiPrefix,
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = _tokenStore.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          // 会话失效：清 token 并通知引导重新登录。
          if (e.response?.statusCode == 401) {
            await _tokenStore.clear();
            _onUnauthorized();
          }
          handler.next(e);
        },
      ),
    );
  }

  late final Dio _dio;
  final TokenStore _tokenStore;
  final UnauthorizedCallback _onUnauthorized;

  /// GET，返回 JSON 对象。
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.get<Object?>(path, queryParameters: query);
      return _asMap(res.data, path);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// POST，返回 JSON 对象。
  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.post<Object?>(path, data: data, queryParameters: query);
      return _asMap(res.data, path);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// PUT，返回 JSON 对象。
  Future<Map<String, dynamic>> putJson(String path, {Object? data}) async {
    try {
      final res = await _dio.put<Object?>(path, data: data);
      return _asMap(res.data, path);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// DELETE，返回 JSON 对象。
  Future<Map<String, dynamic>> deleteJson(String path) async {
    try {
      final res = await _dio.delete<Object?>(path);
      return _asMap(res.data, path);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// PUT 原始二进制（分片上传专用，Content-Type: application/octet-stream）。
  Future<Map<String, dynamic>> putBytes(String path, List<int> bytes) async {
    try {
      final res = await _dio.put<Object?>(
        path,
        data: bytes,
        options: Options(
          contentType: 'application/octet-stream',
          headers: {Headers.contentLengthHeader: bytes.length},
        ),
      );
      return _asMap(res.data, path);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// 校验响应体为 JSON 对象（部分接口成功时可能无 body，返回空 Map）。
  Map<String, dynamic> _asMap(Object? data, String path) {
    if (data == null) return <String, dynamic>{};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException(
      reason: 'BAD_RESPONSE',
      message: '接口 $path 返回了不支持的数据格式',
    );
  }
}
