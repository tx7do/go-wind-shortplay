import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart' show RouteNames;
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.message),
        actions: [
          BlocBuilder<NotifyBloc, NotifyState>(
            builder: (context, state) {
              if (state.unreadCount <= 0) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: TextButton.icon(
                  onPressed: () {
                    context.read<NotifyBloc>().add(const NotifyAllMarkedRead());
                  },
                  icon: Icon(Icons.done_all_rounded, size: 16.sp),
                  label: Text(
                    loc.markAllRead,
                    style: TextStyle(fontSize: 13.sp),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotifyBloc, NotifyState>(
        builder: (context, state) {
          if (state.requireLogin) {
            return EmptyState(
              icon: Icons.notifications_none,
              title: loc.loginToViewMessages,
              actionLabel: loc.login,
              onAction: () async {
                final ok = await ensureLogin(context);
                if (ok && context.mounted) {
                  context.read<NotifyBloc>().add(const NotifyRefreshed());
                }
              },
            );
          }

          if (state.errorMessage != null && state.items.isEmpty) {
            return EmptyState(
              icon: Icons.wifi_off_rounded,
              title: state.errorMessage!,
              actionLabel: loc.retry,
              onAction: () => context
                  .read<NotifyBloc>()
                  .add(NotifyRefreshed(unreadOnly: state.unreadOnly)),
            );
          }

          if (state.items.isEmpty && state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.items.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_none,
              title: loc.noNewMessages,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<NotifyBloc>().add(
                    NotifyRefreshed(unreadOnly: state.unreadOnly),
                  );
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => SizedBox(height: 6.h),
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
              ),
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
    final unread = !item.isRead;

    return Material(
      color: unread
          ? BrandColor.rose.withAlpha(10)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38.r,
                    height: 38.r,
                    decoration: BoxDecoration(
                      color: unread
                          ? BrandColor.rose.withAlpha(24)
                          : theme.colorScheme.onSurface.withAlpha(12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      unread
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      size: 18.r,
                      color: unread
                          ? (theme.brightness == Brightness.dark
                              ? BrandColor.roseBright
                              : BrandColor.roseDeep)
                          : theme.colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                  if (unread)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 9.r,
                        height: 9.r,
                        decoration: BoxDecoration(
                          color: BrandColor.rose,
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
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
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
                        height: 1.45,
                        color: theme.colorScheme.onSurface
                            .withAlpha(unread ? 190 : 150),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.chevron_right_rounded,
                size: 18.sp,
                color: theme.colorScheme.onSurface.withAlpha(60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
