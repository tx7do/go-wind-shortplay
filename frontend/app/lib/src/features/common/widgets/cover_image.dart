import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:shortplay_app/src/core/utilities/media_url.dart';

/// 通用网络封面图（含圆角、占位与失败占位；入参支持对象键或完整 URL）
class CoverImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const CoverImage({
    super.key,
    required String? url,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) : url = url ?? '';

  /// 由对象键构造（自动经 [MediaUrl.resolve] 拼接媒体网关前缀）
  factory CoverImage.fromKey(
    String? key, {
    double? width,
    double? height,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) {
    return CoverImage(
      url: MediaUrl.resolve(key),
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: url.isEmpty
            ? _placeholder(theme)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => _placeholder(theme),
                errorWidget: (_, _, _) => _placeholder(theme),
              ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.movie_outlined,
        size: 24,
        color: theme.colorScheme.outline,
      ),
    );
  }
}
