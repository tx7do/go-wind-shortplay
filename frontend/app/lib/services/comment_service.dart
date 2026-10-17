import '../core/network/api_client.dart';
import '../models/comment.dart';
import '../models/common.dart';

/// 评论 / 楼中楼。
class CommentService {
  CommentService(this._api);

  final ApiClient _api;

  static const int _pageSize = 10;

  /// 评论列表（游客可访问，pageNum 从 1 起）。
  Future<PageData<Comment>> comments({
    required int videoId,
    required int pageNum,
  }) async {
    final data = await _api.getJson(
      '/videos/$videoId/comments',
      query: {'pageNum': pageNum},
    );
    return PageData.parse(
      data,
      parseItem: Comment.fromJson,
      pageNum: pageNum,
      pageSize: _pageSize,
    );
  }

  /// 楼中楼回复列表。
  Future<PageData<Comment>> replies({
    required int commentId,
    required int pageNum,
  }) async {
    final data = await _api.getJson(
      '/comments/$commentId/replies',
      query: {'pageNum': pageNum},
    );
    return PageData.parse(
      data,
      parseItem: Comment.fromJson,
      pageNum: pageNum,
      pageSize: _pageSize,
    );
  }

  /// 发表评论；楼中楼传 parentId。
  Future<Comment> post(
    int videoId,
    String content, {
    int? parentId,
  }) async {
    final data = await _api.postJson(
      '/videos/$videoId/comments',
      data: {
        'content': content,
        'parentId': ?parentId,
      },
    );
    // 响应可能是评论对象本身，也可能包在 {comment:{...}} 里。
    final inner = data['comment'];
    return Comment.fromJson(
      inner is Map<String, dynamic> ? inner : data,
    );
  }

  /// 删除自己的评论（403 NOT_OWNER 由 UI 提示）。
  Future<void> delete(int commentId) => _api.deleteJson('/comments/$commentId');
}
