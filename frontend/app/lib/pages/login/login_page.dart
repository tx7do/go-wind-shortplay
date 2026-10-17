import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth_cubit.dart';
import '../../widgets/common.dart';

/// 登录 / 注册页（一页双模式切换）。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  /// 打开登录页，登录成功返回 true。
  static Future<bool> push(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    return result ?? false;
  }

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _registerMode = false;
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthCubit>();
    final ok = _registerMode
        ? await auth.register(
            _usernameCtrl.text.trim(),
            _passwordCtrl.text,
            _nicknameCtrl.text.trim(),
          )
        : await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      showToast(context, _registerMode ? '注册成功，欢迎加入' : '登录成功');
      Navigator.of(context).pop(true);
    } else {
      showToast(context, auth.state.error ?? '操作失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_registerMode ? '注册' : '登录')),
      body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'GoWind 短视频',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '记录灵感，分享此刻',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 36),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入用户名' : null,
                ),
                const SizedBox(height: 16),
                if (_registerMode) ...[
                  TextFormField(
                    controller: _nicknameCtrl,
                    decoration: const InputDecoration(
                      labelText: '昵称',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入昵称' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? '密码至少 6 位' : null,
                ),
                const SizedBox(height: 28),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    return FilledButton(
                      onPressed: state.busy ? null : _submit,
                      child: state.busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_registerMode ? '注册并登录' : '登录'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      setState(() => _registerMode = !_registerMode),
                  child: Text(
                    _registerMode ? '已有账号？去登录' : '没有账号？去注册',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '游客也可以直接返回刷视频，点赞 / 评论 / 发布时再登录',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

/// 需要登录的操作统一入口：未登录时引导登录，返回是否已登录。
Future<bool> ensureLoggedIn(BuildContext context) async {
  if (context.read<AuthCubit>().state.isAuthenticated) return true;
  showToast(context, '请先登录');
  return LoginPage.push(context);
}
