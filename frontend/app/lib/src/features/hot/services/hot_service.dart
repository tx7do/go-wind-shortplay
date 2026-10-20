import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 热榜服务（游客可访问；热度分 = 播放 + 点赞×3 + 收藏×5 + 完播×4）
class HotService extends BaseService {
  HotService() : super(tag: 'HotService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 拉取热榜（一次返回，上限 50）
  Future<List<Video>> hot({int limit = 20}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/hot-videos',
        queryParameters: {'limit': limit},
      );
      final body = res.data ?? const {};
      return (body['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Video.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
