import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart'
    show ApiStatusException;
import 'package:shortplay_app/src/features/comment/bloc/comment_bloc.dart';
import 'package:shortplay_app/src/features/comment/models/comment.dart';
import 'package:shortplay_app/src/features/common/widgets/login_guard.dart';
import 'package:shortplay_app/src/features/common/widgets/user_avatar.dart';
import 'package:get_it/get_it.dart' show GetIt;

/// 底部弹出的评论面板（含楼中楼）
///
/// 用法：
/// ```dart
/// await showCommentSheet(context, videoId: video.id);
/// ```
Future<void> showCommentSheet(
  BuildContext context, {
  required int videoId,
  ValueChanged<int>? onCommentCountChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    // 桌面宽窗下收窄居中（手机端无感）
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) {
      return BlocProvider(
        create: (_) => CommentBloc()..add(CommentListRequested(videoId)),
        child: CommentSheet(
          onCommentCountChanged: onCommentCountChanged,
        ),
      );
    },
  );
}

class CommentSheet extends StatefulWidget {
  final ValueChanged<int>? onCommentCountChanged;

  const CommentSheet({super.key, this.onCommentCountChanged});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  Comment? _replyTarget;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      context.read<CommentBloc>().add(const CommentNextPageRequested());
    }
  }

  void _setReplyTarget(Comment? comment) {
    setState(() => _replyTarget = comment);
  }

  Future<void> _submit() async {
    final content = _inputController.text.trim();
    final loc = S.of(context);
    if (content.isEmpty) {
      EasyLoading.showToast(loc.commentIsEmpty);
      return;
    }
    if (!await ensureLogin(context) || !mounted) return;

    final parent = _replyTarget;
    try {
      await context.read<CommentBloc>().postComment(
            content: content,
            parent: parent,
          );
      if (!mounted) return;
      _inputController.clear();
      _setReplyTarget(null);
      if (parent == null) {
        widget.onCommentCountChanged?.call(1);
      }
      EasyLoading.showToast(loc.commentSuccess);
    } on ApiStatusException catch (e) {
      EasyLoading.showToast(
        localizedCommentError(context, e) ?? loc.errorDefault,
      );
    } catch (_) {
      EasyLoading.showToast(loc.errorDefault);
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final loc = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.delete),
        content: Text(loc.deleteCommentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<CommentBloc>().add(CommentDeleted(comment));
    if (!comment.isReply) {
      widget.onCommentCountChanged?.call(-1);
    }
  }

  Future<void> _toggleLike(Comment comment) async {
    if (!await ensureLogin(context)) return;
    if (!mounted) return;
    context.read<CommentBloc>().add(CommentLikeToggled(comment));
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return BlocConsumer<CommentBloc, CommentState>(
      listener: (context, state) {
        // 错误处理在动作层完成，这里仅兜底列表错误
      },
      builder: (context, state) {
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽把手
              Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(top: 10.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(40),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              SizedBox(height: 10.h),
              // 标题
              Text(
                loc.commentsCount(state.total),
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8.h),
              Divider(height: 1, color: theme.dividerColor),
              // 列表
              Flexible(child: _buildList(context, state, loc, theme)),
              Divider(height: 1, color: theme.dividerColor),
              // 输入栏
              SafeArea(
                top: false,
                child: _buildInputBar(context, loc, theme),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    CommentState state,
    S loc,
    ThemeData theme,
  ) {
    if (state.isLoading && state.comments.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(40.h),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (state.errorMessage != null && state.comments.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(32.h),
        child: Center(
          child: Text(
            state.errorMessage!,
            style: TextStyle(
              fontSize: 13.sp,
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
        ),
      );
    }
    if (state.comments.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(40.h),
        child: Center(
          child: Text(
            loc.noCommentsYet,
            style: TextStyle(
              fontSize: 13.sp,
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: state.comments.length,
      itemBuilder: (context, index) {
        final comment = state.comments[index];
        return _CommentTile(
          comment: comment,
          currentUserId: GetIt.instance<UserAuthCache>().userId,
          onReply: () => _setReplyTarget(comment),
          onLike: () => _toggleLike(comment),
          onDelete: () => _deleteComment(comment),
        );
      },
    );
  }

  Widget _buildInputBar(
    BuildContext context,
    S loc,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: _replyTarget != null
                    ? loc.replyTo(_replyTarget!.user.nickname)
                    : loc.writeComment,
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.r),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
            ),
          ),
          SizedBox(width: 8.w),
          // 渐变圆形发送按钮
          GestureDetector(
            onTap: _submit,
            child: Semantics(
              label: loc.confirmSend,
              button: true,
              child: Container(
                width: 36.r,
                height: 36.r,
                decoration: const BoxDecoration(
                  gradient: BrandColor.gradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  size: 17.r,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 评论条目（含楼中楼）
class _CommentTile extends StatelessWidget {
  final Comment comment;
  final int currentUserId;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);
    final isMine = currentUserId > 0 && comment.userId == currentUserId;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar.fromBrief(comment.user, radius: 16),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.user.nickname,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withAlpha(160),
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      comment.content,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Text(
                          _formatTime(loc, comment.createdAt),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: theme.colorScheme.onSurface.withAlpha(110),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        GestureDetector(
                          onTap: onReply,
                          child: Text(
                            loc.reply,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ),
                        if (isMine) ...[
                          SizedBox(width: 16.w),
                          GestureDetector(
                            onTap: onDelete,
                            child: Text(
                              loc.delete,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // 点赞
              GestureDetector(
                onTap: onLike,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  child: Column(
                    children: [
                      Icon(
                        comment.liked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 16.sp,
                        color:
                            comment.liked ? theme.colorScheme.error : null,
                      ),
                      if (comment.likeCount > 0)
                        Text(
                          '${comment.likeCount}',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: theme.colorScheme.onSurface.withAlpha(130),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 楼中楼
          if (comment.replyCount > 0 || comment.replies.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 42.w, top: 6.h),
              child: _RepliesSection(
                comment: comment,
                currentUserId: currentUserId,
                onReply: onReply,
                onLike: onLike,
                onDelete: onDelete,
              ),
            ),
        ],
      ),
    );
  }
}

/// 楼中楼区域
class _RepliesSection extends StatefulWidget {
  final Comment comment;
  final int currentUserId;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  const _RepliesSection({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
  });

  @override
  State<_RepliesSection> createState() => _RepliesSectionState();
}

class _RepliesSectionState extends State<_RepliesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);
    final comment = widget.comment;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_expanded)
            GestureDetector(
              onTap: () {
                context
                    .read<CommentBloc>()
                    .add(CommentRepliesRequested(comment));
                setState(() => _expanded = true);
              },
              child: Text(
                loc.expandReplies(comment.replyCount),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            )
          else
            ...comment.replies.map(
              (reply) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: _ReplyTile(
                  reply: reply,
                  currentUserId: widget.currentUserId,
                  onReply: widget.onReply,
                  onLike: widget.onLike,
                  onDelete: widget.onDelete,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  final Comment reply;
  final int currentUserId;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  const _ReplyTile({
    required this.reply,
    required this.currentUserId,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);
    final isMine = currentUserId > 0 && reply.userId == currentUserId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar.fromBrief(reply.user, radius: 11),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reply.user.nickname,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                reply.content,
                style: TextStyle(fontSize: 13.sp),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Text(
                    _formatTime(loc, reply.createdAt),
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: onReply,
                    child: Text(
                      loc.reply,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                    ),
                  ),
                  if (isMine) ...[
                    SizedBox(width: 12.w),
                    GestureDetector(
                      onTap: onDelete,
                      child: Text(
                        loc.delete,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onLike,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Icon(
              reply.liked ? Icons.favorite : Icons.favorite_border,
              size: 13.sp,
              color: reply.liked ? theme.colorScheme.error : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// 相对时间
String _formatTime(S loc, DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return loc.timeJustNow;
  if (diff.inMinutes < 60) return loc.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return loc.timeHoursAgo(diff.inHours);
  if (diff.inDays < 30) return loc.timeDaysAgo(diff.inDays);
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}

/// 评论错误转提示（403 NOT_OWNER 等）
String? localizedCommentError(BuildContext context, ApiStatusException e) {
  final loc = S.of(context);
  switch (e.status.getReason) {
    case 'NOT_OWNER':
      return loc.onlyOwnerCanDelete;
    default:
      return null;
  }
}
