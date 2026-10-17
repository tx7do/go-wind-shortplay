import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 点赞目标类型（protojson 枚举字符串全名）
class LikeTargetType {
  LikeTargetType._();

  static const video = 'TARGET_TYPE_VIDEO';
  static const comment = 'TARGET_TYPE_COMMENT';
}

/// 互动服务：点赞 / 收藏 / 关注 / 批量互动状态
///
/// 除批量状态查询外均需登录（UI 层先经登录引导）。
class InteractionService extends BaseService {
  InteractionService() : super(tag: 'InteractionService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 点赞（幂等）→ {liked, likeCount}
  Future<({bool liked, int likeCount})> like({
    required String targetType,
    required int targetId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/likes',
        data: {'targetType': targetType, 'targetId': targetId},
      );
      final data = res.data ?? const {};
      return (
        liked: data['liked'] == true,
        likeCount: _count(data['likeCount']),
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 取消点赞 → {liked, likeCount}
  Future<({bool liked, int likeCount})> unlike({
    required String targetType,
    required int targetId,
  }) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>(
        '/likes/$targetType/$targetId',
      );
      final data = res.data ?? const {};
      return (
        liked: data['liked'] == true,
        likeCount: _count(data['likeCount']),
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 收藏 → {collected, collectCount}
  Future<({bool collected, int collectCount})> collect({
    required int videoId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/videos/$videoId/collect',
        data: const {},
      );
      final data = res.data ?? const {};
      return (
        collected: data['collected'] == true,
        collectCount: _count(data['collectCount']),
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 取消收藏 → {collected, collectCount}
  Future<({bool collected, int collectCount})> uncollect({
    required int videoId,
  }) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>(
        '/videos/$videoId/collect',
      );
      final data = res.data ?? const {};
      return (
        collected: data['collected'] == true,
        collectCount: _count(data['collectCount']),
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 批量查询视频互动状态（游客可用，全 false）
  /// → statuses{[id]: {liked, collected}}
  Future<Map<int, InteractionStatus>> statuses(List<int> videoIds) async {
    if (videoIds.isEmpty) return {};
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/interactions/status',
        data: {'videoIds': videoIds},
      );
      final statuses = res.data?['statuses'];
      if (statuses is! Map) return {};
      return statuses.map((key, value) {
        final id = int.tryParse('$key') ?? 0;
        final status = value is Map<String, dynamic>
            ? InteractionStatus.fromJson(value)
            : const InteractionStatus();
        return MapEntry(id, status);
      });
    } on DioException catch (e) {
      logger.w('interaction statuses failed: ${handleDioError(e).getReason}');
      return {};
    }
  }

  /// 关注作者 → {following}
  Future<bool> follow(int userId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/users/$userId/follow',
        data: const {},
      );
      return res.data?['following'] == true;
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 取关作者 → {following}
  Future<bool> unfollow(int userId) async {
    try {
      final res =
          await _dio.delete<Map<String, dynamic>>('/users/$userId/follow');
      return res.data?['following'] == true;
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  int _count(dynamic value) =>
      value == null ? 0 : (value is int ? value : int.tryParse('$value') ?? 0);
}
