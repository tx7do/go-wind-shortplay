import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/common.dart';
import '../models/user.dart';
import '../models/video.dart';
import '../services/services.dart';

/// 「我的」页状态。
class ProfileState extends Equatable {
  const ProfileState({
    this.user,
    this.stats,
    this.overview,
    this.videos = const [],
    this.videosPageNum = 0,
    this.videosHasMore = true,
    this.collects = const [],
    this.collectsPageNum = 0,
    this.collectsHasMore = true,
    this.loading = false,
    this.videosLoadingMore = false,
    this.collectsLoadingMore = false,
    this.error,
  });

  final User? user;
  final UserStats? stats;
  final CreatorOverview? overview;

  final List<Video> videos;
  final int videosPageNum;
  final bool videosHasMore;
  final bool videosLoadingMore;

  final List<Video> collects;
  final int collectsPageNum;
  final bool collectsHasMore;
  final bool collectsLoadingMore;

  final bool loading;
  final String? error;

  ProfileState copyWith({
    User? user,
    bool clearUser = false,
    UserStats? stats,
    CreatorOverview? overview,
    List<Video>? videos,
    int? videosPageNum,
    bool? videosHasMore,
    List<Video>? collects,
    int? collectsPageNum,
    bool? collectsHasMore,
    bool? loading,
    bool? videosLoadingMore,
    bool? collectsLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return ProfileState(
      user: clearUser ? null : (user ?? this.user),
      stats: stats ?? this.stats,
      overview: overview ?? this.overview,
      videos: videos ?? this.videos,
      videosPageNum: videosPageNum ?? this.videosPageNum,
      videosHasMore: videosHasMore ?? this.videosHasMore,
      collects: collects ?? this.collects,
      collectsPageNum: collectsPageNum ?? this.collectsPageNum,
      collectsHasMore: collectsHasMore ?? this.collectsHasMore,
      loading: loading ?? this.loading,
      videosLoadingMore: videosLoadingMore ?? this.videosLoadingMore,
      collectsLoadingMore: collectsLoadingMore ?? this.collectsLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        user, stats, overview,
        videos, videosPageNum, videosHasMore, videosLoadingMore,
        collects, collectsPageNum, collectsHasMore, collectsLoadingMore,
        loading, error,
      ];
}

/// 「我的」域 Cubit。
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._userId) : super(const ProfileState());

  final int _userId;

  /// 首次进入：并行拉取资料 / 统计 / 创作者概览 / 作品第一页。
  Future<void> loadBase() async {
    if (state.loading) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final results = await Future.wait([
        Services.user.user(_userId),
        Services.user.stats(_userId),
        Services.user.creatorOverview(),
        Services.user.userVideos(userId: _userId, pageNum: 1),
      ]);
      emit(
        state.copyWith(
          user: results[0] as User,
          stats: results[1] as UserStats,
          overview: results[2] as CreatorOverview,
          videos: (results[3] as PageData<Video>).items,
          videosPageNum: 1,
          videosHasMore: (results[3] as PageData<Video>).hasMore,
          loading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    }
  }

  /// 加载更多作品。
  Future<void> loadMoreVideos() async {
    final s = state;
    if (s.videosLoadingMore || !s.videosHasMore) return;
    emit(s.copyWith(videosLoadingMore: true));
    try {
      final page = await Services.user.userVideos(
        userId: _userId,
        pageNum: s.videosPageNum + 1,
      );
      emit(
        state.copyWith(
          videos: [...state.videos, ...page.items],
          videosPageNum: s.videosPageNum + 1,
          videosHasMore: page.hasMore,
          videosLoadingMore: false,
        ),
      );
    } on ApiException {
      emit(state.copyWith(videosLoadingMore: false));
    }
  }

  /// 加载更多收藏（首次展开收藏 Tab 时调用）。
  Future<void> loadMoreCollects({bool refresh = false}) async {
    final s = state;
    if (s.collectsLoadingMore) return;
    if (!refresh && !s.collectsHasMore) return;
    if (refresh) {
      emit(s.copyWith(collectsLoadingMore: true));
    } else {
      emit(s.copyWith(collectsLoadingMore: true));
    }
    try {
      final pageNum = refresh ? 1 : s.collectsPageNum + 1;
      final page = await Services.interaction.collects(page: pageNum);
      emit(
        state.copyWith(
          collects: refresh
              ? page.items
              : [...state.collects, ...page.items],
          collectsPageNum: pageNum,
          collectsHasMore: page.hasMore,
          collectsLoadingMore: false,
        ),
      );
    } on ApiException {
      emit(state.copyWith(collectsLoadingMore: false));
    }
  }
}
