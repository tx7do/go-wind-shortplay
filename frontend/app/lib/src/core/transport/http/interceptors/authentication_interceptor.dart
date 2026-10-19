import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart' show GetIt;

// 私有字段不便用 initializing formal（字段名为 _ 开头），忽略该 lint
// ignore_for_file: prefer_initializing_formals

import 'package:shortplay_app/src/core/services/base_service.dart'
    show BaseService;
import 'package:shortplay_app/src/core/utilities/logger.dart' show fatal;

/// 认证服务接口，定义了获取和刷新令牌的方法
abstract class AuthService extends BaseService {
  AuthService({super.tag = 'AuthService'});

  /// 获取当前访问令牌
  String? getAccessToken();

  /// 获取刷新令牌
  String? getRefreshToken();

  /// 刷新访问令牌
  /// 返回新的访问令牌，失败时返回null
  Future<String?> refreshToken();

  /// 认证失败处理
  void authenticationFailed();
}

/// 认证拦截器
class AuthenticationInterceptor extends Interceptor {
  final AuthService Function() _authServiceFactory;
  final bool _autoRefreshToken;

  /// 进行中的刷新任务（并发 401 共享同一次刷新，避免刷新令牌轮换竞态）
  Future<String?>? _refreshing;

  /// 不触发刷新重试的认证接口（相对 baseUrl 路径）：
  /// 刷新接口自身 401 再刷新会无限递归；登录 401 是凭证错误，
  /// 误走刷新链路会把登录失败放大成登出跳转
  static const Set<String> _noRefreshPaths = <String>{
    '/auth/login',
    '/auth/refresh',
  };

  /// 重试标记（extra 键）：每个请求最多自动刷新重试一次，防止循环
  static const String _kExtraAuthRetried = 'authRetried';

  /// 创建认证拦截器实例
  /// [authServiceFactory] - 认证服务的懒工厂（推迟到首次请求时解析，
  ///   以规避 transport 初始化早于 repository 注册的顺序依赖）
  /// [autoRefreshToken] - 是否自动刷新令牌，默认为true
  AuthenticationInterceptor({
    required AuthService Function() authServiceFactory,
    bool autoRefreshToken = true,
  }) : _authServiceFactory = authServiceFactory,
       _autoRefreshToken = autoRefreshToken;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = _authServiceFactory().getAccessToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = _makeBearerToken(accessToken: token);
    }

    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 网络层错误（无响应）直接透传；不调用 handler 会让请求 Future 永不完成
    if (err.response == null) {
      return handler.next(err);
    }

    // 如果不需要自动刷新令牌或不是401错误，则直接传递错误
    if (!_autoRefreshToken || err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // 认证接口自身的 401 不刷新重试
    if (_noRefreshPaths.contains(err.requestOptions.path)) {
      return handler.next(err);
    }

    // 已刷新重试过仍 401，不再刷新
    if (err.requestOptions.extra[_kExtraAuthRetried] == true) {
      return handler.next(err);
    }

    // 尝试刷新令牌
    String? newToken;
    try {
      newToken = await _refreshToken();
    } catch (e) {
      fatal('Error refreshing token: $e');
      _authServiceFactory().authenticationFailed();
      return handler.next(err);
    }
    if (newToken == null || newToken.isEmpty) {
      // 刷新失败：AuthenticationService 已清理本地凭证并回首页（游客态），
      // 这里透传原始 401 给调用方收尾
      return handler.next(err);
    }

    // 使用新令牌重试请求（每个请求只重试一次）
    final options = err.requestOptions;
    options.headers['Authorization'] = _makeBearerToken(accessToken: newToken);
    options.extra[_kExtraAuthRetried] = true;

    // 重新发送请求（复用全局 Dio，携带 baseUrl 等配置）
    try {
      final response = await GetIt.instance<Dio>().fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// 刷新令牌（单飞：并发触发共享同一次刷新）
  Future<String?> _refreshToken() {
    final pending = _refreshing;
    if (pending != null) {
      return pending;
    }
    final task = _authServiceFactory().refreshToken();
    _refreshing = task;
    unawaited(task.whenComplete(() => _refreshing = null));
    return task;
  }

  /// 创建Bearer令牌
  String _makeBearerToken({String? accessToken}) {
    return "Bearer ${accessToken ?? ""}";
  }
}
