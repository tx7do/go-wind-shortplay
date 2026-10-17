import 'package:cached_query/cached_query.dart' show MutationSuccess;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/transport/http/api_error_messages.dart'
    show localizedApiErrorMessage;
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utils/responsive_utils.dart';
import 'package:shortplay_app/src/features/auth/services/authentication_service.dart';

/// 登录 / 注册页
///
/// 登录：POST /auth/login {username,password}
/// 注册：POST /auth/register {username,password,nickname}（成功即登录）
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _authService = AuthenticationService();
  bool _obscurePassword = true;
  bool _isRegisterMode = false;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isRegisterMode && _nicknameController.text.trim().isEmpty) {
      _showToast(S.of(context).nicknameHint, isError: true);
      return;
    }

    setState(() => _submitting = true);
    final loc = S.of(context);

    try {
      final mutation = _isRegisterMode
          ? _authService.registerMutation().mutate(RegisterParams(
              username: _usernameController.text.trim(),
              password: _passwordController.text,
              nickname: _nicknameController.text.trim(),
            ))
          : _authService.loginMutation().mutate(LoginParams(
              username: _usernameController.text.trim(),
              password: _passwordController.text,
            ));
      final result = await mutation;

      if (!mounted) return;
      if (result is MutationSuccess &&
          (result.data as dynamic)?.accessToken != null &&
          ((result.data as dynamic).accessToken as String).isNotEmpty) {
        _showToast(_isRegisterMode ? loc.registerSuccess : loc.loginSuccess);
        context.pop(true);
      } else {
        _showToast(_isRegisterMode ? loc.registerFailed : loc.loginFailed,
            isError: true);
      }
    } on ApiStatusException catch (e) {
      if (!mounted) return;
      _showToast(_errorMessage(e, loc), isError: true);
    } catch (e) {
      if (!mounted) return;
      _showToast(_isRegisterMode ? loc.registerFailed : loc.loginFailed,
          isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errorMessage(ApiStatusException e, S loc) {
    switch (e.status.getReason) {
      case 'USERNAME_TAKEN':
        return loc.errorUsernameTaken;
      case 'INVALID_PASSWORD':
      case 'USER_NOT_FOUND':
        return loc.loginFailed;
      default:
        return localizedApiErrorMessage(loc, e.status);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _toggleMode() {
    setState(() => _isRegisterMode = !_isRegisterMode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveUtils.isMobile(context);
    final loc = S.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // 返回按钮
            Positioned(
              top: isMobile ? 8 : 16,
              left: isMobile ? 8 : 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => context.pop(),
                tooltip: loc.backToHome,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.onSurface.withAlpha(15),
                ),
              ),
            ),

            // 主内容：居中卡片
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24.w : 48,
                  vertical: isMobile ? 32.h : 48,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 420,
                  ),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(isMobile ? 20.r : 24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.06 * 255).round()),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 28.w : 40,
                      vertical: isMobile ? 32.h : 48,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          Container(
                            width: isMobile ? 64.w : 72,
                            height: isMobile ? 64.w : 72,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                isMobile ? 18.r : 20,
                              ),
                            ),
                            child: Icon(
                              Icons.movie_filter_outlined,
                              size: isMobile ? 32.sp : 36,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: isMobile ? 20.h : 24),
                          Text(
                            loc.appName,
                            style: TextStyle(
                              fontSize: isMobile ? 22.sp : 24,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: isMobile ? 4.h : 6),
                          Text(
                            _isRegisterMode
                                ? loc.registerTitle
                                : loc.loginForMore,
                            style: TextStyle(
                              fontSize: isMobile ? 13.sp : 14,
                              color:
                                  theme.colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                          SizedBox(height: isMobile ? 32.h : 40),

                          // Username
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: loc.username,
                              hintText: loc.usernameHint,
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isMobile ? 12.r : 14,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return loc.usernameHint;
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: isMobile ? 16.h : 18),

                          // Nickname（注册模式）
                          if (_isRegisterMode) ...[
                            TextFormField(
                              controller: _nicknameController,
                              decoration: InputDecoration(
                                labelText: loc.nicknameLabel,
                                hintText: loc.nicknameHint,
                                prefixIcon:
                                    const Icon(Icons.face_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    isMobile ? 12.r : 14,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return loc.nicknameHint;
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: isMobile ? 16.h : 18),
                          ],

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: loc.password,
                              hintText: loc.passwordHint,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isMobile ? 12.r : 14,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return loc.passwordHint;
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _handleSubmit(),
                          ),
                          SizedBox(height: isMobile ? 28.h : 32),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: isMobile ? 48.h : 50,
                            child: FilledButton(
                              onPressed: _submitting ? null : _handleSubmit,
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    isMobile ? 12.r : 14,
                                  ),
                                ),
                              ),
                              child: Text(
                                _submitting
                                    ? loc.loading
                                    : (_isRegisterMode
                                        ? loc.register
                                        : loc.loginButton),
                                style: TextStyle(
                                  fontSize: isMobile ? 16.sp : 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),

                          // 切换登录/注册
                          TextButton(
                            onPressed: _toggleMode,
                            child: Text(
                              _isRegisterMode ? loc.toLogin : loc.toRegister,
                              style: TextStyle(fontSize: 13.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
