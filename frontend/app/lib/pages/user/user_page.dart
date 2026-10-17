import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/user_page_cubit.dart';
import '../../models/user.dart';
import '../../widgets/common.dart';
import '../../widgets/video_card.dart';
import '../login/login_page.dart';
import '../video_detail/video_detail_page.dart';

/// 他人主页：资料 + 统计 + 作品列表 + 关注/取关。
class UserPage extends StatelessWidget {
  const UserPage({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context) {
    if (userId <= 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('用户主页')),
        body: const ErrorRetryView(message: '用户不存在'),
      );
    }
    return BlocProvider<UserPageCubit>(
      create: (_) => UserPageCubit(userId)..loadBase(),
      child: const _UserPageView(),
    );
  }
}

class _UserPageView extends StatelessWidget {
  const _UserPageView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<UserPageCubit, UserPageState>(
          builder: (context, state) =>
              Text(state.user?.displayName ?? '用户主页'),
        ),
      ),
      body: BlocBuilder<UserPageCubit, UserPageState>(
        builder: (context, state) {
          if (state.loading && state.user == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          }
          if (state.error != null && state.user == null) {
            return ErrorRetryView(
              message: state.error ?? '加载失败',
              onRetry: () => context.read<UserPageCubit>().loadBase(),
            );
          }
          final user = state.user;
          if (user == null) return const SizedBox.shrink();
          return NestedScrollView(
            headerSliverBuilder: (_, _) => [
              SliverToBoxAdapter(
                child: _UserHeader(user: user, state: state),
              ),
            ],
            body: _VideosGrid(state: state),
          );
        },
      ),
    );
  }
}

/// 资料区：头像 / 昵称 / 简介 / 统计 / 关注按钮。
class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.user, required this.state});

  final User user;
  final UserPageState state;

  Future<void> _toggleFollow(BuildContext context) async {
    if (!await ensureLoggedIn(context)) return;
    if (!context.mounted) return;
    final ok = await context.read<UserPageCubit>().toggleFollow();
    if (!ok && context.mounted) showToast(context, '操作失败，请稍后重试');
  }

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    // 关注状态：由 cubit 维护（来自视频详情 viewerState 或 follow 接口返回）。
    final following = state.following;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                url: user.avatarUrl,
                name: user.displayName,
                radius: 32,
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => _toggleFollow(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: following ? Colors.white38 : Colors.white,
                  side: BorderSide(
                    color: following ? Colors.white24 : Colors.white54,
                  ),
                  minimumSize: const Size(96, 38),
                ),
                child: Text(following ? '已关注' : '关注'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (user.bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                user.bio,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('作品', stats?.videoCount ?? 0),
              _stat('粉丝', stats?.followerCount ?? 0),
              _stat('关注', stats?.followingCount ?? 0),
              _stat('获赞', stats?.likeReceivedCount ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            formatCount(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

/// 作品九宫格。
class _VideosGrid extends StatelessWidget {
  const _VideosGrid({required this.state});

  final UserPageState state;

  @override
  Widget build(BuildContext context) {
    final videos = state.videos;
    if (videos.isEmpty && !state.loadingMore) {
      return const EmptyView(
        icon: Icons.movie_creation_outlined,
        text: 'TA 还没有发布作品',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
          context.read<UserPageCubit>().loadMoreVideos();
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
              loading: state.loadingMore,
              hasMore: state.hasMore,
            );
          }
          final v = videos[i];
          return VideoGridTile(
            video: v,
            onTap: () => VideoDetailPage.push(context, v.id),
          );
        },
      ),
    );
  }
}
