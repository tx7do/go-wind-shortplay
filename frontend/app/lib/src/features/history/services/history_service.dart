import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 观看历史条目（视频 + 最近观看时间）
class HistoryEntry {
  final Video video;
  final DateTime? watchedAt;

  const HistoryEntry({required this.video, this.watchedAt});
}

/// 观看历史服务（本人视角，最近观看倒序；派生自播放事件）
class HistoryService extends BaseService {
  HistoryService() : super(tag: 'HistoryService');

  Dio get _dio => GetIt.instance<Dio>();

  Future<PageData<HistoryEntry>> history({required PaginationQuery paging}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/watch-history',
        queryParameters: paging.toQueryMap(),
      );
      final body = res.data ?? const {};
      final items = (body['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => HistoryEntry(
                video: Video.fromJson(
                  (item['video'] as Map<String, dynamic>?) ?? const {},
                ),
                watchedAt: parseTime(item['watchedAt']),
              ))
          .toList();
      return PageData.inferHasMore(
        items: items,
        total: jsonInt(body['total'], fallback: items.length),
        pageNum: paging.pageNum,
        pageSize: paging.pageSize,
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
