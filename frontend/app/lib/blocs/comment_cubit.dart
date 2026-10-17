import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/comment.dart';
import '../services/services.dart';

/// 楼中楼线程状态。
class ReplyThread extends Equatable {
  const ReplyThread({
    this.items = const [],
    this.pageNum = 0,
    this.hasMore = true,
    this.loading = false,
  });

  final List<Comment> items;
  final int pageNum;
  final bool hasMore;
  final bool loading;

  ReplyThread copyWith({
    List<Comment>? items,
    int? pageNum,
    bool? hasMore,
    bool? loading,
  }) {
    return ReplyThread(
      items: items ?? this.items,
      pageNum: pageNum ?? this.pageNum,
      hasMore: hasMore ?? this.hasMore,
      loading: loading ?? this.loading,
    );
  }

  @override
  List<Object?> get props => [items, pageNum, hasMore, loading];
}

/// 评论弹窗状态。
class CommentState extends Equatable {
  const CommentState({
    this.comments = const [],
    this.pageNum = 0,
    this.hasMore = true,
    this.loading = false,
    this.submitting = false,
    this.error,
    this.replyTo,
    this.likedIds = const {},
    this.likeCountDelta = const {},
    this.replies = const {},
    this.expanded = const {},
  });

  final List<Comment> comments;
  final int pageNum;
  final bool hasMore;
  final bool loading;
  final bool submitting;
  final String? error;

  /// 当前正在回复的目标（null 表示发顶级评论）。
  final Comment? replyTo;

  /// 本地标记的已点赞评论 id（服务端无评论点赞状态查询）。
  final Set<int> likedIds;
  final Map<int, int> likeCountDelta;

  /// 楼中楼数据：父评论 id → 线程。
  final Map<int, ReplyThread> replies;

  /// 已展开楼中楼的父评论 id。
  final Set<int> expanded;

  CommentState copyWith({
    List<Comment>? comments,
    int? pageNum,
    bool? hasMore,
    bool? loading,
    bool? submitting,
    String? error,
    bool clearError = false,
    Comment? replyTo,
    bool clearReplyTo = false,
    Set<int>? likedIds,
    Map<int, int>? likeCountDelta,
    Map<int, ReplyThread>? replies,
    Set<int>? expanded,
  }) {
    return CommentState(
      comments: comments ?? this.comments,
      pageNum: pageNum ?? this.pageNum,
      hasMore: hasMore ?? this.hasMore,
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
      likedIds: likedIds ?? this.likedIds,
      likeCountDelta: likeCountDelta ?? this.likeCountDelta,
      replies: replies ?? this.replies,
      expanded: expanded ?? this.expanded,
    );
  }

  @override
  List<Object?> get props => [
        comments, pageNum, hasMore, loading, submitting, error, replyTo,
        likedIds, likeCountDelta, replies, expanded,
      ];
}

/// 评论域 Cubit：分页列表、楼中楼、发表/删除、评论点赞。
class CommentCubit extends Cubit<CommentState> {
  CommentCubit(this._videoId) : super(const CommentState());

  final int _videoId;

  /// 首次加载。
  Future<void> loadFirst() async {
    if (state.loading) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final page =
          await Services.comment.comments(videoId: _videoId, pageNum: 1);
      emit(
        state.copyWith(
          comments: page.items,
          pageNum: 1,
          hasMore: page.hasMore,
          loading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    }
  }

  /// 加载更多。
  Future<void> loadMore() async {
    final s = state;
    if (s.loading || !s.hasMore) return;
    emit(s.copyWith(loading: true));
    try {
      final page = await Services.comment.comments(
        videoId: _videoId,
        pageNum: s.pageNum + 1,
      );
      emit(
        state.copyWith(
          comments: [...state.comments, ...page.items],
          pageNum: s.pageNum + 1,
          hasMore: page.hasMore,
          loading: false,
        ),
      );
    } on ApiException {
      emit(state.copyWith(loading: false));
    }
  }

  /// 展开 / 收起楼中楼（首次展开时拉取第一页）。
  Future<void> toggleExpand(int commentId) async {
    final s = state;
    if (s.expanded.contains(commentId)) {
      emit(
        s.copyWith(
          expanded: s.expanded.difference({commentId}),
        ),
      );
      return;
    }
    emit(s.copyWith(expanded: {...s.expanded, commentId}));
    if (!s.replies.containsKey(commentId)) {
      await loadReplies(commentId, refresh: true);
    }
  }

  /// 拉取楼中楼（refresh=true 重置）。
  Future<void> loadReplies(int commentId, {bool refresh = false}) async {
    final s = state;
    final thread = s.replies[commentId] ?? const ReplyThread();
    if (thread.loading) return;
    if (!refresh && !thread.hasMore) return;
    emit(
      s.copyWith(
        replies: {
          ...s.replies,
          commentId: thread.copyWith(loading: true),
        },
      ),
    );
    try {
      final pageNum = refresh ? 1 : thread.pageNum + 1;
      final page = await Services.comment.replies(
        commentId: commentId,
        pageNum: pageNum,
      );
      final cur = state.replies[commentId] ?? const ReplyThread();
      emit(
        state.copyWith(
          replies: {
            ...state.replies,
            commentId: cur.copyWith(
              items: refresh
                  ? page.items
                  : [...cur.items, ...page.items],
              pageNum: pageNum,
              hasMore: page.hasMore,
              loading: false,
            ),
          },
        ),
      );
    } on ApiException {
      final cur = state.replies[commentId] ?? const ReplyThread();
      emit(
        state.copyWith(
          replies: {
            ...state.replies,
            commentId: cur.copyWith(loading: false),
          },
        ),
      );
    }
  }

  /// 发表评论（顶级或回复）。
  ///
  /// 返回 true 表示成功；游客由 UI 层先做登录引导，不会走到这里。
  Future<bool> submit(String content) async {
    final s = state;
    if (content.trim().isEmpty || s.submitting) return false;
    emit(s.copyWith(submitting: true, clearError: true));
    try {
      final c = await Services.comment.post(
        _videoId,
        content.trim(),
        parentId: s.replyTo?.id,
      );
      if (s.replyTo == null) {
        // 顶级评论插入列表头。
        emit(
          state.copyWith(
            comments: [c, ...state.comments],
            submitting: false,
            clearReplyTo: true,
          ),
        );
      } else {
        final parentId = s.replyTo!.id;
        final thread = state.replies[parentId] ?? const ReplyThread();
        // 更新父评论回复数，并插入楼中楼。
        emit(
          state.copyWith(
            comments: state.comments
                .map(
                  (e) => e.id == parentId
                      ? e.copyWith(replyCount: e.replyCount + 1)
                      : e,
                )
                .toList(),
            replies: {
              ...state.replies,
              parentId: thread.copyWith(
                items: [c, ...thread.items],
              ),
            },
            submitting: false,
            clearReplyTo: true,
          ),
        );
      }
      // 埋点：评论（静默）。
      Services.uba.report(
        UbaEvent(eventType: UbaEventType.comment, videoId: _videoId),
      );
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(submitting: false, error: e.message));
      return false;
    }
  }

  /// 删除自己的评论。isReply=false 删除顶级评论，否则从楼中楼移除。
  Future<bool> delete(Comment c, {bool isReply = false}) async {
    try {
      await Services.comment.delete(c.id);
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.isReason('NOT_OWNER') ? '只能删除自己的评论' : e.message));
      return false;
    }
    final s = state;
    if (isReply && c.parentId != null) {
      final parentId = c.parentId!;
      final thread = s.replies[parentId] ?? const ReplyThread();
      emit(
        s.copyWith(
          replies: {
            ...s.replies,
            parentId: thread.copyWith(
              items: thread.items.where((e) => e.id != c.id).toList(),
            ),
          },
          comments: s.comments
              .map(
                (e) => e.id == parentId
                    ? e.copyWith(
                        replyCount: e.replyCount > 0 ? e.replyCount - 1 : 0,
                      )
                    : e,
              )
              .toList(),
        ),
      );
    } else {
      emit(
        s.copyWith(
          comments: s.comments.where((e) => e.id != c.id).toList(),
        ),
      );
    }
    return true;
  }

  /// 评论点赞 / 取消（targetType=2）。
  Future<void> toggleLike(Comment c) async {
    if (!Services.tokens.hasToken) return;
    final s = state;
    final liked = s.likedIds.contains(c.id);
    emit(
      s.copyWith(
        likedIds: liked
            ? s.likedIds.difference({c.id})
            : {...s.likedIds, c.id},
        likeCountDelta: {
          ...s.likeCountDelta,
          c.id: (s.likeCountDelta[c.id] ?? 0) + (liked ? -1 : 1),
        },
      ),
    );
    try {
      if (liked) {
        await Services.interaction.unlike(2, c.id);
      } else {
        await Services.interaction.like(2, c.id);
      }
    } on ApiException {
      // 回滚。
      emit(
        state.copyWith(
          likedIds: liked
              ? {...state.likedIds, c.id}
              : state.likedIds.difference({c.id}),
          likeCountDelta: {
            ...state.likeCountDelta,
            c.id: state.likeCountDelta[c.id] ?? 0,
          },
        ),
      );
    }
  }

  void setReplyTo(Comment? c) =>
      emit(state.copyWith(replyTo: c, clearReplyTo: c == null));
}
