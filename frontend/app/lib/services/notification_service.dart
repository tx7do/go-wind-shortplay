import '../core/network/api_client.dart';
import '../models/common.dart';
import '../models/notification.dart';

/// 通知列表结果：分页 + 未读数。
class NotificationListResult {
  const NotificationListResult({
    required this.page,
    this.unreadCount = 0,
  });

  final PageData<AppNotification> page;
  final int unreadCount;
}

/// 站内通知。
class NotificationService {
  NotificationService(this._api);

  final ApiClient _api;

  static const int _pageSize = 20;

  /// 通知列表（响应中带回 unreadCount，供角标使用）。
  Future<NotificationListResult> list({
    required int pageNum,
    bool unreadOnly = false,
  }) async {
    final data = await _api.getJson(
      '/notifications',
      query: {
        'unreadOnly': unreadOnly,
        'pageNum': pageNum,
        'pageSize': _pageSize,
      },
    );
    final page = PageData.parse(
      data,
      parseItem: AppNotification.fromJson,
      pageNum: pageNum,
      pageSize: _pageSize,
    );
    return NotificationListResult(
      page: page,
      unreadCount: asInt(data['unreadCount'] ?? data['unread_count']),
    );
  }

  /// 未读数（GET /notifications/unread-count）。
  ///
  /// 该接口响应字段名文档未明确，兼容 count / unreadCount / unread_count。
  Future<int> unreadCount() async {
    final data = await _api.getJson('/notifications/unread-count');
    return asInt(
      data['count'] ?? data['unreadCount'] ?? data['unread_count'],
    );
  }

  /// 标记已读。
  Future<void> markRead(List<int> ids) =>
      _api.putJson('/notifications/read', data: {'ids': ids});

  /// 全部已读。
  Future<void> markAllRead() => _api.putJson('/notifications/read-all');
}
