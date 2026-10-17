import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth_cubit.dart';
import '../../blocs/comment_cubit.dart';
import '../../models/comment.dart';
import '../../models/user.dart';
import '../../models/video.dart';
import '../../widgets/common.dart';
import '../login/login_page.dart';

/// 评论弹窗：底部 DraggableScrollableSheet。
///
/// 功能：分页评论列表、楼中楼展开、发表评论/回复、
/// 删除自己的评论（长按）、评论点赞。
class CommentSheet extends StatefulWidget {
  const CommentSheet({
    super.key,
    required this.video,
    required this.onCountChanged,
  });

  final Video video;

  /// 评论数变化回调（发表 +1 / 删除 -1），由调用方更新 Feed 计数。
  final ValueChanged<int> onCountChanged;

  /// 打开评论弹窗。
  static Future<void> show(
    BuildContext context, {
    required Video video,
    required ValueChanged<int> onCountChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider<CommentCubit>(
        create: (_) => CommentCubit(video.id)..loadFirst(),
        child: CommentSheet(video: video, onCountChanged: onCountChanged),
      ),
    );
  }

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();

  User? _me;

  /// 本会话内的评论数增量（发表 +1 / 删除 -1）。
  int _delta = 0;

  @override
  void initState() {
    super.initState();
    _me = context.read<AuthCubit>().state.user;
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final cubit = context.read<CommentCubit>();
    final ok = await cubit.submit(_inputCtrl.text);
    if (!mounted) return;
    if (ok) {
      _inputCtrl.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onCountChanged(1);
      setState(() => _delta++);
      showToast(context, '评论成功');
    } else {
      showToast(context, cubit.state.error ?? '评论失败，请稍后重试');
    }
  }

  Future<void> _confirmDelete(Comment c, {required bool isReply}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除评论'),
        content: const Text('确定要删除这条评论吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cubit = context.read<CommentCubit>();
    final ok = await cubit.delete(c, isReply: isReply);
    if (!mounted) return;
    if (ok) {
      widget.onCountChanged(-1);
      setState(() => _delta--);
      showToast(context, '已删除');
    } else {
      showToast(context, cubit.state.error ?? '删除失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 键盘弹出时抬升输入框。
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1D1D20),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                _header(scrollController),
                const Divider(height: 1, color: Colors.white12),
                Expanded(child: _buildList(scrollController)),
                const Divider(height: 1, color: Colors.white12),
                _buildInputBar(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(ScrollController scrollController) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 16),
              BlocBuilder<CommentCubit, CommentState>(
                builder: (context, state) {
                  final count = widget.video.commentCount + _delta;
                  return Text(
                    '评论 ${formatCount(count < 0 ? 0 : count)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  );
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(ScrollController scrollController) {
    return BlocBuilder<CommentCubit, CommentState>(
      builder: (context, state) {
        if (state.loading && state.comments.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          );
        }
        if (state.error != null && state.comments.isEmpty) {
          return ErrorRetryView(
            message: state.error ?? '加载失败',
            onRetry: () => context.read<CommentCubit>().loadFirst(),
          );
        }
        if (state.comments.isEmpty) {
          return const EmptyView(
            icon: Icons.chat_bubble_outline,
            text: '还没有评论，来抢沙发吧',
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
              context.read<CommentCubit>().loadMore();
            }
            return false;
          },
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.comments.length + 1,
            itemBuilder: (context, i) {
              if (i == state.comments.length) {
                return LoadMoreFooter(
                  loading: state.loading,
                  hasMore: state.hasMore,
                );
              }
              final c = state.comments[i];
              return _CommentTile(
                comment: c,
                state: state,
                me: _me,
                isReply: false,
                onLike: () => context.read<CommentCubit>().toggleLike(c),
                onReply: () {
                  context.read<CommentCubit>().setReplyTo(c);
                  _focusNode.requestFocus();
                },
                onDelete: () => _confirmDelete(c, isReply: false),
                onToggleExpand: () =>
                    context.read<CommentCubit>().toggleExpand(c.id),
                onLoadMoreReplies: () =>
                    context.read<CommentCubit>().loadReplies(c.id),
                onReplyLike: (r) => context.read<CommentCubit>().toggleLike(r),
                onReplyDelete: (r) => _confirmDelete(r, isReply: true),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: BlocBuilder<CommentCubit, CommentState>(
        builder: (context, state) {
          final replyTo = state.replyTo;
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (replyTo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text(
                          '回复 @${replyTo.user?.displayName ?? '用户'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              context.read<CommentCubit>().setReplyTo(null),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white),
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: replyTo == null
                              ? '说点什么吧…'
                              : '回复 @${replyTo.user?.displayName ?? '用户'}…',
                          hintStyle:
                              const TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    state.submitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send,
                                color: Color(0xFFFF4D67)),
                            onPressed: _send,
                          ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 评论条目（含楼中楼）。
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.state,
    required this.me,
    required this.isReply,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onToggleExpand,
    required this.onLoadMoreReplies,
    required this.onReplyLike,
    required this.onReplyDelete,
  });

  final Comment comment;
  final CommentState state;
  final User? me;
  final bool isReply;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onToggleExpand;
  final VoidCallback onLoadMoreReplies;
  final ValueChanged<Comment> onReplyLike;
  final ValueChanged<Comment> onReplyDelete;

  bool get _isMine => me != null && me!.id == comment.userId;

  @override
  Widget build(BuildContext context) {
    final liked = state.likedIds.contains(comment.id);
    final delta = state.likeCountDelta[comment.id] ?? 0;
    final likeCount = comment.likeCount + delta;
    final author = comment.user;

    final content = InkWell(
      onLongPress: _isMine ? onDelete : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              url: author?.avatarUrl ?? '',
              name: author?.displayName ?? '',
              radius: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author?.displayName ?? '用户${comment.userId}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        formatRelativeTime(comment.createdAt),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: onReply,
                        child: const Text(
                          '回复',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      if (!isReply && comment.replyCount > 0) ...[
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: onToggleExpand,
                          child: Text(
                            state.expanded.contains(comment.id)
                                ? '收起回复'
                                : '${comment.replyCount} 条回复',
                            style: const TextStyle(
                              color: Color(0xFFFF4D67),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      if (_isMine) ...[
                        const SizedBox(width: 14),
                        const Text(
                          '长按可删除',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 点赞。
            InkWell(
              onTap: onLike,
              child: Column(
                children: [
                  Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: liked ? const Color(0xFFFF4D67) : Colors.white54,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatCount(likeCount < 0 ? 0 : likeCount),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isReply) return content;

    // 楼中楼。
    final expanded = state.expanded.contains(comment.id);
    final thread = state.replies[comment.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        if (expanded && thread != null)
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Column(
              children: [
                ...thread.items.map(
                  (r) => _CommentTile(
                    comment: r,
                    state: state,
                    me: me,
                    isReply: true,
                    onLike: () => onReplyLike(r),
                    onReply: onReply,
                    onDelete: () => onReplyDelete(r),
                    onToggleExpand: () {},
                    onLoadMoreReplies: () {},
                    onReplyLike: onReplyLike,
                    onReplyDelete: onReplyDelete,
                  ),
                ),
                if (thread.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (thread.hasMore)
                  TextButton(
                    onPressed: onLoadMoreReplies,
                    child: const Text(
                      '查看更多回复',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1, indent: 14, color: Colors.white10),
      ],
    );
  }
}
