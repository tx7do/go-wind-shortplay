import 'dart:convert';

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

/// 站内信 content 机器可读尾标记约定（与 core report_service.go spBizMarkerPrefix 对齐）：
/// content 末尾为独立一行 `sp-biz:{...}`，JSON 载荷按业务类型携带跳转定位字段，
/// 视频类通知为 `{"videoId":<id>}`。无标记或解析失败一律视为普通文本通知（向后兼容），
/// 标记行在展示前剔除，不影响人读文案。
const String spBizMarkerKey = 'sp-biz:';

/// 解析 content 尾标记：返回 (剔除标记行后的展示文案, videoId 或 null)。
///
/// 约定见 [spBizMarkerKey]；videoId 非正数视为无跳转目标。
(String, int?) parseSpBizMarker(String content) {
  final markerLine = '\n$spBizMarkerKey';
  final idx = content.lastIndexOf(markerLine);
  if (idx < 0) {
    return (content, null);
  }
  final display = content.substring(0, idx);
  final payload = content.substring(idx + markerLine.length).trim();
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      final videoId = jsonInt(decoded['videoId'], fallback: 0);
      return (display, videoId > 0 ? videoId : null);
    }
  } on FormatException {
    // 尾标记行不是合法 JSON：按无标记兜底（纯本地 best-effort，原样展示全量文案）
    return (content, null);
  }
  return (content, null);
}

/// 站内信通知（基座 internal_message.service.v1.InternalMessageRecipient）
///
/// 基座收件箱形状：标题 + 正文 + 收件状态 + 时间；content 携带 sp-biz 尾标记时
/// 解析出 videoId，点击跳转视频详情页，否则仅做已读。
class NotificationItem {
  /// 收件记录 ID（标记已读用）
  final int id;

  /// 站内信内容 ID
  final int messageId;

  /// 收件状态（SENT/RECEIVED/READ）
  final String status;

  /// 消息标题
  final String title;

  /// 消息正文（已剔除 sp-biz 尾标记行）
  final String content;

  /// 通知关联的视频 ID（sp-biz 尾标记解析，无标记/非视频类通知为 null）
  final int? videoId;

  final bool isRead;
  final DateTime? createdAt;

  const NotificationItem({
    required this.id,
    this.messageId = 0,
    this.status = NotifyStatus.sent,
    this.title = '',
    this.content = '',
    this.videoId,
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final status = jsonString(json['status'], fallback: NotifyStatus.sent);
    final (content, videoId) = parseSpBizMarker(jsonString(json['content']));
    return NotificationItem(
      id: jsonInt(json['id']),
      messageId: jsonInt(json['messageId']),
      status: status,
      title: jsonString(json['title']),
      content: content,
      videoId: videoId,
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
      videoId: videoId,
      isRead: true,
      createdAt: createdAt,
    );
  }
}
