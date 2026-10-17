import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth_cubit.dart';
import '../../models/user.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

/// 编辑资料页（PUT /profile：昵称 / 简介 / 头像链接）。
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, required this.user});

  final User user;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nicknameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _avatarCtrl;

  bool _busy = false;
  /// 头像预览地址（实时跟随输入）。
  late String _avatarPreview;

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController(text: widget.user.nickname);
    _bioCtrl = TextEditingController(text: widget.user.bio);
    _avatarCtrl = TextEditingController(text: widget.user.avatarUrl);
    _avatarPreview = widget.user.avatarUrl;
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      showToast(context, '昵称不能为空');
      return;
    }
    setState(() => _busy = true);
    try {
      // 服务端返回更新后的完整资料。
      final updated = await Services.user.updateProfile(
        nickname: nickname,
        bio: _bioCtrl.text.trim(),
        avatarUrl: _avatarCtrl.text.trim(),
      );
      // 同步全局登录态与本地缓存。
      if (!mounted) return;
      await context.read<AuthCubit>().updateUser(updated);
      if (!mounted) return;
      showToast(context, '资料已更新');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 头像预览。
            Center(
              child: UserAvatar(
                url: _avatarPreview,
                name: widget.user.displayName,
                radius: 36,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nicknameCtrl,
              maxLength: 20,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '昵称',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioCtrl,
              maxLength: 100,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '简介',
                hintText: '介绍一下自己吧',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _avatarCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '头像链接',
                hintText: '填写图片地址，留空则保持不变',
              ),
              onChanged: (v) => setState(() => _avatarPreview = v.trim()),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
