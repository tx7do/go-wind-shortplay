import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth_cubit.dart';
import '../../blocs/notify_cubit.dart';
import '../../models/notification.dart';
import '../../widgets/common.dart';
import '../login/login_page.dart';
import '../user/user_page.dart';
import '../video_detail/video_detail_page.dart';

/// 消息页：点赞 / 评论 / 关注 / 系统通知列表 + 未读角标 + 全部已读。
class NotifyPage extends StatefulWidget {
  const NotifyPage({super.key});

  @override
  State<NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends State<NotifyPage> {
  @override
  void initState() {
    super.initState();
    // 首次进入（已登录）刷新列表与未读数。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthCubit>().state;
      if (auth.isAuthenticated) {
        context.read<NotifyCubit>().refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authenticated = context.watch<AuthCubit>().state.isAuthenticated;
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          BlocBuilder<NotifyCubit, NotifyState>(
            builder: (context, state) {
              final disabled = !authenticated || state.unreadCount == 0;
              return TextButton(
                onPressed: disabled
                    ? null
                    : () => context.read<NotifyCubit>().markAllRead(),
                child: Text(
                  '全部已读',
                  style: TextStyle(
                    color: disabled ? Colors.white24 : Colors.white70,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: authenticated ? _buildList() : _buildGuestGuide(),
    );
  }

  /// 未登录引导。
  Widget _buildGuestGuide() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_none_rounded,
              size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            '登录后查看点赞、评论和粉丝消息',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              if (!await ensureLoggedIn(context)) return;
              if (!mounted) return;
              context.read<NotifyCubit>().refresh();
            },
            child: const Text('登录 / 注册'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return BlocBuilder<NotifyCubit, NotifyState>(
      builder: (context, state) {
        if (state.loading && state.items.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          );
        }
        if (state.error != null && state.items.isEmpty) {
          return ErrorRetryView(
            message: state.error ?? '加载失败',
            onRetry: () => context.read<NotifyCubit>().refresh(),
          );
        }
        if (state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => context.read<NotifyCubit>().refresh(),
            child: ListView(
              children: const [
                SizedBox(height: 160),
                EmptyView(
                  icon: Icons.notifications_none_rounded,
                  text: '暂无消息，发个视频让大家认识你吧',
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => context.read<NotifyCubit>().refresh(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                context.read<NotifyCubit>().loadMore();
              }
              return false;
            },
            child: ListView.separated(
              itemCount: state.items.length + 1,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 66, color: Colors.white10),
              itemBuilder: (context, i) {
                if (i == state.items.length) {
                  return LoadMoreFooter(
                    loading: state.loadingMore,
                    hasMore: state.hasMore,
                  );
                }
                return _NotifyTile(
                  notification: state.items[i],
                  onTap: () => _onItemTap(state.items[i]),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 点击通知：标记已读，并按内容跳转（带视频进详情，关注类进对方主页）。
  Future<void> _onItemTap(AppNotification n) async {
    context.read<NotifyCubit>().markRead(n);
    final videoId = n.videoId;
    if (videoId != null && videoId > 0) {
      await VideoDetailPage.push(context, videoId);
      // 返回后刷新角标。
      if (mounted) context.read<NotifyCubit>().refreshUnreadCount();
      return;
    }
    final sender = n.sender;
    if (n.type == NotifyType.follow && sender != null && sender.id > 0) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserPage(userId: sender.id)),
      );
    }
  }
}

/// 单条通知。
class _NotifyTile extends StatelessWidget {
  const _NotifyTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _typeIcon(n.type, n.isRead),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _titleOf(n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        formatRelativeTime(n.createdAt),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (n.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        n.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
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

  /// 类型图标（未读带角标点）。
  Widget _typeIcon(NotifyType type, bool isRead) {
    final (icon, color) = switch (type) {
      NotifyType.like => (Icons.favorite_rounded, const Color(0xFFFF4D67)),
      NotifyType.comment => (Icons.chat_bubble_rounded, const Color(0xFF4D9FFF)),
      NotifyType.follow => (Icons.person_add_alt_1_rounded, const Color(0xFF37D67A)),
      NotifyType.system => (Icons.campaign_rounded, const Color(0xFFFFC53D)),
      NotifyType.unknown => (Icons.notifications_rounded, Colors.white38),
    };
    return Badge(
      isLabelVisible: !isRead,
      smallSize: 8,
      alignment: Alignment.topLeft,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  String _titleOf(AppNotification n) {
    final name = n.sender?.displayName;
    switch (n.type) {
      case NotifyType.like:
        return '${name ?? '有人'} 赞了你的作品';
      case NotifyType.comment:
        return '${name ?? '有人'} 评论了你的作品';
      case NotifyType.follow:
        return '${name ?? '有人'} 关注了你';
      case NotifyType.system:
        return '系统通知';
      case NotifyType.unknown:
        return name?.isNotEmpty == true ? name! : '新消息';
    }
  }
}
