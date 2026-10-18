import 'package:flutter_test/flutter_test.dart';

import 'package:shortplay_app/src/features/notify/models/notification.dart';

void main() {
  group('parseSpBizMarker（sp-biz 机器可读尾标记，与 core report_service 约定对齐）', () {
    test('视频举报通知：剔除标记行并解析 videoId', () {
      final (display, videoId) = parseSpBizMarker(
        '工单 #3：目标类型=REPORT_TARGET_TYPE_VIDEO，目标ID=1，原因=涉黄\n'
        'sp-biz:{"videoId":1}',
      );
      expect(
        display,
        '工单 #3：目标类型=REPORT_TARGET_TYPE_VIDEO，目标ID=1，原因=涉黄',
      );
      expect(videoId, 1);
    });

    test('无标记的普通通知：原样返回，videoId 为 null（向后兼容）', () {
      final (display, videoId) = parseSpBizMarker('系统维护公告');
      expect(display, '系统维护公告');
      expect(videoId, isNull);
    });

    test('videoId 非正数：视为无跳转目标', () {
      final (display, videoId) = parseSpBizMarker('正文\nsp-biz:{"videoId":0}');
      expect(display, '正文');
      expect(videoId, isNull);
    });

    test('标记载荷非合法 JSON：按无标记兜底，全量文案照显', () {
      final raw = '正文\nsp-biz:{not-json';
      final (display, videoId) = parseSpBizMarker(raw);
      expect(display, raw);
      expect(videoId, isNull);
    });

    test('标记载荷非对象：按无标记兜底', () {
      final raw = '正文\nsp-biz:"videoId"';
      final (display, videoId) = parseSpBizMarker(raw);
      expect(display, raw);
      expect(videoId, isNull);
    });
  });

  group('NotificationItem.fromJson（sp-biz 尾标记集成）', () {
    test('带视频标记的通知：videoId 已解析、文案已剔除标记行', () {
      final item = NotificationItem.fromJson({
        'id': 7,
        'messageId': 3,
        'status': 'SENT',
        'title': '新举报工单待处理',
        'content': '工单 #3：目标类型=REPORT_TARGET_TYPE_VIDEO，目标ID=1，原因=涉黄\n'
            'sp-biz:{"videoId":1}',
      });
      expect(item.videoId, 1);
      expect(item.content, isNot(contains('sp-biz:')));
      expect(item.isRead, isFalse);
    });

    test('无标记通知：videoId 为 null，正文不变', () {
      final item = NotificationItem.fromJson({
        'id': 8,
        'status': 'READ',
        'title': '公告',
        'content': '普通正文',
      });
      expect(item.videoId, isNull);
      expect(item.content, '普通正文');
      expect(item.isRead, isTrue);
    });

    test('markRead 保留 videoId 与正文', () {
      final item = NotificationItem.fromJson({
        'id': 9,
        'status': 'SENT',
        'title': '新举报工单待处理',
        'content': '工单 #4：原因=侵权\nsp-biz:{"videoId":42}',
      });
      final read = item.markRead();
      expect(read.isRead, isTrue);
      expect(read.videoId, 42);
      expect(read.content, '工单 #4：原因=侵权');
    });
  });
}
