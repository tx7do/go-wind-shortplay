import 'common.dart';
import 'user.dart';

/// 评论 / 楼中楼回复。
class Comment {
  const Comment({
    required this.id,
    this.videoId = 0,
    this.userId = 0,
    this.user,
    this.content = '',
    this.parentId,
    this.likeCount = 0,
    this.replyCount = 0,
    this.createdAt = '',
  });

  final int id;
  final int videoId;
  final int userId;
  final User? user;
  final String content;

  /// 楼中楼回复的父评论 id，顶级评论为 null。
  final int? parentId;
  final int likeCount;
  final int replyCount;
  final String createdAt;

  Comment copyWith({int? likeCount, int? replyCount}) => Comment(
        id: id,
        videoId: videoId,
        userId: userId,
        user: user,
        content: content,
        parentId: parentId,
        likeCount: likeCount ?? this.likeCount,
        replyCount: replyCount ?? this.replyCount,
        createdAt: createdAt,
      );

  factory Comment.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return Comment(
      id: asInt(json['id'] ?? json['commentId'] ?? json['comment_id']),
      videoId: asInt(json['videoId'] ?? json['video_id']),
      userId: asInt(json['userId'] ?? json['user_id']),
      user:
          userJson is Map<String, dynamic> ? User.fromJson(userJson) : null,
      content: asStr(json['content']),
      parentId: asIntOrNull(json['parentId'] ?? json['parent_id']),
      likeCount: asInt(json['likeCount'] ?? json['like_count']),
      replyCount: asInt(json['replyCount'] ?? json['reply_count']),
      createdAt: asStr(json['createdAt'] ?? json['created_at']),
    );
  }
}
