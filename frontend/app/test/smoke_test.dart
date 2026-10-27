import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/status.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/comment/models/comment.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/services/sysconf_service.dart';
import 'package:shortplay_app/src/features/danmaku/services/danmaku_service.dart';
import 'package:shortplay_app/src/features/history/services/history_service.dart';
import 'package:shortplay_app/src/features/video_detail/services/video_service.dart'
    show VideoDetail;

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
        'viewerState': {
          'liked': false,
          'collected': true,
          'following': false,
          'resumePositionMs': '12345',
        },
      });

      expect(video.id, 1);
      expect(video.title, 'Smoke Test Video');
      expect(video.duration, 15);
      expect(video.status, VideoStatus.published);
      expect(video.likeCount, 1); // int64 字符串已转 int
      expect(video.commentCount, 2);
      expect(video.liked, isFalse);
      expect(video.collected, isTrue);
      expect(video.resumePositionMs, 12345); // int64 字符串形态的续播位置
    });

    test('VideoDetail.fromJson 合并平级 viewerState（互动态 + 续播位置）', () {
      // wire 上 viewerState 与 video 平级（protojson），解析须合并
      final detail = VideoDetail.fromJson({
        'video': {
          'id': 7,
          'title': 'Detail Video',
          'status': 'VIDEO_STATUS_PUBLISHED',
          'duration': 60,
        },
        'viewerState': {
          'liked': true,
          'collected': false,
          'following': true,
          'resumePositionMs': '30000',
        },
      });
      expect(detail.video.id, 7);
      expect(detail.video.liked, isTrue);
      expect(detail.video.followingAuthor, isTrue);
      expect(detail.video.resumePositionMs, 30000);
    });

    test('Series/SeriesDetail 解析追剧字段', () {
      final detail = SeriesDetail.fromJson({
        'series': {
          'id': '3',
          'title': 'Test Series',
          'episodeCount': '12',
          'publishedCount': '5',
          'followerCount': '42',
        },
        'items': [],
        'viewerFollowing': true,
      });
      expect(detail.series!.id, 3);
      expect(detail.series!.followerCount, 42);
      expect(detail.viewerFollowing, isTrue);
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

    test('DanmakuItem/Comment.pinned/SysConf 解析新字段', () {
      final d = DanmakuItem.fromJson({
        'id': '9',
        'userId': 3,
        'content': 'hello',
        'timeOffsetMs': '12345',
      });
      expect(d.id, 9);
      expect(d.timeOffsetMs, 12345);
      expect(d.content, 'hello');

      final c = Comment.fromJson({
        'id': 1,
        'videoId': 2,
        'content': 'nice',
        'likeCount': '5',
        'pinned': true,
      });
      expect(c.pinned, isTrue);
      expect(c.copyWith(pinned: false).pinned, isFalse);

      const conf = SysConf(
        announcementEnabled: true,
        announcementText: 'hi',
        danmakuEnabled: false,
      );
      expect(conf.danmakuEnabled, isFalse);
      // 缺省开（JSON 缺字段不关弹幕）
      expect(SysConf.fromJson(const {}).danmakuEnabled, isTrue);
    });

    test('HistoryEntry 进度判定', () {
      final video = const Video(id: 1, duration: 100);
      // 有效进度：>5s 且未接近片尾
      expect(HistoryEntry(video: video, progressSeconds: 40).resumable, isTrue);
      // 片尾 5s 内不续播
      expect(
        HistoryEntry(video: video, progressSeconds: 98).resumable,
        isFalse,
      );
      // 未记录 / 开头几秒不续播
      expect(HistoryEntry(video: video, progressSeconds: 0).resumable, isFalse);
      expect(HistoryEntry(video: video, progressSeconds: 3).resumable, isFalse);
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
                children: [Text(loc.appName), Text(loc.commentsCount(3))],
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
          home: Builder(builder: (context) => Text(S.of(context).appName)),
        ),
      );
      expect(find.text('Fengyin ShortPlay'), findsOneWidget);
    });
  });
}
