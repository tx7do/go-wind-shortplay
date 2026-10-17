import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 评论（interaction.service.v1.Comment）
///
/// protojson：id/videoId/userId/parentId 为数字；likeCount/replyCount 为字符串。
class Comment {
  final int id;
  final int videoId;
  final int userId;
  final UserBrief user;
  final String content;
  final int parentId;
  final int likeCount;
  final int replyCount;
  final DateTime? createdAt;

  /// 本地点赞状态（列表接口不回传，点赞操作后本地维护）
  final bool liked;

  /// 楼中楼回复（展开后填充）
  final List<Comment> replies;

  const Comment({
    required this.id,
    this.videoId = 0,
    this.userId = 0,
    this.user = const UserBrief(id: 0),
    this.content = '',
    this.parentId = 0,
    this.likeCount = 0,
    this.replyCount = 0,
    this.createdAt,
    this.liked = false,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return Comment(
      id: jsonInt(json['id']),
      videoId: jsonInt(json['videoId']),
      userId: jsonInt(json['userId']),
      user: user is Map<String, dynamic> ? UserBrief.fromJson(user) : const UserBrief(id: 0),
      content: jsonString(json['content']),
      parentId: jsonInt(json['parentId']),
      likeCount: jsonInt(json['likeCount']),
      replyCount: jsonInt(json['replyCount']),
      createdAt: parseTime(json['createdAt']),
    );
  }

  bool get isReply => parentId > 0;

  Comment copyWith({
    int? likeCount,
    bool? liked,
    List<Comment>? replies,
    int? replyCount,
  }) {
    return Comment(
      id: id,
      videoId: videoId,
      userId: userId,
      user: user,
      content: content,
      parentId: parentId,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      createdAt: createdAt,
      liked: liked ?? this.liked,
      replies: replies ?? this.replies,
    );
  }
}

/// 评论列表响应（items + total）
class CommentPage {
  final List<Comment> items;
  final int total;

  const CommentPage({required this.items, this.total = 0});
}
