import '../core/network/api_client.dart';
import '../models/user.dart';

/// 登录 / 注册 / 登出。
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  /// 用户名密码登录。
  Future<LoginResult> login(String username, String password) async {
    final data = await _api.postJson(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    return LoginResult.fromJson(data);
  }

  /// 注册并自动登录（409 USERNAME_TAKEN 由 UI 层提示）。
  Future<LoginResult> register(
    String username,
    String password,
    String nickname,
  ) async {
    final data = await _api.postJson(
      '/auth/register',
      data: {
        'username': username,
        'password': password,
        'nickname': nickname,
      },
    );
    return LoginResult.fromJson(data);
  }

  /// 刷新令牌。
  Future<LoginResult> refresh(String refreshToken) async {
    final data = await _api.postJson(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return LoginResult.fromJson(data);
  }

  /// 登出（需登录；失败不抛出由调用方兜底）。
  Future<void> logout() => _api.postJson('/auth/logout');
}
