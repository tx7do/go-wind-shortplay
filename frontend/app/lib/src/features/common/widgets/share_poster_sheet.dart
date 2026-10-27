import 'dart:typed_data' show ByteData, Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart' as share;

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/config/environments.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/utilities/logger.dart' show debug;
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/widgets/cover_image.dart';

/// 分享面板：复制链接 / 生成分享海报（封面 + 标题 + 二维码）并调起系统分享
Future<void> showShareSheet(BuildContext context, Video video) {
  final loc = S.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc.share,
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 14.h),
              _PosterCard(video: video),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final link =
                            '${Environments.shareBaseUrl}/s/${video.id}';
                        share.SharePlus.instance.share(
                          share.ShareParams(text: link),
                        );
                      },
                      icon: const Icon(Icons.link_rounded),
                      label: Text(loc.copyLink),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _sharePoster(sheetContext, video),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(loc.sharePoster),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _sharePoster(BuildContext sheetContext, Video video) async {
  final Object? boundary = _posterKey.currentState;
  if (boundary is! RenderRepaintBoundary) return;
  try {
    final ui.Image image = await boundary.toImage(pixelRatio: 3);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (bytes == null) return;
    final Uint8List png = bytes.buffer.asUint8List();
    await share.SharePlus.instance.share(
      share.ShareParams(
        files: <share.XFile>[
          share.XFile.fromData(
            png,
            mimeType: 'image/png',
            name: 'fengyin-share-${video.id}.png',
          ),
        ],
        text: video.title,
      ),
    );
  } catch (e) {
    debug('share poster failed (ignored): $e');
  }
}

/// 海报截图锚点（全局唯一，同屏只有一张海报）
final GlobalKey _posterKey = GlobalKey();

/// 海报卡片：品牌渐变底 + 封面 + 标题 + 二维码（RepaintBoundary 可截图）
class _PosterCard extends StatefulWidget {
  final Video video;

  const _PosterCard({required this.video});

  @override
  State<_PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<_PosterCard> {
  Future<void>? _precache;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache ??= widget.video.coverDisplayUrl.isEmpty
        ? Future<void>.value()
        : precacheImage(
            NetworkImage(widget.video.coverDisplayUrl),
            context,
          ).then((_) {
            if (mounted) setState(() {});
          });
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final video = widget.video;

    return RepaintBoundary(
      key: _posterKey,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          gradient: BrandColor.gradient,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: SizedBox(
                width: double.infinity,
                height: 150.h,
                child: video.coverDisplayUrl.isEmpty
                    ? const ColoredBox(color: Colors.black26)
                    : CoverImage(
                        url: video.coverDisplayUrl,
                        borderRadius: BorderRadius.zero,
                      ),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.appName,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: QrImageView(
                    data: '${Environments.shareBaseUrl}/s/${video.id}',
                    size: 56.sp,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
