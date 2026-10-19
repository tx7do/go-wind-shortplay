import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/src/core/themes/app_colors.dart';

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
/// 自绘实现（国内短视频风格）：图标 + 小字标签，选中态品牌色加重，
/// 无 MD3 胶囊指示器；角标为品牌红胶囊。
///
/// 实体栏（不透明）：与抖音一致，仅顶部栏沉入视频，底栏不与视频叠加。
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
    final activeColor = theme.brightness == Brightness.dark
        ? BrandColor.roseBright
        : BrandColor.rose;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color:
                theme.colorScheme.onSurface.withAlpha((0.06 * 255).round()),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54.h,
          child: Center(
            child: ConstrainedBox(
              // 宽窗（桌面/平板横屏）下导航项收窄居中，避免拉伸到全屏
              constraints: BoxConstraints(maxWidth: 520.w),
              child: Row(
                children: List.generate(items.length, (index) {
                  return Expanded(
                    child: _NavItemTile(
                      item: items[index],
                      selected: index == selectedIndex,
                      activeColor: activeColor,
                      onTap: () => onDestinationSelected(index),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemTile extends StatelessWidget {
  final BottomNavItem item;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavItemTile({
    required this.item,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? activeColor
        : theme.colorScheme.onSurface.withAlpha((0.45 * 255).round());

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  key: ValueKey(selected),
                  size: 24.r,
                  color: color,
                ),
              ),
              if (item.badgeCount > 0)
                Positioned(
                  top: -4.r,
                  right: -10.r,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    constraints: BoxConstraints(minWidth: 16.r),
                    decoration: BoxDecoration(
                      color: BrandColor.rose,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 3.h),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
