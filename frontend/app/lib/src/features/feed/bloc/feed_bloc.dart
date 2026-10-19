import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart'
    show ApiStatusException, localizedErrorText;
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/feed/services/feed_service.dart';

/// Feed 事件
sealed class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

/// 刷新（下拉 / 首次加载）
class FeedRefreshed extends FeedEvent {
  const FeedRefreshed();
}

/// 加载下一页
class FeedNextPageRequested extends FeedEvent {
  const FeedNextPageRequested();
}

/// 刷新指定位置的视频（互动/删除后同步）
class FeedVideoReplaced extends FeedEvent {
  final int videoId;
  final Video? video; // null 表示移除

  const FeedVideoReplaced(this.videoId, this.video);

  @override
  List<Object?> get props => [videoId, video];
}

/// Feed 状态
class FeedState extends Equatable {
  final List<FeedItem> items;
  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;
  final bool reachedEnd;

  const FeedState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.errorMessage,
    this.reachedEnd = false,
  });

  FeedState copyWith({
    List<FeedItem>? items,
    bool? isLoading,
    bool? hasMore,
    String? errorMessage,
    bool? reachedEnd,
  }) {
    return FeedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
      reachedEnd: reachedEnd ?? this.reachedEnd,
    );
  }

  @override
  List<Object?> get props =>
      [items, isLoading, hasMore, errorMessage, reachedEnd];
}

/// Feed 业务
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({FeedService? feedService})
      : _feedService = feedService ?? FeedService(),
        super(const FeedState()) {
    on<FeedRefreshed>(_onRefreshed);
    on<FeedNextPageRequested>(_onNextPage);
    on<FeedVideoReplaced>(_onVideoReplaced);
  }

  final FeedService _feedService;

  int _pageNum = 1;

  Future<void> _onRefreshed(
    FeedRefreshed event,
    Emitter<FeedState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      _pageNum = 1;
      final page = await _feedService.feed(
        query: const PaginationQuery(pageNum: 1),
      );
      emit(state.copyWith(
        items: page.items,
        isLoading: false,
        hasMore: page.hasMore,
        reachedEnd: page.items.isEmpty,
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
    FeedNextPageRequested event,
    Emitter<FeedState> emit,
  ) async {
    if (state.isLoading || !state.hasMore) return;
    emit(state.copyWith(isLoading: true));
    try {
      _pageNum += 1;
      final page = await _feedService.feed(
        query: PaginationQuery(pageNum: _pageNum),
      );
      final merged = [...state.items, ...page.items];
      emit(state.copyWith(
        items: merged,
        isLoading: false,
        hasMore: page.hasMore,
        reachedEnd: !page.hasMore,
      ));
    } catch (e) {
      _pageNum -= 1;
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onVideoReplaced(
    FeedVideoReplaced event,
    Emitter<FeedState> emit,
  ) {
    final items = [...state.items];
    final index = items.indexWhere((item) => item.video.id == event.videoId);
    if (index < 0) return;

    if (event.video == null) {
      items.removeAt(index);
    } else {
      items[index] = FeedItem(
        video: event.video!,
        reason: items[index].reason,
      );
    }
    emit(state.copyWith(items: items));
  }
}
