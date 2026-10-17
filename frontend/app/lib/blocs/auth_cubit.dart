import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/user.dart';
import '../services/services.dart';

/// 登录态。
enum AuthStatus { unknown, authenticated, unauthenticated }

/// 登录态 + 当前用户。
class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.busy = false,
    this.error,
  });

  final AuthStatus status;
  final User? user;
  final bool busy;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool clearUser = false,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, user, busy, error];
}

/// 认证域 Cubit：启动恢复会话、登录 / 注册 / 登出、401 强制登出。
class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthState());

  /// 启动时调用：有 token 视为已登录（用户信息来自本地缓存）。
  Future<void> init() async {
    final user = Services.tokens.cachedUser;
    if (Services.tokens.hasToken) {
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } else {
      emit(
        state.copyWith(status: AuthStatus.unauthenticated, clearUser: true),
      );
    }
  }

  /// 用户名密码登录。
  Future<bool> login(String username, String password) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final result = await Services.auth.login(username, password);
      await _saveLogin(result);
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
      return false;
    }
  }

  /// 注册并登录（409 USERNAME_TAKEN 提示用户名已存在）。
  Future<bool> register(
    String username,
    String password,
    String nickname,
  ) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final result =
          await Services.auth.register(username, password, nickname);
      await _saveLogin(result);
      return true;
    } on ApiException catch (e) {
      var msg = e.message;
      if (e.isReason('USERNAME_TAKEN')) msg = '用户名已被占用，换一个试试';
      emit(state.copyWith(busy: false, error: msg));
      return false;
    }
  }

  /// 主动登出（接口尽力而为，本地一定清干净）。
  Future<void> logout() async {
    try {
      await Services.auth.logout();
    } catch (_) {
      // 登出接口失败不阻断本地清理。
    }
    await _clearLocal();
  }

  /// 401 时由网络层回调：清 token 引导重新登录。
  Future<void> forceLogout() async {
    await _clearLocal();
  }

  /// 编辑资料成功后同步本地用户与缓存。
  Future<void> updateUser(User user) async {
    emit(state.copyWith(user: user));
    await Services.tokens.updateCachedUser(user);
  }

  Future<void> _saveLogin(LoginResult result) async {
    final user = result.user ?? const User(id: 0, nickname: '用户');
    await Services.tokens.save(
      token: result.token,
      refreshToken: result.refreshToken,
      user: user,
    );
    emit(
      state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        busy: false,
      ),
    );
  }

  Future<void> _clearLocal() async {
    await Services.tokens.clear();
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        busy: false,
      ),
    );
  }
}
