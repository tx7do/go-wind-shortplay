import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/utilities/logger.dart' show debug;

/// UBA 事件类型（protojson 枚举字符串全名，请求也须传全名）
class UbaEventType {
  UbaEventType._();

  static const videoPlay = 'EVENT_TYPE_VIDEO_PLAY';
  static const videoHeartbeat = 'EVENT_TYPE_VIDEO_HEARTBEAT';
  static const videoComplete = 'EVENT_TYPE_VIDEO_COMPLETE';
  static const videoSwipeAway = 'EVENT_TYPE_VIDEO_SWIPE_AWAY';
  static const videoLike = 'EVENT_TYPE_VIDEO_LIKE';
  static const videoCollect = 'EVENT_TYPE_VIDEO_COLLECT';
  static const commentCreate = 'EVENT_TYPE_COMMENT_CREATE';
  static const followAuthor = 'EVENT_TYPE_FOLLOW_AUTHOR';
}

/// 单条行为事件
class UbaEvent {
  /// 事件类型（[UbaEventType] 全名）
  final String eventType;

  /// 视频ID（非视频事件为 0）
  final int videoId;

  /// 对方用户ID（关注事件）
  final int targetUserId;

  /// 观看时长（毫秒）
  final int durationMs;

  /// 观看进度百分比 0-100
  final int watchPercent;

  const UbaEvent({
    required this.eventType,
    this.videoId = 0,
    this.targetUserId = 0,
    this.durationMs = 0,
    this.watchPercent = 0,
  });

  Map<String, dynamic> toJson() {
    // protojson：durationMs 为 int64 → 字符串；watchPercent 为 uint32 → 数字
    return {
      'eventType': eventType,
      if (videoId > 0) 'videoId': videoId,
      if (targetUserId > 0) 'targetUserId': targetUserId,
      'durationMs': '$durationMs',
      'watchPercent': watchPercent.clamp(0, 100),
    };
  }
}

/// 用户行为埋点服务
///
/// 尽力而为：失败静默（仅 debug 日志），不阻塞播放体验。
class UbaService extends BaseService {
  UbaService() : super(tag: 'UbaService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 上报单条事件（fire-and-forget）
  void report(UbaEvent event) {
    reportAll([event]);
  }

  /// 批量上报事件（fire-and-forget，失败静默）
  void reportAll(List<UbaEvent> events) {
    if (events.isEmpty) return;
    unawaited(
      _dio
          .post<Object?>(
            '/uba/events',
            data: {
              'events': events.map((e) => e.toJson()).toList(),
            },
          )
          .then((_) {}, onError: (Object e) {
        debug('uba report failed (ignored): $e');
      }),
    );
  }
}
