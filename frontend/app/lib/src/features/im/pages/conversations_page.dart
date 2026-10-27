import 'dart:async' show StreamSubscription;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart' show RouteNames;
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/transport/sse/sse_client.dart';
import 'package:shortplay_app/src/core/utilities/number_format.dart';
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/common/widgets/user_avatar.dart';
import 'package:shortplay_app/src/features/im/services/im_service.dart';

/// 私信会话列表（最近消息倒序；SSE 收到新消息即刷新首屏）
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final ImService _imService = ImService();
  final ScrollController _scrollController = ScrollController();
  final List<Conversation> _items = [];
  StreamSubscription<SseMessage>? _sub;

  bool _loading = false;
  bool _hasMore = true;
  int _pageNum = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNext();
    // 实时性：收到任意私信事件就刷新首屏（简单可靠，落库为准的口径下
    // 事件只提示"有新消息"，真实数据以 REST 拉取为准）
    _sub = sseClient.events.listen((m) {
      if (m.event == 'im-message') _refresh();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      _pageNum += 1;
      final page = await _imService.conversations(
        paging: PaginationQuery(pageNum: _pageNum, pageSize: 20),
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _pageNum -= 1;
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _pageNum = 0;
      _hasMore = true;
    });
    await _loadNext();
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.imConversations)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _items.isEmpty && _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: loc.imEmpty,
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => SizedBox(height: 2.h),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final conv = _items[index];
                      return _ConversationTile(
                        conversation: conv,
                        onTap: () async {
                          await context.pushNamed(
                            RouteNames.imChat,
                            pathParameters: {'peerId': '${conv.peerId}'},
                            queryParameters: {'conversationId': '${conv.id}'},
                          );
                          // 回来自刷新（未读可能已清零）
                          if (mounted) _refresh();
                        },
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  String _timeLabel(DateTime? at) {
    if (at == null) return '';
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    if (sameDay) return DateFormat('HH:mm').format(at);
    return DateFormat('MM-dd').format(at);
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);
    final conv = conversation;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(
          children: [
            UserAvatar.fromBrief(conv.peer, radius: 24),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.peer.nickname.isEmpty
                              ? loc.imUserFallback
                              : conv.peer.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _timeLabel(conv.lastMessageAt),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: theme.colorScheme.onSurface.withAlpha(110),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.lastMessagePreview.isEmpty
                              ? loc.imConversationEmpty
                              : conv.lastMessagePreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: theme.colorScheme.onSurface.withAlpha(140),
                          ),
                        ),
                      ),
                      if (conv.unreadCount > 0) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 1.h,
                          ),
                          decoration: BoxDecoration(
                            gradient: BrandColor.gradient,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            NumberFormatUtils.formatCount(conv.unreadCount),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
