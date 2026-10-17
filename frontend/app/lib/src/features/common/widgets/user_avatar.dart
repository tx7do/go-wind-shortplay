import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:shortplay_app/src/features/common/data/models.dart';

/// 圆形用户头像（支持对象键 / 完整 URL，空地址回退首字占位）
class UserAvatar extends StatelessWidget {
  final String avatarUrl;
  final String nickname;
  final double radius;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    this.nickname = '',
    this.radius = 20,
  });

  factory UserAvatar.fromBrief(UserBrief? brief, {double radius = 20}) {
    return UserAvatar(
      avatarUrl: brief?.avatarDisplayUrl ?? '',
      nickname: brief?.nickname ?? '',
      radius: radius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUrl = avatarUrl.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      backgroundImage: hasUrl ? CachedNetworkImageProvider(avatarUrl) : null,
      child: hasUrl
          ? null
          : Text(
              nickname.isNotEmpty ? nickname.characters.first : '?',
              style: TextStyle(
                fontSize: radius * 0.9,
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
