import '../core/network/api_client.dart';

/// UBA 埋点事件类型（对应后端 eventType 枚举）。
enum UbaEventType {
  /// 1 播放。
  play(1),

  /// 2 心跳（暂未使用）。
  heartbeat(2),

  /// 3 完播。
  complete(3),

  /// 4 划走。
  swipeAway(4),

  /// 5 点赞。
  like(5),

  /// 6 收藏。
  collect(6),

  /// 7 评论。
  comment(7),

  /// 8 关注。
  follow(8);

  const UbaEventType(this.value);
  final int value;
}

/// UBA 埋点事件。
class UbaEvent {
  UbaEvent({
    required this.eventType,
    required this.videoId,
    this.durationMs,
    this.watchPercent,
  });

  final UbaEventType eventType;
  final int videoId;

  /// 观看时长（毫秒），划走/完播时上报。
  final int? durationMs;

  /// 观看进度（0~1），划走/完播时上报。
  final double? watchPercent;

  Map<String, dynamic> toJson() => {
        'eventType': eventType.value,
        'videoId': videoId,
        if (durationMs != null) 'durationMs': durationMs,
        if (watchPercent != null) 'watchPercent': watchPercent,
      };
}

/// UBA 埋点上报（游客也可上报）。
///
/// 埋点属于“尽力而为”：任何失败都静默吞掉，绝不影响主流程。
class UbaService {
  UbaService(this._api);

  final ApiClient _api;

  /// 上报单个事件（静默失败）。
  Future<void> report(UbaEvent event) => reportAll([event]);

  /// 批量上报事件（静默失败）。
  Future<void> reportAll(List<UbaEvent> events) async {
    if (events.isEmpty) return;
    try {
      await _api.postJson(
        '/uba/events',
        data: {'events': events.map((e) => e.toJson()).toList()},
      );
    } catch (_) {
      // 埋点失败必须静默。
    }
  }
}
