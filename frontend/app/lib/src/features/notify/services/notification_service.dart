import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/notify/models/notification.dart';

/// 站内信通知服务（基座 internal_message 域收件箱的 app BFF 新端点）
///
/// 端点（均需登录）：
/// - `POST /notifications/list`        {page, pageSize, unreadOnly} → {items, total}
/// - `GET  /notifications/unread-count`                            → {count}
/// - `POST /notifications/read`        {recipientIds: [id]}        → {}
/// - `POST /notifications/read-all`    {}                          → {}
class NotificationService extends BaseService {
  NotificationService() : super(tag: 'NotificationService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 通知列表（当前用户收件箱）
  Future<({List<NotificationItem> items, int total})> list({
    int page = 1,
    int pageSize = 10,
    bool unreadOnly = false,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/notifications/list',
        data: {
          'page': page,
          'pageSize': pageSize,
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
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 标记已读（收件记录 ID 列表）
  Future<void> markRead(List<int> ids) async {
    try {
      await _dio.post<Object?>(
        '/notifications/read',
        data: {'recipientIds': ids},
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 全部已读
  Future<void> markAllRead() async {
    try {
      await _dio.post<Object?>('/notifications/read-all', data: const {});
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 未读数
  Future<int> unreadCount() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/notifications/unread-count');
      final data = res.data ?? const {};
      return jsonInt(data['count']);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
