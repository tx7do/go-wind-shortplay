import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart' show RouteNames;
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/widgets/cover_image.dart';

/// 剧集卡片（我的剧集 / 他人主页剧集 / 搜索剧集结果共用）
///
/// 横向布局：左封面（集数角标）+ 右剧名/更新进度，点击进剧集详情页。
class SeriesListCard extends StatelessWidget {
  final Series series;

  const SeriesListCard({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => context.pushNamed(
        RouteNames.seriesDetail,
        pathParameters: {'seriesId': '${series.id}'},
      ),
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Stack(
              children: [
                CoverImage(
                  url: series.coverDisplayUrl,
                  width: 124.w,
                  height: 82.h,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                Positioned(
                  left: 6.w,
                  bottom: 6.h,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      gradient: BrandColor.gradient,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      loc.seriesEpisodeBadge(series.publishedCount),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    loc.seriesUpdatedTo(series.publishedCount, series.episodeCount),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: theme.colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 22.w,
              color: theme.colorScheme.onSurface.withAlpha(90),
            ),
          ],
        ),
      ),
    );
  }
}
