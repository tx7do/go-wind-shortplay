import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart'
    show parseTime;

/// 站内信收件状态（基座 internal_message 域 protojson 枚举名）
class NotifyStatus {
  NotifyStatus._();

  static const sent = 'SENT'; // 已入收件箱（未读）
  static const received = 'RECEIVED'; // 客户端已接收（未读）
  static const read = 'READ'; // 已读
}

/// 站内信通知（基座 internal_message.service.v1.InternalMessageRecipient）
///
/// 基座收件箱形状：无 sender/type/videoId 等短剧业务字段，
/// 标题 + 正文 + 收件状态 + 时间；点击仅做已读，不再跳转视频详情。
class NotificationItem {
  /// 收件记录 ID（标记已读用）
  final int id;

  /// 站内信内容 ID
  final int messageId;

  /// 收件状态（SENT/RECEIVED/READ）
  final String status;

  /// 消息标题
  final String title;

  /// 消息正文
  final String content;

  final bool isRead;
  final DateTime? createdAt;

  const NotificationItem({
    required this.id,
    this.messageId = 0,
    this.status = NotifyStatus.sent,
    this.title = '',
    this.content = '',
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final status = jsonString(json['status'], fallback: NotifyStatus.sent);
    return NotificationItem(
      id: jsonInt(json['id']),
      messageId: jsonInt(json['messageId']),
      status: status,
      title: jsonString(json['title']),
      content: jsonString(json['content']),
      isRead: status == NotifyStatus.read,
      createdAt: parseTime(json['createdAt']),
    );
  }

  NotificationItem markRead() {
    return NotificationItem(
      id: id,
      messageId: messageId,
      status: NotifyStatus.read,
      title: title,
      content: content,
      isRead: true,
      createdAt: createdAt,
    );
  }
}
