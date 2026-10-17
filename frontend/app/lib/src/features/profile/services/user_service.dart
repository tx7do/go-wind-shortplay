import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 用户服务：主页资料 / 统计 / 作品列表 / 收藏列表 / 编辑资料
class UserService extends BaseService {
  UserService() : super(tag: 'UserService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 用户主页资料（游客可访问）
  Future<UserProfile> getUser(int userId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/users/$userId');
      final data = res.data;
      if (data == null) {
        throw ApiStatusException(Status(message: 'empty response'));
      }
      return UserProfile.fromJson(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 用户统计（游客可访问）
  Future<UserStats> getStats(int userId) async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/users/$userId/stats');
      final data = res.data;
      if (data == null) {
        throw ApiStatusException(Status(message: 'empty response'));
      }
      return UserStats.fromJson(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 创作者中心总览（需登录）
  Future<CreatorOverview> creatorOverview() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/creator/overview');
      final data = res.data;
      if (data == null) {
        throw ApiStatusException(Status(message: 'empty response'));
      }
      return CreatorOverview.fromJson(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 用户作品列表（本人含审核中/驳回/下架，他人仅已发布）
  Future<PageData<Video>> userVideos({
    required int userId,
    required PaginationQuery query,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/users/$userId/videos',
        queryParameters: query.toQueryMap(),
      );
      final data = res.data ?? const {};
      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Video.fromJson)
          .toList();
      return PageData.inferHasMore(
        items: items,
        total: jsonInt(data['total'], fallback: items.length),
        pageNum: query.pageNum,
        pageSize: query.pageSize,
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 我的收藏列表
  Future<PageData<Video>> collects(PaginationQuery query) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/collects',
        queryParameters: query.toPageMap(),
      );
      final data = res.data ?? const {};
      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Video.fromJson)
          .toList();
      return PageData.inferHasMore(
        items: items,
        total: jsonInt(data['total'], fallback: items.length),
        pageNum: query.pageNum,
        pageSize: query.pageSize,
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 编辑资料 {nickname?, avatarUrl?, bio?}
  Future<UserProfile> updateProfile({
    String? nickname,
    String? avatarUrl,
    String? bio,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/profile',
        data: {
          'nickname': ?nickname,
          'avatarUrl': ?avatarUrl,
          'bio': ?bio,
        },
      );
      final data = res.data;
      if (data == null) {
        throw ApiStatusException(Status(message: 'empty response'));
      }
      return UserProfile.fromJson(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
