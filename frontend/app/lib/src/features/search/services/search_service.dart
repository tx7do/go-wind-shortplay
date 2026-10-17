import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 搜索服务：关键词搜索（标题模糊 + 标签精确）/ 标签聚合
class SearchService extends BaseService {
  SearchService() : super(tag: 'SearchService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 关键词搜索（游客可访问，`pageNum` 分页形态）
  ///
  /// 实测响应条目为 `{video, reason}` 包裹形态（与 feed 一致），需解包。
  Future<PageData<Video>> search({
    required String keyword,
    required PaginationQuery query,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/search/videos',
        queryParameters: {
          'keyword': keyword,
          'pageNum': query.pageNum,
          'pageSize': query.pageSize,
        },
      );
      return _toPage(res.data, query);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 标签聚合（`GET /tags/{tag}/videos?pageNum=`）
  Future<PageData<Video>> byTag({
    required String tag,
    required PaginationQuery query,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/tags/$tag/videos',
        queryParameters: query.toQueryMap(),
      );
      return _toPage(res.data, query);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  PageData<Video> _toPage(Map<String, dynamic>? data, PaginationQuery query) {
    final body = data ?? const {};
    final items = (body['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => Video.fromJson(
              (item['video'] as Map<String, dynamic>?) ?? item,
            ))
        .toList();
    return PageData.inferHasMore(
      items: items,
      total: jsonInt(body['total'], fallback: items.length),
      pageNum: query.pageNum,
      pageSize: query.pageSize,
    );
  }
}
