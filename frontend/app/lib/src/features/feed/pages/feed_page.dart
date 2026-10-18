import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart';
import 'package:shortplay_app/src/features/comment/widgets/comment_sheet.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/services/uba_service.dart';
import 'package:shortplay_app/src/features/feed/bloc/feed_bloc.dart';
import 'package:shortplay_app/src/features/feed/widgets/feed_action_bar.dart';
import 'package:shortplay_app/src/features/feed/widgets/feed_video_info.dart';
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
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(44.h),
        child: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(loc.appName),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => context.push(AppRoutePath.search),
            ),
          ],
        ),
      ),
      body: BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return _buildEmpty(context, state, loc);
          }
          return ScrollConfiguration(
            behavior: const _MouseDragScrollBehavior(),
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: state.items.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _FeedPageItem(
                  key: ValueKey('feed-video-${item.video.id}'),
                  feedItem: item,
                  isActive: index == _currentDrawnPage(),
                  author: _authors[item.video.authorId],
                  onNeedDetail: () => _fetchVideoDetail(item.video.id),
                  onVideoUpdated: (video) => context
                      .read<FeedBloc>()
                      .add(FeedVideoReplaced(video.id, video)),
                  onCommentTap: () => _openComments(item.video),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, FeedState state, S loc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_filter_outlined,
            size: 56.sp,
            color: Colors.white.withAlpha(120),
          ),
          SizedBox(height: 12.h),
          Text(
            state.errorMessage ?? loc.allLoaded,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withAlpha(180),
            ),
          ),
          SizedBox(height: 16.h),
          FilledButton(
            onPressed: () =>
                context.read<FeedBloc>().add(const FeedRefreshed()),
            child: Text(state.errorMessage != null ? loc.retry : loc.loading),
          ),
        ],
      ),
    );
  }
}

/// 单页 Feed 条目：播放器 + 右侧操作栏 + 底部信息
class _FeedPageItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final video = feedItem.video;
    final uba = UbaService();

    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayerItem(
          video: video,
          isActive: isActive,
          onPlayStart: (_) {
            uba.report(UbaEvent(
              eventType: UbaEventType.videoPlay,
              videoId: video.id,
            ));
            onNeedDetail();
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
          bottom: 24.h,
          child: FeedVideoInfo(video: video, reason: feedItem.reason),
        ),
        // 右侧操作栏
        Positioned(
          right: 12.w,
          bottom: 24.h,
          child: FeedActionBar(
            video: video,
            authorNickname: author?.nickname ?? '',
            authorAvatarUrl: author?.avatarDisplayUrl ?? '',
            onCommentTap: onCommentTap,
            onVideoUpdated: onVideoUpdated,
          ),
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
