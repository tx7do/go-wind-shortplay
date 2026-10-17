import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/notification.dart';
import '../services/services.dart';

/// 消息中心状态。
class NotifyState extends Equatable {
  const NotifyState({
    this.items = const [],
    this.pageNum = 0,
    this.hasMore = true,
    this.unreadCount = 0,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<AppNotification> items;
  final int pageNum;
  final bool hasMore;
  final int unreadCount;
  final bool loading;
  final bool loadingMore;
  final String? error;

  NotifyState copyWith({
    List<AppNotification>? items,
    int? pageNum,
    bool? hasMore,
    int? unreadCount,
    bool clearUnread = false,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) {
    return NotifyState(
      items: items ?? this.items,
      pageNum: pageNum ?? this.pageNum,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: clearUnread ? 0 : (unreadCount ?? this.unreadCount),
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        items, pageNum, hasMore, unreadCount, loading, loadingMore, error,
      ];
}

/// 消息域 Cubit：通知列表 / 未读角标 / 已读。
class NotifyCubit extends Cubit<NotifyState> {
  NotifyCubit() : super(const NotifyState());

  /// 刷新列表与未读数。
  Future<void> refresh() async {
    if (state.loading) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final result = await Services.notification.list(pageNum: 1);
      emit(
        state.copyWith(
          items: result.page.items,
          pageNum: 1,
          hasMore: result.page.hasMore,
          unreadCount: result.unreadCount,
          loading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    }
  }

  /// 仅刷新未读数（角标）。
  Future<void> refreshUnreadCount() async {
    if (!Services.tokens.hasToken) return;
    try {
      final count = await Services.notification.unreadCount();
      emit(state.copyWith(unreadCount: count));
    } on ApiException {
      // 角标拉取失败静默。
    }
  }

  /// 加载更多。
  Future<void> loadMore() async {
    final s = state;
    if (s.loading || s.loadingMore || !s.hasMore) return;
    emit(s.copyWith(loadingMore: true));
    try {
      final result = await Services.notification.list(pageNum: s.pageNum + 1);
      emit(
        state.copyWith(
          items: [...state.items, ...result.page.items],
          pageNum: s.pageNum + 1,
          hasMore: result.page.hasMore,
          loadingMore: false,
        ),
      );
    } on ApiException {
      emit(state.copyWith(loadingMore: false));
    }
  }

  /// 标记单条已读。
  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      await Services.notification.markRead([n.id]);
      emit(
        state.copyWith(
          items: state.items
              .map((e) => e.id == n.id ? _withRead(e) : e)
              .toList(),
          unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
        ),
      );
    } on ApiException {
      // 已读失败静默。
    }
  }

  /// 全部已读。
  Future<void> markAllRead() async {
    if (state.unreadCount == 0) return;
    try {
      await Services.notification.markAllRead();
      emit(
        state.copyWith(
          items: state.items.map(_withRead).toList(),
          clearUnread: true,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  /// 退出登录时清空。
  void reset() => emit(const NotifyState());

  static AppNotification _withRead(AppNotification n) =>
      AppNotification(
        id: n.id,
        type: n.type,
        sender: n.sender,
        videoId: n.videoId,
        commentId: n.commentId,
        content: n.content,
        isRead: true,
        createdAt: n.createdAt,
      );
}
