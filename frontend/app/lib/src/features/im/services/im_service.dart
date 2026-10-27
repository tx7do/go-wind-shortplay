import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 会话（im.service.v1.Conversation；peer 由服务端按 viewer 视角解析）
class Conversation {
  final int id;
  final int peerId;
  final UserBrief peer;

  /// 最近一条消息预览（空会话为 ''）
  final String lastMessagePreview;
  final DateTime? lastMessageAt;

  /// viewer 侧未读数
  final int unreadCount;
  final DateTime? createdAt;

  const Conversation({
    required this.id,
    this.peerId = 0,
    this.peer = const UserBrief(id: 0),
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.unreadCount = 0,
    this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final peer = json['peer'];
    return Conversation(
      id: jsonInt(json['id']),
      peerId: jsonInt(json['peerId']),
      peer: peer is Map<String, dynamic>
          ? UserBrief.fromJson(peer)
          : const UserBrief(id: 0),
      lastMessagePreview: jsonString(json['lastMessagePreview']),
      lastMessageAt: parseTime(json['lastMessageAt']),
      unreadCount: jsonInt(json['unreadCount']),
      createdAt: parseTime(json['createdAt']),
    );
  }

  Conversation copyWith({
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return Conversation(
      id: id,
      peerId: peerId,
      peer: peer,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
    );
  }
}

/// 私信消息（im.service.v1.Message）
class ImMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final int receiverId;
  final UserBrief sender;
  final String content;
  final DateTime? createdAt;

  const ImMessage({
    required this.id,
    this.conversationId = 0,
    this.senderId = 0,
    this.receiverId = 0,
    this.sender = const UserBrief(id: 0),
    this.content = '',
    this.createdAt,
  });

  factory ImMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    return ImMessage(
      id: jsonInt(json['id']),
      conversationId: jsonInt(json['conversationId']),
      senderId: jsonInt(json['senderId']),
      receiverId: jsonInt(json['receiverId']),
      sender: sender is Map<String, dynamic>
          ? UserBrief.fromJson(sender)
          : const UserBrief(id: 0),
      content: jsonString(json['content']),
      createdAt: parseTime(json['createdAt']),
    );
  }
}

/// 私信服务：发送（自动建会话）/ 会话列表 / 消息 / 已读 / 未读数
class ImService extends BaseService {
  ImService() : super(tag: 'ImService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 发送私信（返回落库后的消息）
  Future<ImMessage> send({
    required int receiverId,
    required String content,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/im/messages',
        data: {'receiverId': receiverId, 'content': content},
      );
      return ImMessage.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 会话列表（最近消息倒序）
  Future<PageData<Conversation>> conversations({
    required PaginationQuery paging,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/im/conversations',
        queryParameters: paging.toQueryMap(),
      );
      final body = res.data ?? const {};
      final items = (body['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Conversation.fromJson)
          .toList();
      return PageData.inferHasMore(
        items: items,
        total: jsonInt(body['total'], fallback: items.length),
        pageNum: paging.pageNum,
        pageSize: paging.pageSize,
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 与指定用户建会话（存在即返回既有；聊天页从他人主页进入用）
  Future<Conversation> ensureConversation(int peerUserId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/im/conversations',
        data: {'peerUserId': peerUserId},
      );
      return Conversation.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 会话消息（ID 倒序：最新一页在前，翻页取更早）
  Future<PageData<ImMessage>> messages({
    required int conversationId,
    required PaginationQuery paging,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/im/conversations/$conversationId/messages',
        queryParameters: paging.toQueryMap(),
      );
      final body = res.data ?? const {};
      final items = (body['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ImMessage.fromJson)
          .toList();
      return PageData.inferHasMore(
        items: items,
        total: jsonInt(body['total'], fallback: items.length),
        pageNum: paging.pageNum,
        pageSize: paging.pageSize,
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 标记会话已读
  Future<void> markRead(int conversationId) async {
    try {
      await _dio.put<void>('/im/conversations/$conversationId/read');
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 全部会话未读总数（角标）
  Future<int> unreadCount() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/im/unread-count');
      return jsonInt(res.data?['count']);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
