import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 通知类型（protojson 枚举全名）
class NotifyType {
  NotifyType._();

  static const like = 'NOTIFY_TYPE_LIKE';
  static const comment = 'NOTIFY_TYPE_COMMENT';
  static const follow = 'NOTIFY_TYPE_FOLLOW';
  static const system = 'NOTIFY_TYPE_SYSTEM';
}

/// 通知（notify.service.v1.Notification）
class NotificationItem {
  final int id;
  final String type;

  /// 触发者（系统通知为空）
  final UserBrief? sender;

  /// 关联视频（点击跳转；0 表示无）
  final int videoId;
  final int commentId;
  final String content;
  final bool isRead;
  final DateTime? createdAt;

  const NotificationItem({
    required this.id,
    this.type = NotifyType.system,
    this.sender,
    this.videoId = 0,
    this.commentId = 0,
    this.content = '',
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    return NotificationItem(
      id: jsonInt(json['id']),
      type: jsonString(json['type'], fallback: NotifyType.system),
      sender:
          sender is Map<String, dynamic> ? UserBrief.fromJson(sender) : null,
      videoId: jsonInt(json['videoId']),
      commentId: jsonInt(json['commentId']),
      content: jsonString(json['content']),
      isRead: jsonBool(json['isRead']),
      createdAt: parseTime(json['createdAt']),
    );
  }

  NotificationItem markRead() {
    return NotificationItem(
      id: id,
      type: type,
      sender: sender,
      videoId: videoId,
      commentId: commentId,
      content: content,
      isRead: true,
      createdAt: createdAt,
    );
  }
}
