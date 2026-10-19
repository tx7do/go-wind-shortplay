import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/features/comment/models/comment.dart';
import 'package:shortplay_app/src/features/comment/services/comment_service.dart';
import 'package:shortplay_app/src/features/common/services/uba_service.dart';

/// 评论事件
sealed class CommentEvent extends Equatable {
  const CommentEvent();

  @override
  List<Object?> get props => [];
}

/// 加载评论列表（重置）
class CommentListRequested extends CommentEvent {
  final int videoId;

  const CommentListRequested(this.videoId);

  @override
  List<Object?> get props => [videoId];
}

/// 加载更多
class CommentNextPageRequested extends CommentEvent {
  const CommentNextPageRequested();
}

/// 评论本地插入（发表成功后由 [CommentBloc.postComment] 触发）
class CommentLocallyInserted extends CommentEvent {
  final Comment created;
  final Comment? parent;

  const CommentLocallyInserted(this.created, this.parent);

  @override
  List<Object?> get props => [created, parent];
}

/// 删除自己的评论
class CommentDeleted extends CommentEvent {
  final Comment comment;

  const CommentDeleted(this.comment);

  @override
  List<Object?> get props => [comment];
}

/// 评论点赞切换
class CommentLikeToggled extends CommentEvent {
  final Comment comment;

  const CommentLikeToggled(this.comment);

  @override
  List<Object?> get props => [comment];
}

/// 展开楼中楼
class CommentRepliesRequested extends CommentEvent {
  final Comment comment;

  const CommentRepliesRequested(this.comment);

  @override
  List<Object?> get props => [comment];
}

/// 评论状态
class CommentState extends Equatable {
  final int videoId;
  final List<Comment> comments;
  final int total;
  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;

  const CommentState({
    this.videoId = 0,
    this.comments = const [],
    this.total = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.errorMessage,
  });

  CommentState copyWith({
    int? videoId,
    List<Comment>? comments,
    int? total,
    bool? isLoading,
    bool? hasMore,
    String? errorMessage,
  }) {
    return CommentState(
      videoId: videoId ?? this.videoId,
      comments: comments ?? this.comments,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [videoId, comments, total, isLoading, hasMore, errorMessage];
}

/// 评论业务
class CommentBloc extends Bloc<CommentEvent, CommentState> {
  CommentBloc({CommentService? commentService, UbaService? ubaService})
      : _service = commentService ?? CommentService(),
        _uba = ubaService ?? UbaService(),
        super(const CommentState()) {
    on<CommentListRequested>(_onList);
    on<CommentNextPageRequested>(_onNextPage);
    on<CommentLocallyInserted>(_onLocallyInserted);
    on<CommentDeleted>(_onDeleted);
    on<CommentLikeToggled>(_onLikeToggled);
    on<CommentRepliesRequested>(_onReplies);
  }

  final CommentService _service;
  final UbaService _uba;

  int _pageNum = 1;
  static const int _pageSize = 10;

  Future<void> _onList(
    CommentListRequested event,
    Emitter<CommentState> emit,
  ) async {
    emit(state.copyWith(
      videoId: event.videoId,
      isLoading: true,
      errorMessage: null,
    ));
    try {
      _pageNum = 1;
      final page = await _service.list(
        videoId: event.videoId,
        query: const PaginationQuery(pageNum: 1, pageSize: _pageSize),
      );
      emit(state.copyWith(
        comments: page.items,
        total: page.total,
        isLoading: false,
        hasMore: page.items.length < page.total,
      ));
    } on ApiStatusException catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: localizedErrorText(S.current, e),
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: localizedErrorText(S.current, e),
      ));
    }
  }

  Future<void> _onNextPage(
    CommentNextPageRequested event,
    Emitter<CommentState> emit,
  ) async {
    if (state.isLoading || !state.hasMore || state.videoId <= 0) return;
    emit(state.copyWith(isLoading: true));
    try {
      _pageNum += 1;
      final page = await _service.list(
        videoId: state.videoId,
        query: PaginationQuery(pageNum: _pageNum, pageSize: _pageSize),
      );
      emit(state.copyWith(
        comments: [...state.comments, ...page.items],
        isLoading: false,
        hasMore: state.comments.length + page.items.length < page.total,
      ));
    } catch (_) {
      _pageNum -= 1;
      emit(state.copyWith(isLoading: false));
    }
  }

  /// 发表评论（公开方法，UI 层可 await 完成以便提示；成功后本地插入）
  Future<void> postComment({
    required String content,
    Comment? parent,
  }) async {
    final created = await _service.create(
      videoId: state.videoId,
      content: content,
      parentId: parent?.id ?? 0,
    );
    _uba.report(UbaEvent(
      eventType: UbaEventType.commentCreate,
      videoId: state.videoId,
    ));
    add(CommentLocallyInserted(created, parent));
  }

  void _onLocallyInserted(
    CommentLocallyInserted event,
    Emitter<CommentState> emit,
  ) {
    final parent = event.parent;
    final created = event.created;

    if (parent == null) {
      // 一级评论：插到最前
      emit(state.copyWith(
        comments: [created, ...state.comments],
        total: state.total + 1,
      ));
      return;
    }

    // 楼中楼：填充到父评论
    final comments = state.comments.map((c) {
      if (c.id != parent.id) return c;
      return c.copyWith(
        replies: [...c.replies, created],
        replyCount: c.replyCount + 1,
      );
    }).toList();
    emit(state.copyWith(comments: comments));
  }

  Future<void> _onDeleted(
    CommentDeleted event,
    Emitter<CommentState> emit,
  ) async {
    final target = event.comment;
    if (target.isReply) {
      // 楼中楼：从父评论中移除
      final comments = state.comments.map((c) {
        final replyIndex = c.replies.indexWhere((r) => r.id == target.id);
        if (replyIndex < 0) return c;
        final replies = [...c.replies]..removeAt(replyIndex);
        return c.copyWith(
          replies: replies,
          replyCount: (c.replyCount - 1).clamp(0, 1 << 31),
        );
      }).toList();
      await _service.delete(target.id);
      emit(state.copyWith(comments: comments));
      return;
    }

    await _service.delete(target.id);
    final comments =
        state.comments.where((c) => c.id != target.id).toList();
    emit(state.copyWith(
      comments: comments,
      total: (state.total - 1).clamp(0, 1 << 31),
    ));
  }

  Future<void> _onLikeToggled(
    CommentLikeToggled event,
    Emitter<CommentState> emit,
  ) async {
    final target = event.comment;

    // 本地乐观更新（点赞/取消各切换一次；失败时再调一次即回滚）
    void updateLocal() {
      List<Comment> mapList(List<Comment> list) => list.map((c) {
            if (c.id == target.id) {
              return c.copyWith(
                liked: !c.liked,
                likeCount:
                    c.likeCount + (c.liked ? -1 : 1),
              );
            }
            if (c.replies.any((r) => r.id == target.id)) {
              return c.copyWith(
                replies: c.replies
                    .map((r) => r.id == target.id
                        ? r.copyWith(
                            liked: !r.liked,
                            likeCount: r.likeCount + (r.liked ? -1 : 1),
                          )
                        : r)
                    .toList(),
              );
            }
            return c;
          }).toList();

      emit(state.copyWith(comments: mapList(state.comments)));
    }

    updateLocal();
    try {
      if (target.liked) {
        await _service.unlike(target.id);
      } else {
        await _service.like(target.id);
      }
    } catch (_) {
      // 失败回滚
      updateLocal();
    }
  }

  Future<void> _onReplies(
    CommentRepliesRequested event,
    Emitter<CommentState> emit,
  ) async {
    final target = event.comment;
    if (target.replies.isNotEmpty || target.replyCount <= 0) return;
    try {
      final page = await _service.replies(
        commentId: target.id,
        query: const PaginationQuery(pageNum: 1, pageSize: 50),
      );
      final comments = state.comments.map((c) {
        if (c.id != target.id) return c;
        return c.copyWith(replies: page.items);
      }).toList();
      emit(state.copyWith(comments: comments));
    } catch (_) {
      // 楼中楼加载失败静默，用户可重试
    }
  }
}
