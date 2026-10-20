import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 剧集服务：建剧 / 编辑 / 详情选集 / 列表（详情与列表游客可访问）
class SeriesService extends BaseService {
  SeriesService() : super(tag: 'SeriesService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 剧集详情（剧信息 + 选集，集号升序；游客仅见已发布集）
  Future<SeriesDetail> getSeries(int seriesId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/series/$seriesId');
      return SeriesDetail.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 剧集列表（query 剧名模糊 / authorId 按作者过滤；非本人视角仅含有已发布集的剧）
  Future<PageData<Series>> listSeries({
    String? query,
    int? authorId,
    required PaginationQuery paging,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/series',
        queryParameters: {
          ...paging.toQueryMap(),
          if (query != null && query.isNotEmpty) 'query': query,
          if (authorId != null && authorId > 0) 'authorId': authorId,
        },
      );
      final body = res.data ?? const {};
      final items = (body['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Series.fromJson)
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

  /// 创建剧集（需登录），返回新建剧
  Future<Series> createSeries({
    required String title,
    String? description,
    String? coverUrl,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/series',
        data: {
          'title': title,
          if (description != null && description.isNotEmpty) 'description': description,
          if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
        },
      );
      return Series.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 编辑自己的剧集（标题/简介/封面）
  Future<Series> updateSeries({
    required int seriesId,
    required String title,
    String? description,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/series/$seriesId',
        data: {
          'title': title,
          'description': ?description,
        },
      );
      return Series.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 删除自己的剧集（剧内视频解挂保留）
  Future<void> deleteSeries(int seriesId) async {
    try {
      await _dio.delete<void>('/series/$seriesId');
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
