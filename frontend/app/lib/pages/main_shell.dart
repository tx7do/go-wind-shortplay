import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_cubit.dart';
import '../blocs/notify_cubit.dart';
import 'feed/feed_page.dart';
import 'notify/notify_page.dart';
import 'profile/profile_page.dart';
import 'publish/publish_page.dart';

/// 主导航壳：底部四个入口 —— 首页 / 发布（中央 +）/ 消息 / 我的。
///
/// 首页、消息、我的用 [IndexedStack] 承载以保留各自状态；
/// 「发布」是动作入口，点击直接打开发布页路由，不切换 Tab。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    // 切到消息 Tab 时顺带刷新未读角标。
    if (i == 1) {
      context.read<NotifyCubit>().refreshUnreadCount();
    }
  }

  Future<void> _openPublish() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PublishPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // 登录态变化时同步消息角标：登录后拉取未读数，登出后清空。
        final notify = context.read<NotifyCubit>();
        if (state.isAuthenticated) {
          notify.refreshUnreadCount();
        } else {
          notify.reset();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [FeedPage(), NotifyPage(), ProfilePage()],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141416),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              _tabItem(
                index: 0,
                icon: Icons.home_rounded,
                activeIcon: Icons.home_filled,
                label: '首页',
              ),
              _publishItem(),
              _tabItem(
                index: 1,
                icon: Icons.notifications_none_rounded,
                activeIcon: Icons.notifications_rounded,
                label: '消息',
              ),
              _tabItem(
                index: 2,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 普通页签（首页 / 消息 / 我的）。
  Widget _tabItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final selected = _index == index;
    final color = selected ? Colors.white : Colors.white54;
    // 注意：builder 闭包里要引用这里的局部 tab（值），不能复用 content 变量，
    // 否则闭包捕获到 BlocBuilder 自身，导致无限递归。
    final tab = _tabContent(
      icon: selected ? activeIcon : icon,
      label: label,
      color: color,
      bold: selected,
    );
    Widget content = tab;
    // 消息页签叠加未读角标。
    if (index == 1) {
      content = BlocBuilder<NotifyCubit, NotifyState>(
        builder: (context, state) {
          final unread = state.unreadCount;
          if (unread <= 0) return tab;
          return Stack(
            children: [
              tab,
              Positioned(
                top: 5,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Transform.translate(
                    // 角标贴在图标右上角。
                    offset: const Offset(8, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4D67),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
    return Expanded(
      child: InkWell(
        onTap: () => _select(index),
        child: content,
      ),
    );
  }

  /// 页签内容（图标 + 文字）。
  Widget _tabContent({
    required IconData icon,
    required String label,
    required Color color,
    required bool bold,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  /// 中央发布按钮：醒目「+」，点击打开发布页。
  Widget _publishItem() {
    return Expanded(
      child: Center(
        child: InkWell(
          onTap: _openPublish,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 46,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4D67), Color(0xFFFF7A45)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
