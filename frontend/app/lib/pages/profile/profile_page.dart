import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth_cubit.dart';
import '../../blocs/notify_cubit.dart';
import '../../blocs/profile_cubit.dart';
import '../../models/user.dart';
import '../../widgets/common.dart';
import '../../widgets/video_card.dart';
import '../login/login_page.dart';
import '../video_detail/video_detail_page.dart';
import 'profile_edit_page.dart';

/// 「我的」页：未登录显示引导登录，已登录展示资料 / 统计 /
/// 创作者中心 / 作品与收藏。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final userId = auth.user?.id ?? 0;
    if (!auth.isAuthenticated || userId <= 0) {
      return const _GuestView();
    }
    // key 绑定用户 id：登录/切换账号后重建 cubit。
    return BlocProvider<ProfileCubit>(
      key: ValueKey(userId),
      create: (_) => ProfileCubit(userId)..loadBase(),
      child: const _ProfileView(),
    );
  }
}

/// 未登录引导视图。
class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline_rounded,
                size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              '登录后可发布作品、点赞收藏',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => LoginPage.push(context),
              child: const Text('登录 / 注册'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 已登录主视图。
class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, size: 22),
              tooltip: '退出登录',
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            final user = state.user;
            if (state.loading && user == null) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              );
            }
            if (state.error != null && user == null) {
              return ErrorRetryView(
                message: state.error ?? '加载失败',
                onRetry: () => context.read<ProfileCubit>().loadBase(),
              );
            }
            if (user == null) return const SizedBox.shrink();
            return RefreshIndicator(
              onRefresh: () => context.read<ProfileCubit>().loadBase(),
              child: NestedScrollView(
                headerSliverBuilder: (_, _) => [
                  SliverToBoxAdapter(child: _Header(user: user)),
                  SliverToBoxAdapter(child: _StatsRow(stats: state.stats)),
                  SliverToBoxAdapter(
                    child: _CreatorCard(overview: state.overview),
                  ),
                  const SliverAppBar(
                    pinned: true,
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.black,
                    toolbarHeight: 46,
                    title: TabBar(
                      tabs: [Tab(text: '作品'), Tab(text: '收藏')],
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _VideosGrid(),
                    _CollectsGrid(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('退出', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await context.read<AuthCubit>().logout();
    // 登出后顺带清空消息角标（MainShell 的监听也会处理，这里双保险）。
    if (context.mounted) context.read<NotifyCubit>().reset();
  }
}

/// 头部：头像 / 昵称 / 简介 / 编辑资料入口。
class _Header extends StatelessWidget {
  const _Header({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          UserAvatar(url: user.avatarUrl, name: user.displayName, radius: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user.bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      user.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileEditPage(user: user),
                ),
              );
              // 编辑完成后刷新页面数据。
              if (context.mounted) {
                context.read<ProfileCubit>().loadBase();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('编辑资料', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// 统计行：作品 / 粉丝 / 关注 / 获赞。
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final UserStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          _item('作品', s?.videoCount ?? 0),
          _item('粉丝', s?.followerCount ?? 0),
          _item('关注', s?.followingCount ?? 0),
          _item('获赞', s?.likeReceivedCount ?? 0),
        ],
      ),
    );
  }

  Widget _item(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            formatCount(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 创作者中心卡片（GET /creator/overview）。
class _CreatorCard extends StatelessWidget {
  const _CreatorCard({required this.overview});

  final CreatorOverview? overview;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    if (o == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  size: 18, color: Color(0xFFFFC53D)),
              const SizedBox(width: 6),
              const Text(
                '创作者中心',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '粉丝 ${formatCount(o.followerCount)}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric('总播放', o.totalViews),
              _metric('总点赞', o.totalLikes),
              _metric('总收藏', o.totalCollects),
              _metric('总评论', o.totalComments),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            formatCount(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// 作品九宫格（本人作品含审核中/驳回/下架，带状态角标）。
class _VideosGrid extends StatelessWidget {
  const _VideosGrid();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final videos = state.videos;
        if (videos.isEmpty && !state.videosLoadingMore) {
          return const EmptyView(
            icon: Icons.movie_creation_outlined,
            text: '还没有作品，点底部「+」发布第一条视频吧',
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
              context.read<ProfileCubit>().loadMoreVideos();
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.62,
            ),
            itemCount: videos.length + 1,
            itemBuilder: (context, i) {
              if (i == videos.length) {
                return LoadMoreFooter(
                  loading: state.videosLoadingMore,
                  hasMore: state.videosHasMore,
                );
              }
              final v = videos[i];
              return VideoGridTile(
                video: v,
                showStatus: true,
                onTap: () => VideoDetailPage.push(context, v.id),
              );
            },
          ),
        );
      },
    );
  }
}

/// 收藏九宫格（首次展开时才拉取）。
class _CollectsGrid extends StatefulWidget {
  @override
  State<_CollectsGrid> createState() => _CollectsGridState();
}

class _CollectsGridState extends State<_CollectsGrid> {
  @override
  void initState() {
    super.initState();
    // TabBarView 懒加载：首次进入收藏页签时拉取第一页。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<ProfileCubit>();
      if (cubit.state.collects.isEmpty && cubit.state.collectsPageNum == 0) {
        cubit.loadMoreCollects(refresh: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final collects = state.collects;
        if (collects.isEmpty && !state.collectsLoadingMore) {
          return const EmptyView(
            icon: Icons.star_border_rounded,
            text: '还没有收藏，去 Feed 里发现喜欢的视频吧',
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
              context.read<ProfileCubit>().loadMoreCollects();
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.62,
            ),
            itemCount: collects.length + 1,
            itemBuilder: (context, i) {
              if (i == collects.length) {
                return LoadMoreFooter(
                  loading: state.collectsLoadingMore,
                  hasMore: state.collectsHasMore,
                );
              }
              final v = collects[i];
              return VideoGridTile(
                video: v,
                onTap: () => VideoDetailPage.push(context, v.id),
              );
            },
          ),
        );
      },
    );
  }
}
