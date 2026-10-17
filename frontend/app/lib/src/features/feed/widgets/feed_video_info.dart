import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart' show RouteNames;
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 底部视频信息：标题 / 简介 / 标签 / 召回原因
class FeedVideoInfo extends StatelessWidget {
  final Video video;
  final String reason;

  const FeedVideoInfo({
    super.key,
    required this.video,
    this.reason = FeedReason.latest,
  });

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 作者名
        if (video.title.isNotEmpty)
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.black.withAlpha(120), blurRadius: 6),
              ],
            ),
          ),
        if (video.description.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Text(
            video.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withAlpha(230),
              shadows: [
                Shadow(color: Colors.black.withAlpha(120), blurRadius: 6),
              ],
            ),
          ),
        ],
        // 标签
        if (video.tags.isNotEmpty) ...[
          SizedBox(height: 6.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 4.h,
            children: video.tags.map((tag) {
              return GestureDetector(
                onTap: () => context.pushNamed(
                  RouteNames.search,
                  queryParameters: {'keyword': '#$tag'},
                ),
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black.withAlpha(120), blurRadius: 6),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        // 召回原因角标
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(70),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text(
            _reasonLabel(loc),
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.white.withAlpha(210),
            ),
          ),
        ),
        if (video.status != VideoStatus.published) ...[
          SizedBox(height: 6.h),
          Text(
            _statusLabel(loc, video.status),
            style: TextStyle(
              fontSize: 11.sp,
              color: theme.colorScheme.tertiary,
            ),
          ),
          if (video.status == VideoStatus.rejected &&
              video.rejectReason.isNotEmpty)
            Text(
              '${loc.rejectReasonLabel}: ${video.rejectReason}',
              style: TextStyle(
                fontSize: 11.sp,
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ],
    );
  }

  String _reasonLabel(S loc) {
    switch (reason) {
      case FeedReason.follow:
        return loc.reasonFollow;
      case FeedReason.hot:
        return loc.reasonHot;
      default:
        return loc.reasonLatest;
    }
  }

  String _statusLabel(S loc, String status) {
    switch (status) {
      case VideoStatus.draft:
        return loc.statusDraft;
      case VideoStatus.reviewing:
        return loc.statusReviewing;
      case VideoStatus.rejected:
        return loc.statusRejected;
      case VideoStatus.offline:
        return loc.statusOffline;
      default:
        return '';
    }
  }
}
