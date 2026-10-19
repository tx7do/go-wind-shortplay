import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart' show RouteNames;
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 底部视频信息：作者 / 标题 / 简介 / 标签 / 召回原因
class FeedVideoInfo extends StatelessWidget {
  final Video video;
  final String reason;

  /// 作者昵称（feed 列表不回传，由详情接口补充；空则不展示作者行）
  final String authorNickname;

  const FeedVideoInfo({
    super.key,
    required this.video,
    this.reason = FeedReason.latest,
    this.authorNickname = '',
  });

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 作者行
        if (authorNickname.isNotEmpty)
          GestureDetector(
            onTap: video.authorId > 0
                ? () => context.pushNamed(
                      RouteNames.userProfile,
                      pathParameters: {'userId': '${video.authorId}'},
                    )
                : null,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Text(
                '@$authorNickname',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black.withAlpha(120), blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        if (video.title.isNotEmpty)
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.35,
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
                    fontWeight: FontWeight.w700,
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
        if (reason.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(80),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              _reasonLabel(loc),
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.white.withAlpha(210),
              ),
            ),
          ),
        ],
        if (video.status != VideoStatus.published) ...[
          SizedBox(height: 6.h),
          Text(
            _statusLabel(loc, video.status),
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
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
