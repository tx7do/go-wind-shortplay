import 'common.dart';
import 'user.dart';

/// 通知类型：LIKE / COMMENT / FOLLOW / SYSTEM。
enum NotifyType { like, comment, follow, system, unknown }

/// 站内通知（GET /notifications）。
class AppNotification {
  const AppNotification({
    required this.id,
    this.type = NotifyType.unknown,
    this.sender,
    this.videoId,
    this.commentId,
    this.content = '',
    this.isRead = false,
    this.createdAt = '',
  });

  final int id;
  final NotifyType type;
  final User? sender;
  final int? videoId;
  final int? commentId;
  final String content;
  final bool isRead;
  final String createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final senderJson = json['sender'];
    return AppNotification(
      id: asInt(
        json['id'] ?? json['notificationId'] ?? json['notification_id'],
      ),
      type: _parseType(asStr(json['type'])),
      sender:
          senderJson is Map<String, dynamic> ? User.fromJson(senderJson) : null,
      videoId: asIntOrNull(json['videoId'] ?? json['video_id']),
      commentId: asIntOrNull(json['commentId'] ?? json['comment_id']),
      content: asStr(json['content']),
      isRead: asBool(json['isRead'] ?? json['is_read']),
      createdAt: asStr(json['createdAt'] ?? json['created_at']),
    );
  }

  static NotifyType _parseType(String raw) {
    switch (raw.toUpperCase()) {
      case 'LIKE':
        return NotifyType.like;
      case 'COMMENT':
        return NotifyType.comment;
      case 'FOLLOW':
        return NotifyType.follow;
      case 'SYSTEM':
        return NotifyType.system;
      default:
        return NotifyType.unknown;
    }
  }
}
