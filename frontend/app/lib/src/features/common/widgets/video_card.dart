import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/src/app_router/app_router.dart' show RouteNames;
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/utilities/number_format.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/widgets/cover_image.dart';

/// 视频卡片（搜索结果 / 作品 / 收藏列表共用）
///
/// 横向布局：左封面（时长角标）+ 右标题/数据，点击进单视频沉浸详情页。
class VideoListCard extends StatelessWidget {
  final Video video;

  /// 额外角标（如「审核中」「未通过」）
  final String? badgeLabel;
  final Color? badgeColor;

  const VideoListCard({
    super.key,
    required this.video,
    this.badgeLabel,
    this.badgeColor,
  });

  String get _durationLabel {
    final totalSeconds = video.duration;
    if (totalSeconds <= 0) return '';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _durationLabel;

    return InkWell(
      onTap: () => context.pushNamed(
        RouteNames.videoDetail,
        pathParameters: {'videoId': '${video.id}'},
      ),
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CoverImage(
                  url: video.coverDisplayUrl,
                  width: 124.w,
                  height: 82.h,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                if (duration.isNotEmpty)
                  Positioned(
                    right: 6.w,
                    bottom: 6.h,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 6.w, vertical: 1.5.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        duration,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: SizedBox(
                height: 82.h,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title.isEmpty ? 'Video #${video.id}' : video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 13.sp,
                          color: theme.colorScheme.onSurface.withAlpha(120),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          NumberFormatUtils.formatCount(video.likeCount),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: theme.colorScheme.onSurface.withAlpha(130),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 13.sp,
                          color: theme.colorScheme.onSurface.withAlpha(120),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          NumberFormatUtils.formatCount(video.commentCount),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: theme.colorScheme.onSurface.withAlpha(130),
                          ),
                        ),
                        if (badgeLabel != null) ...[
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 7.w, vertical: 2.5.h),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? theme.colorScheme.tertiary)
                                  .withAlpha(30),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              badgeLabel!,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color:
                                    badgeColor ?? theme.colorScheme.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片状态角标标准色（作品列表用）
class VideoBadgeColors {
  VideoBadgeColors._();

  static const Color reviewing = BrandColor.violet;
  static const Color rejected = Color(0xFFF53F3F);
  static const Color offline = Color(0xFF9B9BA8);
  static const Color draft = Color(0xFFFFB43A);
}
