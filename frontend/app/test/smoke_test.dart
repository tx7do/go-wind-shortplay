import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/status.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

void main() {
  group('protojson 序列化约定', () {
    test('jsonInt 兼容 int64 字符串 / uint32 数字 / 空值', () {
      expect(jsonInt('123'), 123); // int64 → 字符串
      expect(jsonInt(456), 456); // uint32 → 数字
      expect(jsonInt(1.0), 1);
      expect(jsonInt(null), 0);
      expect(jsonInt(''), 0);
      expect(jsonInt('not-a-number'), 0);
    });

    test('jsonString 解析枚举全名', () {
      expect(jsonString('VIDEO_STATUS_PUBLISHED'), 'VIDEO_STATUS_PUBLISHED');
      expect(jsonString(null), '');
    });

    test('jsonBool 解析布尔', () {
      expect(jsonBool(true), isTrue);
      expect(jsonBool(false), isFalse);
      expect(jsonBool(null), isFalse);
      expect(jsonBool('true'), isTrue);
    });

    test('Video.fromJson 解析真实详情响应样例', () {
      // 来自后端实测：GET /app/v1/videos/1
      final video = Video.fromJson({
        'id': 1,
        'title': 'Smoke Test Video',
        'description': 'e2e smoke',
        'videoUrl': 'videos/2026/10/xxx.mp4',
        'duration': 15,
        'width': 720,
        'height': 1280,
        'status': 'VIDEO_STATUS_PUBLISHED',
        'authorId': 2,
        'tags': ['test', 'smoke'],
        'likeCount': '1',
        'collectCount': '1',
        'commentCount': '2',
        'viewCount': '1',
        'viewerState': {'liked': false, 'collected': true, 'following': false},
      });

      expect(video.id, 1);
      expect(video.title, 'Smoke Test Video');
      expect(video.duration, 15);
      expect(video.status, VideoStatus.published);
      expect(video.likeCount, 1); // int64 字符串已转 int
      expect(video.commentCount, 2);
      expect(video.liked, isFalse);
      expect(video.collected, isTrue);
    });

    test('FeedItem.fromJson 解析 feed 条目', () {
      final item = FeedItem.fromJson({
        'video': {
          'id': 9,
          'title': 'Feed Video',
          'status': 'VIDEO_STATUS_PUBLISHED',
          'likeCount': '0',
        },
        'reason': 'FEED_REASON_HOT',
      });
      expect(item.video.id, 9);
      expect(item.reason, FeedReason.hot);
    });

    test('Status 解析错误响应 + ApiStatusException', () {
      final status = Status.fromJson({
        'code': 404,
        'reason': 'VIDEO_NOT_FOUND',
        'message': 'video not found',
        'metadata': <String, String>{},
      });
      expect(status.code, 404);
      expect(status.getReason, 'VIDEO_NOT_FOUND');
      expect(status.getMessage, 'video not found');

      final exception = ApiStatusException(status);
      expect(exception.toString(), contains('VIDEO_NOT_FOUND'));
    });

    test('PageData 推断 hasMore', () {
      final page = PageData<int>.inferHasMore(
        items: [1, 2, 3],
        total: 10,
        pageNum: 1,
        pageSize: 3,
      );
      expect(page.hasMore, isTrue);

      final last = PageData<int>.inferHasMore(
        items: [10],
        total: 10,
        pageNum: 4,
        pageSize: 3,
      );
      expect(last.hasMore, isFalse);
    });
  });

  group('l10n 冒烟', () {
    testWidgets('中文字案与占位符渲染', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          locale: const Locale('zh', 'CN'),
          home: Builder(
            builder: (context) {
              final loc = S.of(context);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.appName),
                  Text(loc.commentsCount(3)),
                ],
              );
            },
          ),
        ),
      );
      expect(find.text('风印短剧'), findsOneWidget);
      expect(find.text('3 条评论'), findsOneWidget);
    });

    testWidgets('英文字案回退渲染', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          locale: const Locale('en', 'US'),
          home: Builder(
            builder: (context) => Text(S.of(context).appName),
          ),
        ),
      );
      expect(find.text('Fengyin ShortPlay'), findsOneWidget);
    });
  });
}
