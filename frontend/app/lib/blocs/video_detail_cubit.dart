import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/user.dart';
import '../models/video.dart';
import '../services/services.dart';

/// 单视频沉浸详情状态。
class VideoDetailState extends Equatable {
  const VideoDetailState({
    this.video,
    this.author,
    this.stats,
    this.liked = false,
    this.collected = false,
    this.following = false,
    this.likeCount = 0,
    this.collectCount = 0,
    this.commentCountDelta = 0,
    this.loading = false,
    this.error,
  });

  final Video? video;
  final User? author;
  final UserStats? stats;
  final bool liked;
  final bool collected;
  final bool following;
  final int likeCount;
  final int collectCount;

  /// 评论数本地增量。
  final int commentCountDelta;
  final bool loading;
  final String? error;

  VideoDetailState copyWith({
    Video? video,
    User? author,
    UserStats? stats,
    bool? liked,
    bool? collected,
    bool? following,
    int? likeCount,
    int? collectCount,
    int? commentCountDelta,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return VideoDetailState(
      video: video ?? this.video,
      author: author ?? this.author,
      stats: stats ?? this.stats,
      liked: liked ?? this.liked,
      collected: collected ?? this.collected,
      following: following ?? this.following,
      likeCount: likeCount ?? this.likeCount,
      collectCount: collectCount ?? this.collectCount,
      commentCountDelta: commentCountDelta ?? this.commentCountDelta,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        video, author, stats, liked, collected, following,
        likeCount, collectCount, commentCountDelta, loading, error,
      ];
}

/// 单视频详情 Cubit：详情加载 + 互动。
class VideoDetailCubit extends Cubit<VideoDetailState> {
  VideoDetailCubit(this._videoId) : super(const VideoDetailState());

  final int _videoId;

  /// 加载详情（游客可访问）。
  Future<void> load() async {
    if (state.loading) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final d = await Services.feed.videoDetail(_videoId);
      emit(
        VideoDetailState(
          video: d.video,
          author: d.author.id != 0 ? d.author : null,
          stats: d.authorStats,
          liked: d.viewerState.liked,
          collected: d.viewerState.collected,
          following: d.viewerState.following,
          likeCount: d.video.likeCount,
          collectCount: d.video.collectCount,
          loading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    }
  }

  /// 点赞 / 取消（targetType=1）。游客返回 false 由 UI 引导登录。
  Future<bool> toggleLike() async {
    final video = state.video;
    if (video == null || !Services.tokens.hasToken) return false;
    final liked = state.liked;
    emit(
      state.copyWith(
        liked: !liked,
        likeCount: state.likeCount + (liked ? -1 : 1),
      ),
    );
    try {
      if (liked) {
        await Services.interaction.unlike(1, video.id);
      } else {
        await Services.interaction.like(1, video.id);
        Services.uba.report(
          UbaEvent(eventType: UbaEventType.like, videoId: video.id),
        );
      }
      return true;
    } on ApiException {
      emit(
        state.copyWith(liked: liked, likeCount: state.likeCount + (liked ? 1 : -1)),
      );
      return false;
    }
  }

  /// 收藏 / 取消。
  Future<bool> toggleCollect() async {
    final video = state.video;
    if (video == null || !Services.tokens.hasToken) return false;
    final collected = state.collected;
    emit(
      state.copyWith(
        collected: !collected,
        collectCount: state.collectCount + (collected ? -1 : 1),
      ),
    );
    try {
      if (collected) {
        await Services.interaction.uncollect(video.id);
      } else {
        await Services.interaction.collect(video.id);
        Services.uba.report(
          UbaEvent(eventType: UbaEventType.collect, videoId: video.id),
        );
      }
      return true;
    } on ApiException {
      emit(
        state.copyWith(
          collected: collected,
          collectCount: state.collectCount + (collected ? 1 : -1),
        ),
      );
      return false;
    }
  }

  /// 关注 / 取关作者。
  Future<bool> toggleFollow() async {
    final author = state.author;
    if (author == null || !Services.tokens.hasToken) return false;
    final following = state.following;
    emit(state.copyWith(following: !following));
    try {
      if (following) {
        await Services.interaction.unfollow(author.id);
      } else {
        await Services.interaction.follow(author.id);
        Services.uba.report(
          UbaEvent(eventType: UbaEventType.follow, videoId: _videoId),
        );
      }
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(following: following));
      if (e.isReason('CANNOT_FOLLOW_SELF')) return true;
      return false;
    }
  }

  /// 评论数变化。
  void bumpCommentCount(int delta) =>
      emit(state.copyWith(commentCountDelta: state.commentCountDelta + delta));
}
