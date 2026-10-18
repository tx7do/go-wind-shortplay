import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart' show RouteNames;
import 'package:shortplay_app/src/features/common/widgets/login_guard.dart';
import 'package:shortplay_app/src/features/notify/bloc/notify_bloc.dart';
import 'package:shortplay_app/src/features/notify/models/notification.dart';

/// 消息通知页（基座站内信收件箱形状：图标 + 标题/正文 + 未读点 + 全部已读）
class NotifyPage extends StatefulWidget {
  const NotifyPage({super.key});

  @override
  State<NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends State<NotifyPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      context.read<NotifyBloc>().add(const NotifyNextPageRequested());
    }
  }

  void _openItem(NotificationItem item) {
    context.read<NotifyBloc>().add(NotifyMarkedRead(item));
    // sp-biz 尾标记携带 videoId 的通知（视频举报等）点击直达视频详情页
    final videoId = item.videoId;
    if (videoId != null) {
      context.pushNamed(
        RouteNames.videoDetail,
        pathParameters: {'videoId': '$videoId'},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.message),
        actions: [
          BlocBuilder<NotifyBloc, NotifyState>(
            builder: (context, state) {
              return IconButton(
                tooltip: loc.markAllRead,
                icon: const Icon(Icons.done_all),
                onPressed: state.unreadCount <= 0
                    ? null
                    : () {
                        context
                            .read<NotifyBloc>()
                            .add(const NotifyAllMarkedRead());
                      },
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotifyBloc, NotifyState>(
        builder: (context, state) {
          if (state.requireLogin) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 56.sp,
                    color: theme.colorScheme.onSurface.withAlpha(90),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    loc.loginToViewMessages,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: theme.colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  FilledButton(
                    onPressed: () async {
                      final ok = await ensureLogin(context);
                      if (ok && context.mounted) {
                        context
                            .read<NotifyBloc>()
                            .add(const NotifyRefreshed());
                      }
                    },
                    child: Text(loc.login),
                  ),
                ],
              ),
            );
          }

          if (state.errorMessage != null && state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.errorMessage!),
                  FilledButton(
                    onPressed: () => context
                        .read<NotifyBloc>()
                        .add(NotifyRefreshed(unreadOnly: state.unreadOnly)),
                    child: Text(loc.retry),
                  ),
                ],
              ),
            );
          }

          if (state.items.isEmpty && state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.items.isEmpty) {
            return Center(
              child: Text(
                loc.noNewMessages,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: theme.colorScheme.onSurface.withAlpha(130),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<NotifyBloc>().add(
                    NotifyRefreshed(unreadOnly: state.unreadOnly),
                  );
            },
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 68.w,
                color: theme.dividerColor.withAlpha(80),
              ),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return Padding(
                    padding: EdgeInsets.all(12.h),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final item = state.items[index];
                return _NotifyTile(
                  item: item,
                  onTap: () => _openItem(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotifyTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotifyTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      theme.colorScheme.secondaryContainer,
                  child: Icon(
                    item.isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    size: 20.sp,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                if (!item.isRead)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 10.r,
                      height: 10.r,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(
                            color: theme.colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight:
                          item.isRead ? FontWeight.w500 : FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    item.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: theme.colorScheme.onSurface.withAlpha(170),
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
