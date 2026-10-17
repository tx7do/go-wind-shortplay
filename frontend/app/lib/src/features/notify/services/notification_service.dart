import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/notify/models/notification.dart';

/// 通知服务：列表 / 已读 / 未读数
class NotificationService extends BaseService {
  NotificationService() : super(tag: 'NotificationService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 通知列表（需登录）
  /// `GET /notifications?unreadOnly=&pageNum=` → {items, total, unreadCount}
  Future<({List<NotificationItem> items, int total, int unreadCount})> list({
    required PaginationQuery query,
    bool unreadOnly = false,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/notifications',
        queryParameters: {
          ...query.toQueryMap(),
          'unreadOnly': unreadOnly,
        },
      );
      final data = res.data ?? const {};
      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(NotificationItem.fromJson)
          .toList();
      return (
        items: items,
        total: jsonInt(data['total'], fallback: items.length),
        unreadCount: jsonInt(data['unreadCount']),
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 标记已读
  Future<void> markRead(List<int> ids) async {
    try {
      await _dio.put<Object?>(
        '/notifications/read',
        data: {'ids': ids},
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 全部已读
  Future<void> markAllRead() async {
    try {
      await _dio.put<Object?>('/notifications/read-all', data: const {});
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 未读数
  ///
  /// 注意：实测后端该端点返回 `{"count":"0"}`（int64 字符串），
  /// 与 API.md 文档写的 `unreadCount` 键名不一致，两种键名都兼容。
  Future<int> unreadCount() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/notifications/unread-count');
      final data = res.data ?? const {};
      return jsonInt(data['count'] ?? data['unreadCount']);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
