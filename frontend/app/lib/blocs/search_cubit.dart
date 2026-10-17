import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/video.dart';
import '../services/services.dart';

/// 搜索状态。
class SearchState extends Equatable {
  const SearchState({
    this.keyword = '',
    this.results = const [],
    this.pageNum = 0,
    this.hasMore = true,
    this.searching = false,
    this.searched = false,
    this.error,
  });

  final String keyword;
  final List<Video> results;
  final int pageNum;
  final bool hasMore;
  final bool searching;

  /// 是否已执行过搜索（区分初始空态与无结果空态）。
  final bool searched;
  final String? error;

  SearchState copyWith({
    String? keyword,
    List<Video>? results,
    int? pageNum,
    bool? hasMore,
    bool? searching,
    bool? searched,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      keyword: keyword ?? this.keyword,
      results: results ?? this.results,
      pageNum: pageNum ?? this.pageNum,
      hasMore: hasMore ?? this.hasMore,
      searching: searching ?? this.searching,
      searched: searched ?? this.searched,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        keyword, results, pageNum, hasMore, searching, searched, error,
      ];
}

/// 搜索域 Cubit。
class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(const SearchState());

  /// 执行搜索（回车触发）。
  Future<void> search(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty || state.searching) return;
    emit(
      SearchState(keyword: kw, searching: true, searched: false),
    );
    try {
      final page = await Services.feed.searchVideos(keyword: kw, pageNum: 1);
      emit(
        state.copyWith(
          results: page.items,
          pageNum: 1,
          hasMore: page.hasMore,
          searching: false,
          searched: true,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          searching: false,
          searched: true,
          error: e.message,
        ),
      );
    }
  }

  /// 加载更多。
  Future<void> loadMore() async {
    final s = state;
    if (s.searching || !s.searched || !s.hasMore || s.keyword.isEmpty) {
      return;
    }
    emit(s.copyWith(searching: true));
    try {
      final page = await Services.feed.searchVideos(
        keyword: s.keyword,
        pageNum: s.pageNum + 1,
      );
      emit(
        state.copyWith(
          results: [...state.results, ...page.items],
          pageNum: s.pageNum + 1,
          hasMore: page.hasMore,
          searching: false,
        ),
      );
    } on ApiException {
      emit(state.copyWith(searching: false));
    }
  }
}
