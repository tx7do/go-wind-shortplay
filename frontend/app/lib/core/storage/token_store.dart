import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';

/// 基于 shared_preferences 的令牌与用户信息持久化。
class TokenStore {
  TokenStore(this._prefs);

  static const String _keyToken = 'sp_access_token';
  static const String _keyRefreshToken = 'sp_refresh_token';
  static const String _keyUser = 'sp_user_json';

  final SharedPreferences _prefs;

  /// 是否已登录（存在 accessToken）。
  bool get hasToken => _prefs.getString(_keyToken)?.isNotEmpty ?? false;

  String? get token => _prefs.getString(_keyToken);

  String? get refreshToken => _prefs.getString(_keyRefreshToken);

  /// 本地缓存的用户信息（登录时写入，供启动时快速渲染）。
  User? get cachedUser {
    final raw = _prefs.getString(_keyUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return User.fromJson(map);
    } catch (_) {
      // 缓存损坏时忽略，走未登录逻辑。
    }
    return null;
  }

  /// 保存登录态（token + 用户信息）。
  Future<void> save({
    required String token,
    String? refreshToken,
    User? user,
  }) async {
    await _prefs.setString(_keyToken, token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _prefs.setString(_keyRefreshToken, refreshToken);
    }
    if (user != null) {
      await _prefs.setString(_keyUser, jsonEncode(user.toJson()));
    }
  }

  /// 更新本地缓存的用户资料（编辑资料后调用）。
  Future<void> updateCachedUser(User user) =>
      _prefs.setString(_keyUser, jsonEncode(user.toJson()));

  /// 清空登录态（登出或 401 时调用）。
  Future<void> clear() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyRefreshToken);
    await _prefs.remove(_keyUser);
  }
}
