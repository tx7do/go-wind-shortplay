import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/common.dart';
import '../models/user.dart';
import '../models/video.dart';
import '../services/services.dart';

/// 他人主页状态。
class UserPageState extends Equatable {
  const UserPageState({
    this.user,
    this.stats,
    this.videos = const [],
    this.pageNum = 0,
    this.hasMore = true,
    this.following = false,
    this.followLoaded = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final User? user;
  final UserStats? stats;
  final List<Video> videos;
  final int pageNum;
  final bool hasMore;

  /// 关注状态（服务端无独立查询接口，依赖详情 viewerState / follow 返回值维护）。
  final bool following;
  final bool followLoaded;

  final bool loading;
  final bool loadingMore;
  final String? error;

  UserPageState copyWith({
    User? user,
    UserStats? stats,
    List<Video>? videos,
    int? pageNum,
    bool? hasMore,
    bool? following,
    bool? followLoaded,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) {
    return UserPageState(
      user: user ?? this.user,
      stats: stats ?? this.stats,
      videos: videos ?? this.videos,
      pageNum: pageNum ?? this.pageNum,
      hasMore: hasMore ?? this.hasMore,
      following: following ?? this.following,
      followLoaded: followLoaded ?? this.followLoaded,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        user, stats, videos, pageNum, hasMore,
        following, followLoaded, loading, loadingMore, error,
      ];
}

/// 他人主页 Cubit。
class UserPageCubit extends Cubit<UserPageState> {
  UserPageCubit(this._userId) : super(const UserPageState());

  final int _userId;

  /// 首次进入：资料 + 统计 + 作品第一页。
  Future<void> loadBase() async {
    if (state.loading) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final results = await Future.wait([
        Services.user.user(_userId),
        Services.user.stats(_userId),
        Services.user.userVideos(userId: _userId, pageNum: 1),
      ]);
      final user = results[0] as User;
      emit(
        state.copyWith(
          user: user,
          stats: results[1] as UserStats,
          videos: (results[2] as PageData<Video>).items,
          pageNum: 1,
          hasMore: (results[2] as PageData<Video>).hasMore,
          loading: false,
        ),
      );
      await _syncFollowState();
    } on ApiException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    }
  }

  /// 关注状态：资料接口若带回 viewerState/following 字段则采用。
  Future<void> _syncFollowState() async {
    try {
      final data = await Services.api.getJson('/users/$_userId');
      final viewer = data['viewerState'] ?? data['viewer_state'];
      if (viewer is Map<String, dynamic>) {
        emit(
          state.copyWith(
            following: (viewer['following'] as bool?) ?? state.following,
            followLoaded: true,
          ),
        );
      }
    } on ApiException {
      // 关注状态拉取失败不阻断页面。
    }
  }

  /// 加载更多作品。
  Future<void> loadMoreVideos() async {
    final s = state;
    if (s.loadingMore || !s.hasMore) return;
    emit(s.copyWith(loadingMore: true));
    try {
      final page = await Services.user.userVideos(
        userId: _userId,
        pageNum: s.pageNum + 1,
      );
      emit(
        state.copyWith(
          videos: [...state.videos, ...page.items],
          pageNum: s.pageNum + 1,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } on ApiException {
      emit(state.copyWith(loadingMore: false));
    }
  }

  /// 关注 / 取关。游客返回 false 由 UI 引导登录。
  Future<bool> toggleFollow() async {
    if (!Services.tokens.hasToken) return false;
    if (_userId == 0) return false;
    final following = state.following;
    emit(state.copyWith(following: !following));
    try {
      final data = following
          ? await Services.interaction.unfollow(_userId)
          : await Services.interaction.follow(_userId);
      final result = (data['following'] as bool?) ?? !following;
      emit(state.copyWith(following: result, followLoaded: true));
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(following: following));
      if (e.isReason('CANNOT_FOLLOW_SELF')) return true;
      return false;
    }
  }
}
