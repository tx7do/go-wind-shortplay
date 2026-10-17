import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/config.dart';
import '../models/video.dart';
import 'common.dart';

/// 九宫格视频封面卡片（我的页 / 他人主页的作品与收藏列表共用）。
class VideoGridTile extends StatelessWidget {
  const VideoGridTile({
    super.key,
    required this.video,
    this.showStatus = false,
    required this.onTap,
  });

  final Video video;

  /// 是否展示状态角标（本人的作品会包含审核中/驳回/下架等状态）。
  final bool showStatus;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = VideoStatus.label(video.status);
    final showBadge = showStatus && !video.isPublished;
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 封面（加载失败显示占位图标）。
                ColoredBox(
                  color: Colors.white.withValues(alpha: 0.06),
                  child: video.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: AppConfig.absolutize(video.coverUrl),
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const Center(
                            child: Icon(
                              Icons.movie_outlined,
                              color: Colors.white24,
                            ),
                          ),
                          placeholder: (_, _) =>
                              const SizedBox.shrink(),
                        )
                      : const Center(
                          child: Icon(
                            Icons.movie_outlined,
                            color: Colors.white24,
                          ),
                        ),
                ),
                // 左下播放量。
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        formatCount(video.viewCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // 状态角标（仅本人非已发布作品）。
                if (showBadge)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: video.status == VideoStatus.rejected ||
                                  video.status == VideoStatus.removed
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFFFFC53D),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (video.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Text(
                video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
