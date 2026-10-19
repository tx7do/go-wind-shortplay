import 'dart:async' show unawaited;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart' show Player;

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart';
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/comment/widgets/comment_sheet.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/services/uba_service.dart';
import 'package:shortplay_app/src/features/feed/bloc/feed_bloc.dart';
import 'package:shortplay_app/src/features/feed/widgets/feed_action_bar.dart';
import 'package:shortplay_app/src/features/feed/widgets/feed_progress_bar.dart';
import 'package:shortplay_app/src/features/feed/widgets/feed_video_info.dart';
import 'package:shortplay_app/src/features/feed/widgets/like_burst.dart';
import 'package:shortplay_app/src/features/feed/widgets/video_player_item.dart';
import 'package:shortplay_app/src/features/video_detail/services/video_service.dart';

/// 沉浸式短视频 Feed（上下滑 PageView）
///
/// - 当前页自动播放 / 离开暂停，单击暂停
/// - 游客可刷，互动时引导登录
/// - UBA：VIDEO_PLAY / SWIPE_AWAY / COMPLETE / HEARTBEAT（失败静默）
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();

  /// 作者信息缓存（feed 列表不回传作者资料，进入页面时按需取详情补齐）
  final Map<int, UserBrief> _authors = {};
  final Set<int> _detailFetched = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<FeedBloc>().add(const FeedRefreshed());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final items = context.read<FeedBloc>().state.items;
    // 预取下一页
    if (index >= items.length - 2) {
      context.read<FeedBloc>().add(const FeedNextPageRequested());
    }
    // 补齐当前页作者信息 + 互动状态
    if (index < items.length) {
      _fetchVideoDetail(items[index].video.id);
    }
  }

  Future<void> _fetchVideoDetail(int videoId) async {
    if (_detailFetched.contains(videoId)) return;
    _detailFetched.add(videoId);
    try {
      final detail = await VideoService().getDetail(videoId: videoId);
      if (!mounted) return;
      final author = detail.author;
      if (author != null && author.id > 0) {
        setState(() => _authors[author.id] = author);
      }
      // viewerState 补齐互动状态
      final items = context.read<FeedBloc>().state.items;
      final index = items.indexWhere((item) => item.video.id == videoId);
      if (index >= 0) {
        final old = items[index].video;
        if (old.liked != detail.video.liked ||
            old.collected != detail.video.collected ||
            old.followingAuthor != detail.video.followingAuthor) {
          context.read<FeedBloc>().add(FeedVideoReplaced(
                videoId,
                old.copyWith(
                  liked: detail.video.liked,
                  collected: detail.video.collected,
                  followingAuthor: detail.video.followingAuthor,
                ),
              ));
        }
      }
    } catch (_) {
      // 详情补齐失败静默（列表数据仍可播放）
      _detailFetched.remove(videoId);
    }
  }

  int _currentDrawnPage() {
    if (!_pageController.hasClients) return 0;
    return (_pageController.page ?? 0).round();
  }

  /// 滚动结束后吸附到最近整页：保证页面上要么完整是这一个视频，
  /// 要么完整是那一个视频，绝不停在两页之间（滚轮/触摸板路径可能不吸附）。
  void _snapToNearestPage() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page == null) return;
    final itemCount = context.read<FeedBloc>().state.items.length;
    if (itemCount == 0) return;
    final target = page.round().clamp(0, itemCount - 1);
    if ((page - target).abs() > 0.001) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ─── 滚轮翻页（桌面） ────────────────────────────────

  /// 滚轮节流：一格鼠标滚轮常常连发多个滚动事件，180ms 内只翻一页
  DateTime _lastWheelFlipAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 在页面条目层截获滚轮（比 Scrollable 注册更早），一格翻一页；
  /// 滚轮不再走平滑滚动，从源头避免停在半程。
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _flipPage(event.scrollDelta.dy > 0 ? 1 : -1);
    });
  }

  void _flipPage(int direction) {
    if (!_pageController.hasClients) return;
    final now = DateTime.now();
    if (now.difference(_lastWheelFlipAt) <
        const Duration(milliseconds: 180)) {
      return;
    }
    _lastWheelFlipAt = now;
    final itemCount = context.read<FeedBloc>().state.items.length;
    if (itemCount == 0) return;
    final current = (_pageController.page ?? 0).round();
    final target = (current + direction).clamp(0, itemCount - 1);
    if (target != current) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _openComments(Video video) async {
    await showCommentSheet(
      context,
      videoId: video.id,
      onCommentCountChanged: (delta) {
        FeedItem? item;
        for (final candidate in context.read<FeedBloc>().state.items) {
          if (candidate.video.id == video.id) {
            item = candidate;
            break;
          }
        }
        if (item == null) return;
        context.read<FeedBloc>().add(FeedVideoReplaced(
              video.id,
              item.video.copyWith(
                commentCount: (video.commentCount + delta).clamp(0, 1 << 40),
              ),
            ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = S.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      // 无 AppBar：视频全屏铺满（含顶部标题栏区域），彻底沉浸式；
      // 顶部仅悬浮一个搜索按钮（SafeArea 避让系统状态栏/窗口标题栏）。
      // 底部为实体导航栏（不与视频叠加），见 _HomeShell。
      body: Stack(
        children: [
          BlocBuilder<FeedBloc, FeedState>(
            builder: (context, state) {
              if (state.items.isEmpty) {
                return _buildEmpty(context, state, loc);
              }
              return ScrollConfiguration(
                behavior: const _MouseDragScrollBehavior(),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // 兜底吸附：任何滚动结束（滚轮/触摸板/拖拽取消等）都不允许
                    // 停在两页之间，一律吸附到最近的整页视频。
                    if (notification is ScrollEndNotification) {
                      _snapToNearestPage();
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: state.items.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      // Listener 在 Scrollable 内层，可优先抢到滚轮事件：
                      // 桌面滚轮一格翻一页（抖音网页口径），不走平滑滚动
                      return Listener(
                        onPointerSignal: _onPointerSignal,
                        child: _FeedPageItem(
                          key: ValueKey('feed-video-${item.video.id}'),
                          feedItem: item,
                          isActive: index == _currentDrawnPage(),
                          author: _authors[item.video.authorId],
                          onNeedDetail: () => _fetchVideoDetail(item.video.id),
                          onVideoUpdated: (video) => context
                              .read<FeedBloc>()
                              .add(FeedVideoReplaced(video.id, video)),
                          onCommentTap: () => _openComments(item.video),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // 顶部悬浮搜索（右上角）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: IconButton(
                    icon: const Icon(Icons.search, size: 22),
                    onPressed: () => context.push(AppRoutePath.search),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(28),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, FeedState state, S loc) {
    return EmptyState(
      icon: Icons.movie_filter_outlined,
      title: state.errorMessage ?? loc.allLoaded,
      actionLabel: state.errorMessage != null ? loc.retry : null,
      onAction: state.errorMessage != null
          ? () => context.read<FeedBloc>().add(const FeedRefreshed())
          : null,
      onDark: true,
    );
  }
}

/// 单页 Feed 条目：播放器 + 右侧操作栏 + 底部信息 + 进度条 + 双击点赞
class _FeedPageItem extends StatefulWidget {
  final FeedItem feedItem;

  /// 是否当前活跃页（自动播放）
  final bool isActive;
  final UserBrief? author;
  final VoidCallback onNeedDetail;
  final ValueChanged<Video> onVideoUpdated;
  final VoidCallback onCommentTap;

  const _FeedPageItem({
    super.key,
    required this.feedItem,
    required this.isActive,
    this.author,
    required this.onNeedDetail,
    required this.onVideoUpdated,
    required this.onCommentTap,
  });

  @override
  State<_FeedPageItem> createState() => _FeedPageItemState();
}

class _FeedPageItemState extends State<_FeedPageItem> {
  Player? _player;
  final LikeBurstController _burst = LikeBurstController();

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  /// 双击点赞：红心动画 + 真实点赞（未登录引导）
  void _onDoubleTapLike(Offset position) {
    _burst.burst(position);
    unawaited(runDoubleTapLike(
      context,
      video: widget.feedItem.video,
      onUpdated: widget.onVideoUpdated,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.feedItem.video;
    final uba = UbaService();

    // 覆盖层贴在系统安全区之上（桌面为 0），与底部实体导航栏留出间距
    final bottomInset = MediaQuery.paddingOf(context).bottom + 12.h;

    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayerItem(
          video: video,
          isActive: widget.isActive,
          onPlayerReady: (player) {
            if (mounted) setState(() => _player = player);
          },
          onDoubleTapLike: _onDoubleTapLike,
          onPlayStart: (_) {
            uba.report(UbaEvent(
              eventType: UbaEventType.videoPlay,
              videoId: video.id,
            ));
            widget.onNeedDetail();
          },
          onSwipeAway: (progress) {
            uba.report(UbaEvent(
              eventType: UbaEventType.videoSwipeAway,
              videoId: video.id,
              durationMs: progress.watchMs,
              watchPercent: progress.percent,
            ));
          },
          onComplete: (progress) {
            uba.report(UbaEvent(
              eventType: UbaEventType.videoComplete,
              videoId: video.id,
              durationMs: progress.watchMs,
              watchPercent: 100,
            ));
          },
          onHeartbeat: (progress) {
            uba.report(UbaEvent(
              eventType: UbaEventType.videoHeartbeat,
              videoId: video.id,
              durationMs: progress.watchMs,
              watchPercent: progress.percent,
            ));
          },
        ),
        // 底部信息（左）
        Positioned(
          left: 16.w,
          right: 88.w,
          bottom: bottomInset,
          child: FeedVideoInfo(
            video: video,
            reason: widget.feedItem.reason,
            authorNickname: widget.author?.nickname ?? '',
          ),
        ),
        // 右侧操作栏
        Positioned(
          right: 12.w,
          bottom: bottomInset,
          child: FeedActionBar(
            video: video,
            authorNickname: widget.author?.nickname ?? '',
            authorAvatarUrl: widget.author?.avatarDisplayUrl ?? '',
            onCommentTap: widget.onCommentTap,
            onVideoUpdated: widget.onVideoUpdated,
          ),
        ),
        // 底部细进度条（拖动 seek + 时间气泡）
        if (_player != null)
          FeedProgressBar(
            player: _player!,
            bottomInset: MediaQuery.paddingOf(context).bottom + 5.h,
          ),
        // 双击点赞红心动画层
        Positioned.fill(
          child: LikeBurstLayer(controller: _burst),
        ),
      ],
    );
  }
}

/// Web 桌面端默认 ScrollBehavior 的 dragDevices 不含鼠标，按住拖拽不会滚动；
/// 放开鼠标后，上下滑 PageView 才能像移动端触屏一样拖拽切换视频。
class _MouseDragScrollBehavior extends MaterialScrollBehavior {
  const _MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}
