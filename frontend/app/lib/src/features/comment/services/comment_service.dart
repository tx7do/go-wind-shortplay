import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/comment/models/comment.dart';
import 'package:shortplay_app/src/features/common/services/interaction_service.dart';

/// 评论服务：评论列表 / 楼中楼 / 发表 / 删除 / 评论点赞
class CommentService extends BaseService {
  CommentService() : super(tag: 'CommentService');

  Dio get _dio => GetIt.instance<Dio>();
  final InteractionService _interaction = InteractionService();

  /// 视频评论列表（游客可访问，`pageNum/pageSize`；sort 传枚举全名，如
  /// `COMMENT_SORT_HOT`——缺省时间倒序）
  Future<CommentPage> list({
    required int videoId,
    required PaginationQuery query,
    String? sort,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/videos/$videoId/comments',
        queryParameters: {
          ...query.toQueryMap(),
          if (sort != null && sort.isNotEmpty) 'sort': sort,
        },
      );
      final data = res.data ?? const {};
      return _toPage(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 楼中楼回复列表
  Future<CommentPage> replies({
    required int commentId,
    required PaginationQuery query,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/comments/$commentId/replies',
        queryParameters: query.toQueryMap(),
      );
      final data = res.data ?? const {};
      return _toPage(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 发表评论（楼中楼传 [parentId]）→ Comment
  Future<Comment> create({
    required int videoId,
    required String content,
    int parentId = 0,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/videos/$videoId/comments',
        data: {
          'content': content,
          if (parentId > 0) 'parentId': parentId,
        },
      );
      final data = res.data;
      if (data == null) {
        throw ApiStatusException(Status(message: 'empty response'));
      }
      return Comment.fromJson(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 删除自己的评论
  Future<void> delete(int commentId) async {
    try {
      await _dio.delete<Object?>('/comments/$commentId');
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 评论点赞（幂等）→ {liked, likeCount}
  Future<({bool liked, int likeCount})> like(int commentId) {
    return _interaction.like(
      targetType: LikeTargetType.comment,
      targetId: commentId,
    );
  }

  /// 取消评论点赞 → {liked, likeCount}
  Future<({bool liked, int likeCount})> unlike(int commentId) {
    return _interaction.unlike(
      targetType: LikeTargetType.comment,
      targetId: commentId,
    );
  }

  CommentPage _toPage(Map<String, dynamic> data) {
    final items = (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList();
    return CommentPage(
      items: items,
      total: jsonInt(data['total'], fallback: items.length),
    );
  }
}
