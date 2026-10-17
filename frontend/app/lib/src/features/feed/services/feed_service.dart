import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// Feed 服务：沉浸式推荐流（游客可访问）
class FeedService extends BaseService {
  FeedService() : super(tag: 'FeedService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 推荐流（登录态自动已看去重）
  /// `GET /feed?tag=&pageNum=&pageSize=` → {items:[{video, reason}], hasMore}
  Future<PageData<FeedItem>> feed({
    required PaginationQuery query,
    String? tag,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/feed',
        queryParameters: {
          ...query.toQueryMap(),
          if (tag != null && tag.isNotEmpty) 'tag': tag,
        },
      );
      final data = res.data ?? const {};
      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FeedItem.fromJson)
          .toList();
      return PageData(
        items: items,
        hasMore: data['hasMore'] == true,
        total: items.length,
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
