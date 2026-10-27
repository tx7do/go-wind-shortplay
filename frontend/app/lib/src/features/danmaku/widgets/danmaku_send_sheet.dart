import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart' show Player;

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart'
    show ApiStatusException, localizedErrorText;
import 'package:shortplay_app/src/features/danmaku/services/danmaku_service.dart';

/// 弹幕发送面板：当前播放位置快照 + 内容输入（≤100 字）。
/// 发送成功回调 [onSent]（宿主把新弹幕注入时间轴即时上屏）。
Future<void> showDanmakuSendSheet(
  BuildContext context, {
  required Player player,
  required int videoId,
  required ValueChanged<DanmakuItem> onSent,
}) {
  final controller = TextEditingController();
  final loc = S.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.danmakuSendTitle,
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: loc.danmakuSendHint,
                counterText: '',
              ),
            ),
            SizedBox(height: 14.h),
            FilledButton.icon(
              onPressed: () async {
                final content = controller.text.trim();
                if (content.isEmpty) return;
                final offsetMs = player.state.position.inMilliseconds;
                final navigator = Navigator.of(sheetContext);
                final loc = S.of(sheetContext);
                try {
                  final item = await DanmakuService().send(
                    videoId: videoId,
                    content: content,
                    timeOffsetMs: offsetMs,
                  );
                  navigator.pop();
                  onSent(item);
                } on ApiStatusException catch (e) {
                  EasyLoading.showToast(localizedErrorText(loc, e));
                } catch (_) {
                  EasyLoading.showToast(loc.errorOccurred);
                }
              },
              icon: const Icon(Icons.send_rounded),
              label: Text(loc.danmakuSendAction),
            ),
          ],
        ),
      );
    },
  );
}
