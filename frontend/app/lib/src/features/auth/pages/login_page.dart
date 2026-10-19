import 'package:cached_query/cached_query.dart' show MutationSuccess;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utils/responsive_utils.dart';
import 'package:shortplay_app/src/core/widgets/brand_logo.dart';
import 'package:shortplay_app/src/core/widgets/gradient_button.dart';
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
    if (_isRegisterMode) return;
    _nicknameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveUtils.isMobile(context);
    final loc = S.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // 品牌渐变 hero：大圆弧底 + 装饰光斑
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _BrandHero(
              height: isMobile ? 300.h : 320,
              appName: loc.appName,
              slogan: _isRegisterMode ? loc.registerTitle : loc.loginForMore,
            ),
          ),
          // 返回按钮（浮在 hero 上）
          Positioned(
            top: isMobile ? 8 : 16,
            left: isMobile ? 8 : 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => context.pop(),
              tooltip: loc.backToHome,
              color: Colors.white,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(40),
              ),
            ),
          ),
          // 表单卡（压住 hero 底部）
          Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(top: isMobile ? 248.h : 264),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 460,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(isMobile ? 28.r : 32),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 26.w : 48,
                  vertical: isMobile ? 30.h : 40,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRegisterMode ? loc.registerTitle : loc.loginButton,
                        style: TextStyle(
                          fontSize: isMobile ? 22.sp : 24,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: isMobile ? 22.h : 28),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: loc.usernameHint,
                          labelText: loc.username,
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            size: 20,
                          ),
                          prefixIconColor:
                              WidgetStateColor.resolveWith((states) {
                            return states.contains(WidgetState.focused)
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withAlpha(120);
                          }),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return loc.usernameHint;
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: isMobile ? 14.h : 16),
                      if (_isRegisterMode) ...[
                        TextFormField(
                          controller: _nicknameController,
                          decoration: InputDecoration(
                            hintText: loc.nicknameHint,
                            labelText: loc.nicknameLabel,
                            prefixIcon:
                                const Icon(Icons.face_outlined, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return loc.nicknameHint;
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isMobile ? 14.h : 16),
                      ],
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: loc.passwordHint,
                          labelText: loc.password,
                          prefixIcon:
                              const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
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
                      SizedBox(height: isMobile ? 26.h : 32),
                      // 主 CTA：品牌渐变
                      GradientButton(
                        label: _submitting
                            ? loc.loading
                            : (_isRegisterMode ? loc.register : loc.loginButton),
                        icon: null,
                        onPressed: _submitting ? null : _handleSubmit,
                        height: 48,
                        fontSize: 16,
                        radius: isMobile ? 16.r : 18,
                        width: double.infinity,
                      ),
                      SizedBox(height: 14.h),
                      // 切换登录/注册
                      Center(
                        child: TextButton(
                          onPressed: _toggleMode,
                          child: Text(
                            _isRegisterMode ? loc.toLogin : loc.toRegister,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // 底部留白（小屏表单不被键盘顶死）
                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部品牌区：渐变底 + 品牌标 + 应用名 + 欢迎语
class _BrandHero extends StatelessWidget {
  final double height;
  final String appName;
  final String slogan;

  const _BrandHero({
    required this.height,
    required this.appName,
    required this.slogan,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 渐变底
          const DecoratedBox(
            decoration: BoxDecoration(gradient: BrandColor.gradient),
          ),
          // 装饰光斑
          Positioned(
            right: -60,
            top: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(26),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: 30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(20),
              ),
            ),
          ),
          // 内容
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 28.w : 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: isMobile ? 56.h : 64),
                  BrandLogoMark(
                    size: isMobile ? 60.w : 68,
                    borderRadius: BorderRadius.circular(isMobile ? 18.r : 20),
                  ),
                  SizedBox(height: isMobile ? 16.h : 20),
                  Text(
                    appName,
                    style: TextStyle(
                      fontSize: isMobile ? 26.sp : 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: isMobile ? 6.h : 8),
                  Text(
                    slogan,
                    style: TextStyle(
                      fontSize: isMobile ? 13.sp : 14,
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
