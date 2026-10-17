import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 底部导航项定义
class BottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// 未读角标数（>0 时展示红点角标，如「消息」Tab）
  final int badgeCount;

  const BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

/// 应用底部导航栏
///
/// 移动端专用的底部导航组件，封装了样式、阴影、安全区域等。
class AppBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<BottomNavItem> items;

  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withAlpha((0.08 * 255).round()),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          // 用 Theme 覆盖去掉水波纹
          child: Theme(
            data: theme.copyWith(
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              height: 60.h,
              backgroundColor: Colors.transparent,
              elevation: 0,
              indicatorColor: theme.colorScheme.primaryContainer,
              surfaceTintColor: Colors.transparent,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: items.map((item) {
                return NavigationDestination(
                  icon: item.badgeCount > 0
                      ? Badge(
                          label: Text(item.badgeCount > 99
                              ? '99+'
                              : '${item.badgeCount}'),
                          child:
                              Icon(item.icon, size: 24.sp),
                        )
                      : Icon(item.icon, size: 24.sp),
                  selectedIcon: Icon(item.activeIcon, size: 24.sp),
                  label: item.label,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
