import 'dart:io' show File;

import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 头像图片直传上限（与后端 /uploads/image 契约一致：2MB）
const avatarUploadMaxBytes = 2 * 1024 * 1024;

/// 按扩展名映射图片 MIME（后端按 Content-Type 白名单校验：
/// jpeg/png/webp/gif；其余返回 415）
String? _imageMimeFromPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    default:
      return null;
  }
}

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

  /// 头像图片直传 POST /uploads/image（需登录，Bearer 由全局认证拦截器附加）
  ///
  /// 契约与 admin 端 /admin/v1/uploads/image 对称：body = 图片原始字节，
  /// Content-Type = 图片 MIME（非 multipart），≤2MB，成功返回 {url}。
  /// [onSendProgress] 上传进度回调（已发送字节 / 总字节）。
  Future<String> uploadAvatar(
    File file, {
    void Function(int count, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final mime = _imageMimeFromPath(file.path);
    if (mime == null) {
      throw ApiStatusException(Status(message: 'unsupported image type'));
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw ApiStatusException(Status(message: 'empty image body'));
    }
    if (bytes.length > avatarUploadMaxBytes) {
      throw ApiStatusException(Status(message: 'image exceeds 2MB limit'));
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/image',
        data: Stream.fromIterable([bytes]),
        options: Options(
          contentType: mime,
          headers: {'Content-Length': '${bytes.length}'},
        ),
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
      final url = res.data?['url'];
      if (url is! String || url.isEmpty) {
        throw ApiStatusException(Status(message: 'empty response'));
      }
      return url;
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
