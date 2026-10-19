import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/features/notify/models/notification.dart';
import 'package:shortplay_app/src/features/notify/services/notification_service.dart';

/// 通知事件
sealed class NotifyEvent extends Equatable {
  const NotifyEvent();

  @override
  List<Object?> get props => [];
}

/// 刷新列表（重置）
class NotifyRefreshed extends NotifyEvent {
  final bool unreadOnly;

  const NotifyRefreshed({this.unreadOnly = false});

  @override
  List<Object?> get props => [unreadOnly];
}

/// 加载更多
class NotifyNextPageRequested extends NotifyEvent {
  const NotifyNextPageRequested();
}

/// 只看未读切换
class NotifyUnreadOnlyToggled extends NotifyEvent {
  const NotifyUnreadOnlyToggled();
}

/// 标记单条已读
class NotifyMarkedRead extends NotifyEvent {
  final NotificationItem item;

  const NotifyMarkedRead(this.item);

  @override
  List<Object?> get props => [item];
}

/// 全部已读
class NotifyAllMarkedRead extends NotifyEvent {
  const NotifyAllMarkedRead();
}

/// 未读数刷新（Tab 角标）
class NotifyUnreadCountRefreshed extends NotifyEvent {
  const NotifyUnreadCountRefreshed();
}

/// 通知状态
class NotifyState extends Equatable {
  final List<NotificationItem> items;
  final int unreadCount;
  final bool unreadOnly;
  final bool isLoading;
  final bool hasMore;
  final bool requireLogin;
  final String? errorMessage;

  const NotifyState({
    this.items = const [],
    this.unreadCount = 0,
    this.unreadOnly = false,
    this.isLoading = false,
    this.hasMore = true,
    this.requireLogin = false,
    this.errorMessage,
  });

  NotifyState copyWith({
    List<NotificationItem>? items,
    int? unreadCount,
    bool? unreadOnly,
    bool? isLoading,
    bool? hasMore,
    bool? requireLogin,
    String? errorMessage,
  }) {
    return NotifyState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      requireLogin: requireLogin ?? this.requireLogin,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        items,
        unreadCount,
        unreadOnly,
        isLoading,
        hasMore,
        requireLogin,
        errorMessage,
      ];
}

/// 通知业务（含底部导航「消息」Tab 未读角标）
class NotifyBloc extends Bloc<NotifyEvent, NotifyState> {
  NotifyBloc({NotificationService? notificationService})
      : _service = notificationService ?? NotificationService(),
        super(const NotifyState()) {
    on<NotifyRefreshed>(_onRefreshed);
    on<NotifyNextPageRequested>(_onNextPage);
    on<NotifyUnreadOnlyToggled>(_onUnreadOnlyToggled);
    on<NotifyMarkedRead>(_onMarkedRead);
    on<NotifyAllMarkedRead>(_onAllMarkedRead);
    on<NotifyUnreadCountRefreshed>(_onUnreadCountRefreshed);

    // 创建时刷一次未读数（Tab 角标）
    add(const NotifyUnreadCountRefreshed());
  }

  final NotificationService _service;

  int _pageNum = 1;
  static const int _pageSize = 10;

  bool get _hasLogin => GetIt.instance<UserAuthCache>().hasLogin;

  Future<void> _onRefreshed(
    NotifyRefreshed event,
    Emitter<NotifyState> emit,
  ) async {
    if (!_hasLogin) {
      emit(state.copyWith(
        requireLogin: true,
        items: [],
        unreadCount: 0,
        isLoading: false,
        hasMore: false,
      ));
      return;
    }
    emit(state.copyWith(
      isLoading: true,
      requireLogin: false,
      unreadOnly: event.unreadOnly,
      errorMessage: null,
    ));
    try {
      _pageNum = 1;
      final page = await _service.list(
        page: 1,
        pageSize: _pageSize,
        unreadOnly: event.unreadOnly,
      );
      add(const NotifyUnreadCountRefreshed());
      emit(state.copyWith(
        items: page.items,
        isLoading: false,
        hasMore: page.items.length < page.total,
      ));
    } on ApiStatusException catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: localizedErrorText(S.current, e),
        requireLogin: e.status.code == 401,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: localizedErrorText(S.current, e),
      ));
    }
  }

  Future<void> _onNextPage(
    NotifyNextPageRequested event,
    Emitter<NotifyState> emit,
  ) async {
    if (state.isLoading || !state.hasMore || !_hasLogin) return;
    emit(state.copyWith(isLoading: true));
    try {
      _pageNum += 1;
      final page = await _service.list(
        page: _pageNum,
        pageSize: _pageSize,
        unreadOnly: state.unreadOnly,
      );
      emit(state.copyWith(
        items: [...state.items, ...page.items],
        isLoading: false,
        hasMore: state.items.length + page.items.length < page.total,
      ));
    } catch (_) {
      _pageNum -= 1;
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onUnreadOnlyToggled(
    NotifyUnreadOnlyToggled event,
    Emitter<NotifyState> emit,
  ) async {
    add(NotifyRefreshed(unreadOnly: !state.unreadOnly));
  }

  Future<void> _onMarkedRead(
    NotifyMarkedRead event,
    Emitter<NotifyState> emit,
  ) async {
    final item = event.item;
    if (item.isRead) return;
    await _service.markRead([item.id]);
    final items = state.items
        .map((e) => e.id == item.id ? e.markRead() : e)
        .toList();
    emit(state.copyWith(
      items: items,
      unreadCount: (state.unreadCount - 1).clamp(0, 1 << 31),
    ));
  }

  Future<void> _onAllMarkedRead(
    NotifyAllMarkedRead event,
    Emitter<NotifyState> emit,
  ) async {
    await _service.markAllRead();
    emit(state.copyWith(
      items: state.items.map((e) => e.markRead()).toList(),
      unreadCount: 0,
    ));
  }

  Future<void> _onUnreadCountRefreshed(
    NotifyUnreadCountRefreshed event,
    Emitter<NotifyState> emit,
  ) async {
    if (!_hasLogin) {
      if (state.unreadCount != 0) {
        emit(state.copyWith(unreadCount: 0));
      }
      return;
    }
    try {
      final count = await _service.unreadCount();
      if (count != state.unreadCount) {
        emit(state.copyWith(unreadCount: count));
      }
    } catch (_) {
      // 角标刷新失败静默
    }
  }
}
