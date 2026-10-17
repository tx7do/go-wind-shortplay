import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/features/common/widgets/user_avatar.dart';
import 'package:shortplay_app/src/features/profile/services/user_service.dart';
import 'package:get_it/get_it.dart' show GetIt;

/// 编辑资料：昵称 / 头像地址 / 简介（PUT /profile，id 取令牌）
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final UserAuthCache _auth = GetIt.instance<UserAuthCache>();
  final UserService _userService = UserService();

  late final TextEditingController _nicknameController =
      TextEditingController(text: _auth.userNickname);
  late final TextEditingController _avatarController =
      TextEditingController(text: _auth.userAvatarUrl);
  late final TextEditingController _bioController =
      TextEditingController(text: _auth.userBio);

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _avatarController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// 拉取最新资料回填（缓存可能过期）
  Future<void> _loadProfile() async {
    try {
      final profile = await _userService.getUser(_auth.userId);
      if (!mounted) return;
      _nicknameController.text = profile.nickname;
      _avatarController.text = profile.avatarUrl;
      _bioController.text = profile.bio;
      setState(() {});
    } catch (_) {
      // 用缓存兜底
    }
  }

  Future<void> _save() async {
    final loc = S.of(context);
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      EasyLoading.showToast(loc.nicknameHint);
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await _userService.updateProfile(
        nickname: nickname,
        avatarUrl: _avatarController.text.trim(),
        bio: _bioController.text.trim(),
      );
      // 同步本地缓存（顶栏/主页即时生效）
      final cache = Map<String, dynamic>.from(_auth.currentUser ?? const {});
      cache['nickname'] = updated.nickname;
      cache['avatarUrl'] = updated.avatarUrl;
      cache['bio'] = updated.bio;
      await _auth.saveUserInfo(cache);

      if (!mounted) return;
      EasyLoading.showToast(loc.profileSaved);
      Navigator.of(context).pop(updated);
    } on ApiStatusException catch (e) {
      EasyLoading.showToast(e.status.message ?? loc.errorDefault);
    } catch (_) {
      EasyLoading.showToast(loc.errorDefault);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.editProfile),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              loc.saveProfile,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像预览
            Center(
              child: Column(
                children: [
                  UserAvatar(
                    avatarUrl: _avatarController.text.trim(),
                    nickname: _nicknameController.text.trim(),
                    radius: 40.r,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    loc.avatarLabel,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: theme.colorScheme.onSurface.withAlpha(130),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            _buildLabel(theme, loc.avatarLabel),
            TextField(
              controller: _avatarController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: 'https://…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                isDense: true,
              ),
            ),
            SizedBox(height: 14.h),
            _buildLabel(theme, loc.nicknameLabel),
            TextField(
              controller: _nicknameController,
              maxLength: 20,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: loc.nicknameHint,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                isDense: true,
              ),
            ),
            SizedBox(height: 14.h),
            _buildLabel(theme, loc.bioLabel),
            TextField(
              controller: _bioController,
              maxLength: 100,
              maxLines: 3,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: loc.bioHint,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(ThemeData theme, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withAlpha(180),
        ),
      ),
    );
  }
}
