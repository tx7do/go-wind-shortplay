import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart'
    show ApiStatusException, localizedErrorText;
import 'package:shortplay_app/src/core/transport/sse/sse_client.dart';
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/common/widgets/login_guard.dart';
import 'package:shortplay_app/src/features/common/widgets/user_avatar.dart';
import 'package:shortplay_app/src/features/im/services/im_service.dart';

/// 1:1 聊天页
///
/// - [conversationId] 可空（从他人主页进入时先 ensureConversation 建会话）
/// - 消息 ID 倒序分页：首屏最新一页，渲染时反转（最新在底）；上拉加载更早
/// - 实时性：SSE 收到本会话 im-message 事件即拉最新一页合并（落库为准）
/// - 进入/收到新消息自动 markRead（清对方侧展示的未读）
class ChatPage extends StatefulWidget {
  final int peerId;

  /// 对端昵称（标题兜底；进入后以会话信息覆盖）
  final String peerNickname;
  final int? conversationId;

  const ChatPage({
    super.key,
    required this.peerId,
    this.peerNickname = '',
    this.conversationId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ImService _imService = ImService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  StreamSubscription<SseMessage>? _sub;

  final List<ImMessage> _messages = [];
  int _conversationId = 0;
  String _peerNickname = '';
  String _peerAvatar = '';

  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;
  bool _sending = false;
  int _pageNum = 0;

  int get _myId => GetIt.instance<UserAuthCache>().userId;

  @override
  void initState() {
    super.initState();
    _peerNickname = widget.peerNickname;
    _conversationId = widget.conversationId ?? 0;
    _scrollController.addListener(_onScroll);
    _bootstrap();
    // 实时性：仅处理本会话的新消息事件
    _sub = sseClient.events.listen((m) {
      if (m.event != 'im-message') return;
      _onIncoming();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 0 && _hasMoreOlder) {
      _loadOlder();
    }
  }

  /// 启动：无会话先建；随后拉首屏 + 标记已读
  Future<void> _bootstrap() async {
    try {
      if (_conversationId <= 0) {
        final conv = await _imService.ensureConversation(widget.peerId);
        _conversationId = conv.id;
        _applyPeer(conv.peer.nickname, conv.peer.avatarDisplayUrl);
      }
      await _loadLatest(markRead: true);
    } on ApiStatusException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      EasyLoading.showToast(localizedErrorText(S.of(context), e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyPeer(String nickname, String avatar) {
    if (!mounted) return;
    setState(() {
      if (nickname.isNotEmpty) _peerNickname = nickname;
      _peerAvatar = avatar;
    });
  }

  /// 拉最新一页（合并去重后按 ID 升序渲染；可选标记已读）
  Future<void> _loadLatest({bool markRead = false}) async {
    if (_conversationId <= 0) return;
    final page = await _imService.messages(
      conversationId: _conversationId,
      paging: const PaginationQuery(pageNum: 1, pageSize: 20),
    );
    if (!mounted) return;
    final merged = <int, ImMessage>{
      for (final m in page.items) m.id: m,
      for (final m in _messages) m.id: m,
    };
    final list = merged.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    setState(() {
      _messages
        ..clear()
        ..addAll(list);
      // 首屏只有一页时也可能还有更早消息
      _hasMoreOlder = _messages.length < page.total;
      _loading = false;
    });
    if (markRead && _conversationId > 0) {
      unawaited(_imService.markRead(_conversationId));
    }
  }

  /// 加载更早消息（列表顶部触发；保持滚动位置）
  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMoreOlder || _conversationId <= 0) return;
    setState(() => _loadingOlder = true);
    try {
      _pageNum += 1;
      final page = await _imService.messages(
        conversationId: _conversationId,
        paging: PaginationQuery(pageNum: _pageNum + 1, pageSize: 20),
      );
      // pageNum 从 2 起（首页被 _loadLatest 占用）
      if (!mounted) return;
      final known = _messages.map((m) => m.id).toSet();
      final older = page.items.where((m) => !known.contains(m.id)).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      final pos = _scrollController.hasClients
          ? _scrollController.position.pixels
          : 0.0;
      setState(() {
        _messages.insertAll(0, older);
        _hasMoreOlder = page.hasMore;
        _loadingOlder = false;
      });
      if (_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.pixels - pos);
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      _pageNum -= 1;
      setState(() => _loadingOlder = false);
    }
  }

  Future<void> _onIncoming() async {
    if (_conversationId <= 0) return;
    // 收到本会话新消息：拉最新一页合并（含自己其他端发的），顺带清未读
    await _loadLatest(markRead: true);
  }

  Future<void> _send() async {
    final loc = S.of(context);
    final content = _inputController.text.trim();
    if (content.isEmpty || _sending) return;
    if (!await ensureLogin(context) || !mounted) return;

    setState(() => _sending = true);
    try {
      final msg = await _imService.send(
        receiverId: widget.peerId,
        content: content,
      );
      _inputController.clear();
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m.id == msg.id)) {
          _messages.add(msg);
        }
      });
      _jumpToBottom();
    } on ApiStatusException catch (e) {
      EasyLoading.showToast(localizedErrorText(S.of(context), e));
    } catch (_) {
      EasyLoading.showToast(loc.errorOccurred);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              avatarUrl: _peerAvatar,
              nickname: _peerNickname,
              radius: 14.r,
            ),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                _peerNickname.isEmpty ? loc.imUserFallback : _peerNickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _messages.isEmpty
                          ? EmptyState(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: loc.imEmpty,
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              reverse: true, // 最新在底；上拉（负向滚动）加载更早
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              itemCount:
                                  _messages.length +
                                  (_loadingOlder || _hasMoreOlder ? 1 : 0),
                              itemBuilder: (context, index) {
                                final flipped = _messages.length - 1 - index;
                                if (flipped < 0) {
                                  return Padding(
                                    padding: EdgeInsets.all(10.h),
                                    child: Center(
                                      child: _loadingOlder
                                          ? const CircularProgressIndicator(
                                              strokeWidth: 2,
                                            )
                                          : Text(
                                              loc.allLoaded,
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withAlpha(110),
                                              ),
                                            ),
                                    ),
                                  );
                                }
                                final msg = _messages[flipped];
                                return _MessageBubble(
                                  message: msg,
                                  isMine: msg.senderId == _myId,
                                );
                              },
                            ),
                    ),
                  ),
                ),
                // 输入栏
                SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.onSurface.withAlpha(20),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              focusNode: _inputFocus,
                              maxLines: 3,
                              minLines: 1,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              style: TextStyle(fontSize: 14.sp),
                              decoration: InputDecoration(
                                hintText: loc.imInputHint,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 10.h,
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.onSurface
                                    .withAlpha(12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(100),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          IconButton.filled(
                            onPressed: _sending ? null : _send,
                            icon: _sending
                                ? SizedBox(
                                    width: 16.sp,
                                    height: 16.sp,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ImMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            UserAvatar.fromBrief(message.sender, radius: 14),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              constraints: BoxConstraints(maxWidth: 280.w),
              decoration: BoxDecoration(
                gradient: isMine ? BrandColor.gradient : null,
                color: isMine
                    ? null
                    : theme.colorScheme.onSurface.withAlpha(14),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14.r),
                  topRight: Radius.circular(14.r),
                  bottomLeft: Radius.circular(isMine ? 14.r : 2.r),
                  bottomRight: Radius.circular(isMine ? 2.r : 14.r),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.4,
                  color: isMine ? Colors.white : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
