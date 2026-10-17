import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart' show AppRoutePath;
import 'package:shortplay_app/src/features/common/widgets/login_guard.dart';
import 'package:shortplay_app/src/features/common/widgets/user_avatar.dart';
import 'package:shortplay_app/src/features/notify/bloc/notify_bloc.dart';
import 'package:shortplay_app/src/features/notify/models/notification.dart';

/// 消息通知页（四类型图标 + 未读角标 + 全部已读 + 点击带 videoId 进详情）
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
    if (item.videoId > 0) {
      context.push(AppRoutePath.videoPath(item.videoId));
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
    final loc = S.of(context);
    final theme = Theme.of(context);

    final (icon, iconColor, typeLabel) = _typeVisual(context, loc);

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
                UserAvatar.fromBrief(item.sender, radius: 20),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: EdgeInsets.all(3.r),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 13.sp, color: iconColor),
                  ),
                ),
              ],
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.sender?.nickname ?? typeLabel,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 5.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: iconColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: iconColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!item.isRead)
                        Container(
                          width: 8.r,
                          height: 8.r,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
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
            if (item.videoId > 0) ...[
              SizedBox(width: 8.w),
              Icon(
                Icons.chevron_right,
                size: 20.sp,
                color: theme.colorScheme.onSurface.withAlpha(90),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _typeVisual(BuildContext context, S loc) {
    final theme = Theme.of(context);
    switch (item.type) {
      case NotifyType.like:
        return (Icons.favorite, theme.colorScheme.error, loc.notifyTypeLike);
      case NotifyType.comment:
        return (
          Icons.chat_bubble_outline,
          theme.colorScheme.primary,
          loc.notifyTypeComment
        );
      case NotifyType.follow:
        return (
          Icons.person_add_alt,
          theme.colorScheme.tertiary,
          loc.notifyTypeFollow
        );
      default:
        return (
          Icons.notifications_outlined,
          theme.colorScheme.secondary,
          loc.notifyTypeSystem
        );
    }
  }
}
