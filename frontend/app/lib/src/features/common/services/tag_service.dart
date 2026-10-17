import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 标签服务：标签列表（发布选择 / 搜索联想）
class TagService extends BaseService {
  TagService() : super(tag: 'TagService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 标签列表（`page/pageSize` 分页形态）
  Future<PageData<VideoTag>> list(PaginationQuery query) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/tags',
        queryParameters: query.toPageMap(),
      );
      final data = res.data ?? const {};
      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VideoTag.fromJson)
          .toList();
      return PageData(
        items: items,
        total: jsonInt(data['total'], fallback: items.length),
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
