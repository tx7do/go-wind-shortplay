import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:get_it/get_it.dart' show GetIt;
import 'package:cached_query/cached_query.dart' show Mutation;

import 'package:shortplay_app/src/app_router/app_router.dart'
    show AppRouter, RouteNames;
import 'package:shortplay_app/src/core/config/environments.dart'
    show Environments;
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart'
    show UserAuthCache;
import 'package:shortplay_app/src/core/utilities/convert.dart'
    show jsonInt, jsonString;
import 'package:shortplay_app/src/core/transport/http/index.dart';

export 'package:get_it/get_it.dart';

/// 登录/注册响应（protojson）
///
/// ```json
/// {
///   "authenticator": {"accessToken", "refreshToken", "expiresIn", "tokenType": "Bearer"},
///   "user": {"id", "username", "nickname", "avatarUrl", "bio"}
/// }
/// ```
class AuthResult {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  /// 当前登录用户（id/username/nickname/avatarUrl/bio）
  final Map<String, dynamic> user;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final authenticator =
        (json['authenticator'] as Map<String, dynamic>?) ?? const {};
    final user = (json['user'] as Map<String, dynamic>?) ?? const {};
    return AuthResult(
      accessToken: jsonString(authenticator['accessToken']),
      refreshToken: jsonString(authenticator['refreshToken']),
      tokenType: jsonString(authenticator['tokenType'], fallback: 'Bearer'),
      expiresIn: jsonInt(authenticator['expiresIn']),
      user: user,
    );
  }
}

/// 认证服务
///
/// 使用 Mutation 管理登录/注册/登出/刷新令牌等写操作，
/// 自动获得加载状态、错误处理、缓存失效等能力。
/// 令牌持久化沿用底座 [UserAuthCache]（SharedPreferences）。
class AuthenticationService extends AuthService {
  AuthenticationService() : super(tag: 'AuthenticationService');

  /// 上传等场景需要绕过认证头时，用独立的裸 Dio 调认证接口
  Dio get _dio => GetIt.instance<Dio>();

  /// 获取当前访问令牌
  @override
  String? getAccessToken() {
    return GetIt.instance<UserAuthCache>().accessToken;
  }

  /// 获取刷新令牌
  @override
  String? getRefreshToken() {
    return GetIt.instance<UserAuthCache>().refreshToken;
  }

  /// 刷新访问令牌（供 AuthenticationInterceptor 调用）
  @override
  Future<String?> refreshToken() async {
    final token = getRefreshToken();
    if (token == null || token.isEmpty) {
      doAuthenticationFailed();
      return null;
    }

    final result = await _doRefreshToken(token);
    if (result != null && result.accessToken.isNotEmpty) {
      return result.accessToken;
    }

    doAuthenticationFailed();
    return null;
  }

  @override
  void authenticationFailed() {
    doAuthenticationFailed();
  }

  /// 清除所有令牌与用户信息
  Future<void> clearTokens() async {
    await GetIt.instance<UserAuthCache>().clearTokens();
  }

  /// 保存新的令牌与用户信息
  Future<void> saveAuth(AuthResult result) async {
    final cache = GetIt.instance<UserAuthCache>();
    await cache.saveAuthInfo(
      result.accessToken,
      refreshToken: result.refreshToken,
    );
    await cache.saveUserInfo(result.user);
  }

  // ─── Mutations ───────────────────────────────────────

  /// 用户登录 Mutation
  ///
  /// 用法：
  /// ```dart
  /// final mutation = authService.loginMutation();
  /// // 在 UI 中通过 MutationBuilder 监听状态
  /// // 触发：mutation.mutate(LoginParams(username: 'xxx', password: 'xxx'));
  /// ```
  Mutation<AuthResult, LoginParams> loginMutation() {
    return Mutation<AuthResult, LoginParams>(
      mutationFn: (params) async {
        final result = await _postAuth('/auth/login', {
          'username': params.username,
          'password': _encryptPassword(params.password),
        });
        await doLoginSuccess(result);
        return result;
      },
    );
  }

  /// 用户注册 Mutation（成功即自动登录）
  Mutation<AuthResult, RegisterParams> registerMutation() {
    return Mutation<AuthResult, RegisterParams>(
      mutationFn: (params) async {
        final result = await _postAuth('/auth/register', {
          'username': params.username,
          'password': _encryptPassword(params.password),
          'nickname': params.nickname,
        });
        await doLoginSuccess(result);
        return result;
      },
    );
  }

  /// 用户登出 Mutation
  Mutation<void, void> logoutMutation() {
    return Mutation<void, void>(
      mutationFn: (_) async {
        try {
          await _dio.post('/auth/logout');
        } catch (e) {
          // 服务端登出失败不阻断本地清理
          logger.w('logout api failed (ignored): $e');
        }
        await GetIt.instance<UserAuthCache>().clearTokens();
      },
    );
  }

  /// 直接调用刷新令牌（裸 Dio，避免被认证拦截器二次加头）
  Future<AuthResult?> _doRefreshToken(String refreshToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data;
      if (data == null) return null;
      return AuthResult.fromJson(data);
    } on DioException catch (e) {
      logger.w('refresh token failed: ${handleDioError(e).getReason}');
      return null;
    }
  }

  /// 登录/注册请求（认证接口不经过认证拦截器加头，直接使用全局 Dio 即可：
  /// 未登录时拦截器不会附加 Authorization）
  Future<AuthResult> _postAuth(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      final data = res.data;
      if (data == null) {
        throw DioException(
          requestOptions: RequestOptions(path: path),
          error: 'empty response',
        );
      }
      return AuthResult.fromJson(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  // ─── 内部方法 ────────────────────────────────────────

  /// 认证成功处理
  Future<void> doLoginSuccess(AuthResult result) async {
    await saveAuth(result);
  }

  /// 认证失败处理：清理本地令牌并回到首页（游客态）
  void doAuthenticationFailed() {
    GetIt.instance<UserAuthCache>().clearTokens();
    AppRouter.router.goNamed(RouteNames.home);
  }

  /// 密码传输加密：base64(AES-CBC/PKCS7(明文, key=iv=AES_KEY))
  ///
  /// 后端登录校验会先 AES 解密再比对 bcrypt；注册侧同样以密文入库前哈希，
  /// 两端口径必须一致（与基座 flutter_app 的 _encryptPassword 同款实现）。
  static String _encryptPassword(String password) {
    final keyBytes = encrypt.Key.fromUtf8(Environments.aesKey);
    final iv = encrypt.IV.fromUtf8(Environments.aesKey);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(keyBytes, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );
    return encrypter.encrypt(password, iv: iv).base64;
  }
}

/// 登录参数
class LoginParams {
  final String username;
  final String password;

  const LoginParams({required this.username, required this.password});
}

/// 注册参数
class RegisterParams {
  final String username;
  final String password;
  final String nickname;

  const RegisterParams({
    required this.username,
    required this.password,
    required this.nickname,
  });
}
