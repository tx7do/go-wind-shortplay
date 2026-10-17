import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/video.dart';
import '../services/services.dart';

/// Feed 召回渠道：关注 / 热门（当前都调 /feed，为后续服务端渠道召回留口子）。
enum FeedChannel { hot, follow }

/// Feed 列表状态。
class FeedState extends Equatable {
  const FeedState({
    this.channel = FeedChannel.hot,
    this.items = const [],
    this.pageNum = 0,
    this.hasMore = true,
    this.firstLoading = false,
    this.loadingMore = false,
    this.firstError,
    this.likedIds = const {},
    this.collectedIds = const {},
    this.followedIds = const {},
    this.likeCountDelta = const {},
    this.collectCountDelta = const {},
    this.commentCountDelta = const {},
  });

  final FeedChannel channel;
  final List<FeedEntry> items;
  final int pageNum;
  final bool hasMore;
  final bool firstLoading;
  final bool loadingMore;
  final String? firstError;

  /// 当前用户互动状态（登录后通过 /interactions/status 批量拉取）。
  final Set<int> likedIds;
  final Set<int> collectedIds;
  final Set<int> followedIds;

  /// 本地计数修正（服务端计数 + 本地增量）。
  final Map<int, int> likeCountDelta;
  final Map<int, int> collectCountDelta;
  final Map<int, int> commentCountDelta;

  FeedState copyWith({
    FeedChannel? channel,
    List<FeedEntry>? items,
    int? pageNum,
    bool? hasMore,
    bool? firstLoading,
    bool? loadingMore,
    String? firstError,
    bool clearFirstError = false,
    Set<int>? likedIds,
    Set<int>? collectedIds,
    Set<int>? followedIds,
    Map<int, int>? likeCountDelta,
    Map<int, int>? collectCountDelta,
    Map<int, int>? commentCountDelta,
  }) {
    return FeedState(
      channel: channel ?? this.channel,
      items: items ?? this.items,
      pageNum: pageNum ?? this.pageNum,
      hasMore: hasMore ?? this.hasMore,
      firstLoading: firstLoading ?? this.firstLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      firstError: clearFirstError ? null : (firstError ?? this.firstError),
      likedIds: likedIds ?? this.likedIds,
      collectedIds: collectedIds ?? this.collectedIds,
      followedIds: followedIds ?? this.followedIds,
      likeCountDelta: likeCountDelta ?? this.likeCountDelta,
      collectCountDelta: collectCountDelta ?? this.collectCountDelta,
      commentCountDelta: commentCountDelta ?? this.commentCountDelta,
    );
  }

  @override
  List<Object?> get props => [
        channel,
        items,
        pageNum,
        hasMore,
        firstLoading,
        loadingMore,
        firstError,
        likedIds,
        collectedIds,
        followedIds,
        likeCountDelta,
        collectCountDelta,
        commentCountDelta,
      ];
}

/// Feed 域 Cubit：分页加载、互动状态维护、UBA 播放侧行为之外的所有数据操作。
class FeedCubit extends Cubit<FeedState> {
  FeedCubit() : super(const FeedState());

  /// 首次加载 / 切换渠道后重载。
  Future<void> loadFirst({FeedChannel? channel}) async {
    final ch = channel ?? state.channel;
    emit(
      state.copyWith(
        channel: ch,
        firstLoading: true,
        clearFirstError: true,
        items: channel != null && channel != state.channel ? [] : null,
        pageNum: 0,
        hasMore: true,
      ),
    );
    try {
      final page = await Services.feed.feed(pageNum: 1);
      final s = state;
      emit(
        s.copyWith(
          items: page.items,
          pageNum: 1,
          hasMore: page.hasMore,
          firstLoading: false,
        ),
      );
      await _syncInteractions(page.items.map((e) => e.video.id).toList());
    } on ApiException {
      emit(state.copyWith(firstLoading: false, firstError: '加载失败'));
    }
  }

  /// 上拉加载更多。
  Future<void> loadMore() async {
    final s = state;
    if (s.loadingMore || s.firstLoading || !s.hasMore) return;
    emit(s.copyWith(loadingMore: true));
    try {
      final page = await Services.feed.feed(pageNum: s.pageNum + 1);
      emit(
        state.copyWith(
          items: [...state.items, ...page.items],
          pageNum: s.pageNum + 1,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
      await _syncInteractions(page.items.map((e) => e.video.id).toList());
    } on ApiException {
      emit(state.copyWith(loadingMore: false));
    }
  }

  /// 登录后批量同步当前页视频的点赞/收藏状态。
  Future<void> _syncInteractions(List<int> videoIds) async {
    if (videoIds.isEmpty) return;
    if (!Services.tokens.hasToken) return;
    try {
      final statuses =
          await Services.interaction.interactionStatus(videoIds);
      emit(
        state.copyWith(
          likedIds: {...state.likedIds, ...statuses.entries.where((e) => e.value.liked).map((e) => e.key)},
          collectedIds: {
            ...state.collectedIds,
            ...statuses.entries.where((e) => e.value.collected).map((e) => e.key),
          },
        ),
      );
    } on ApiException {
      // 状态同步失败不影响浏览。
    }
  }

  /// 点赞 / 取消点赞（targetType=1）。游客引导登录。
  Future<bool> toggleLike(Video video) async {
    if (!Services.tokens.hasToken) return false;
    final s = state;
    final liked = s.likedIds.contains(video.id);
    // 乐观更新。
    _mutateSets(
      liked: () =>
          liked ? s.likedIds.difference({video.id}) : {...s.likedIds, video.id},
      collect: null,
      follow: null,
      likeDelta: {video.id: (s.likeCountDelta[video.id] ?? 0) + (liked ? -1 : 1)},
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
      // 回滚。
      _mutateSets(
        liked: () => (!liked)
            ? s.likedIds.difference({video.id})
            : {...s.likedIds, video.id},
        collect: null,
        follow: null,
        likeDelta: {video.id: s.likeCountDelta[video.id] ?? 0},
      );
      return false;
    }
  }

  /// 收藏 / 取消收藏。
  Future<bool> toggleCollect(Video video) async {
    if (!Services.tokens.hasToken) return false;
    final s = state;
    final collected = s.collectedIds.contains(video.id);
    _mutateSets(
      liked: null,
      collect: () => collected
          ? s.collectedIds.difference({video.id})
          : {...s.collectedIds, video.id},
      follow: null,
      collectDelta: {
        video.id: (s.collectCountDelta[video.id] ?? 0) + (collected ? -1 : 1),
      },
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
      _mutateSets(
        liked: null,
        collect: () => (!collected)
            ? s.collectedIds.difference({video.id})
            : {...s.collectedIds, video.id},
        follow: null,
        collectDelta: {video.id: s.collectCountDelta[video.id] ?? 0},
      );
      return false;
    }
  }

  /// 关注 / 取关作者。
  Future<bool> toggleFollow(int authorId) async {
    if (!Services.tokens.hasToken) return false;
    final s = state;
    final following = s.followedIds.contains(authorId);
    _mutateSets(
      liked: null,
      collect: null,
      follow: () => following
          ? s.followedIds.difference({authorId})
          : {...s.followedIds, authorId},
    );
    try {
      if (following) {
        await Services.interaction.unfollow(authorId);
      } else {
        await Services.interaction.follow(authorId);
        for (final e in state.items) {
          if (e.video.authorId == authorId) {
            Services.uba.report(
              UbaEvent(eventType: UbaEventType.follow, videoId: e.video.id),
            );
          }
        }
      }
      return true;
    } on ApiException catch (e) {
      _mutateSets(
        liked: null,
        collect: null,
        follow: () => (!following)
            ? s.followedIds.difference({authorId})
            : {...s.followedIds, authorId},
      );
      if (e.isReason('CANNOT_FOLLOW_SELF')) return true;
      return false;
    }
  }

  /// 评论数变化（发表/删除评论后回调）。
  void bumpCommentCount(int videoId, int delta) {
    final s = state;
    emit(
      s.copyWith(
        commentCountDelta: {
          ...s.commentCountDelta,
          videoId: (s.commentCountDelta[videoId] ?? 0) + delta,
        },
      ),
    );
  }

  void _mutateSets({
    Set<int>? Function()? liked,
    Set<int>? Function()? collect,
    Set<int>? Function()? follow,
    Map<int, int>? likeDelta,
    Map<int, int>? collectDelta,
  }) {
    final s = state;
    emit(
      s.copyWith(
        likedIds: liked?.call(),
        collectedIds: collect?.call(),
        followedIds: follow?.call(),
        likeCountDelta: likeDelta,
        collectCountDelta: collectDelta,
      ),
    );
  }
}
