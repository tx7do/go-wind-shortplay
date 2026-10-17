import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/feed_cubit.dart';
import '../../core/config.dart';
import '../../core/route_observer.dart';
import '../../models/user.dart';
import '../../models/video.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import '../comment/comment_sheet.dart';
import '../login/login_page.dart';
import '../search/search_page.dart';
import '../user/user_page.dart';
import 'feed_video_item.dart';

/// 首页 Feed：顶部「关注/热门」渠道切换 + 垂直沉浸流。
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  FeedChannel _channel = FeedChannel.hot;

  @override
  Widget build(BuildContext context) {
    // 按渠道隔离 cubit 实例：切换 Tab 即重建（当前两个渠道都调 /feed，
    // 为后续服务端按渠道召回留口子）。
    return BlocProvider<FeedCubit>(
      key: ValueKey(_channel),
      create: (_) => FeedCubit()..loadFirst(channel: _channel),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const _FeedListView(),
            SafeArea(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: _ChannelSwitch(
                      current: _channel,
                      onChanged: (c) => setState(() => _channel = c),
                    ),
                  ),
                  // 顶部右侧搜索入口。
                  Positioned(
                    top: 2,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      tooltip: '搜索',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchPage()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部渠道切换（关注 / 热门）。
class _ChannelSwitch extends StatelessWidget {
  const _ChannelSwitch({required this.current, required this.onChanged});

  final FeedChannel current;
  final ValueChanged<FeedChannel> onChanged;

  @override
  Widget build(BuildContext context) {
    // 外层由 Align(topCenter) 定位，这里直接渲染胶囊容器。
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _item('关注', FeedChannel.follow),
          _item('热门', FeedChannel.hot),
        ],
      ),
    );
  }

  Widget _item(String label, FeedChannel channel) {
    final selected = current == channel;
    return GestureDetector(
      onTap: () => onChanged(channel),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.6),
            fontSize: 16,
            fontWeight: selected ? FontWeight.bold : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Feed 翻页列表：实现 [VideoItemActions]，把数据操作交给 FeedCubit。
class _FeedListView extends StatefulWidget {
  const _FeedListView();

  @override
  State<_FeedListView> createState() => _FeedListViewState();
}

class _FeedListViewState extends State<_FeedListView>
    with RouteAware
    implements VideoItemActions {
  final PageController _pageController = PageController();
  final Map<int, User> _authorCache = {};
  int _index = 0;
  bool _routeObscured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pageController.dispose();
    super.dispose();
  }

  // RouteAware：上层路由（评论弹窗、详情页等）盖住时暂停视频。
  @override
  void didPushNext() {
    if (!_routeObscured) setState(() => _routeObscured = true);
  }

  @override
  void didPopNext() {
    if (_routeObscured) setState(() => _routeObscured = false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeedCubit, FeedState>(
      builder: (context, state) {
        if (state.firstLoading && state.items.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          );
        }
        if (state.firstError != null && state.items.isEmpty) {
          return ErrorRetryView(
            message: state.firstError ?? '加载失败',
            onRetry: () => context.read<FeedCubit>().loadFirst(),
          );
        }
        if (state.items.isEmpty) {
          return const EmptyView(
            icon: Icons.movie_filter_outlined,
            text: '暂时没有内容，去发布第一条视频吧',
          );
        }
        return PageView.builder(
          scrollDirection: Axis.vertical,
          controller: _pageController,
          itemCount: state.items.length,
          onPageChanged: (i) {
            setState(() => _index = i);
            // 接近末尾时预取下一页。
            if (i >= state.items.length - 3) {
              context.read<FeedCubit>().loadMore();
            }
          },
          itemBuilder: (context, i) {
            final video = state.items[i].video;
            return FeedVideoItem(
              video: video,
              isActive: i == _index && !_routeObscured,
              actions: this,
            );
          },
        );
      },
    );
  }

  // ---- VideoItemActions ----

  @override
  bool isLiked(Video video) =>
      context.read<FeedCubit>().state.likedIds.contains(video.id);

  @override
  bool isCollected(Video video) =>
      context.read<FeedCubit>().state.collectedIds.contains(video.id);

  @override
  bool isFollowing(User author) =>
      context.read<FeedCubit>().state.followedIds.contains(author.id);

  @override
  int likeCountOf(Video video) {
    final s = context.read<FeedCubit>().state;
    return video.likeCount + (s.likeCountDelta[video.id] ?? 0);
  }

  @override
  int collectCountOf(Video video) {
    final s = context.read<FeedCubit>().state;
    return video.collectCount + (s.collectCountDelta[video.id] ?? 0);
  }

  @override
  int commentCountOf(Video video) {
    final s = context.read<FeedCubit>().state;
    return video.commentCount + (s.commentCountDelta[video.id] ?? 0);
  }

  @override
  Future<User?> loadAuthor(int userId) async {
    if (userId <= 0) return null;
    final cached = _authorCache[userId];
    if (cached != null) return cached;
    try {
      final user = await Services.user.user(userId);
      _authorCache[userId] = user;
      return user;
    } on ApiException {
      return null;
    }
  }

  @override
  Future<void> toggleLike(Video video) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final ok = await context.read<FeedCubit>().toggleLike(video);
    if (!ok && mounted) showToast(context, '操作失败，请稍后重试');
  }

  @override
  Future<void> toggleCollect(Video video) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final ok = await context.read<FeedCubit>().toggleCollect(video);
    if (!ok && mounted) showToast(context, '操作失败，请稍后重试');
  }

  @override
  Future<void> toggleFollow(User author) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final ok = await context.read<FeedCubit>().toggleFollow(author.id);
    if (!ok && mounted) showToast(context, '操作失败，请稍后重试');
  }

  @override
  void openComments(Video video) {
    CommentSheet.show(
      context,
      video: video,
      onCountChanged: (delta) =>
          context.read<FeedCubit>().bumpCommentCount(video.id, delta),
    );
  }

  @override
  void share(Video video) {
    // 分享链接：http://<API_BASE>/s/{videoId}（后端 H5 预览页）。
    Clipboard.setData(
      ClipboardData(text: '${AppConfig.shareBase}/s/${video.id}'),
    );
    showToast(context, '链接已复制，快去分享吧');
  }

  @override
  void openAuthor(User author) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserPage(userId: author.id)),
    );
  }
}
