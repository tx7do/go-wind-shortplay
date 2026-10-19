import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/themes/cubit/app_theme_cubit.dart';

/// 系统设置：外观（深色模式）/ 语言 / 关于（版本）
///
/// 裁剪自底座 settings_page（go-wind-cms flutter_app），卡片样式沿用本应用
/// 设计语言（品牌渐变点缀）。主题色选择不引入：品牌色固定为
/// BrandColor.gradient（#FF3D77→#8B5CF6），不开放换色。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  /// 版本号读取失败不阻塞页面，留空兜底展示占位
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {
      // 设备信息异常时按未知版本展示（纯本地 best-effort）
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final cubit = context.watch<AppThemeCubit>();

    return Scaffold(
      appBar: AppBar(title: Text(loc.settings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              // 外观：深色模式
              _SettingsSection(
                icon: Icons.palette_outlined,
                title: loc.appearance,
                children: [
                  _SettingsRow(
                    icon: Icons.dark_mode_outlined,
                    label: loc.darkMode,
                    trailing: _SegmentedSwitch<ThemeMode>(
                      items: {
                        ThemeMode.light: loc.light,
                        ThemeMode.system: loc.followSystem,
                        ThemeMode.dark: loc.dark,
                      },
                      selected: cubit.themeMode,
                      onChanged: (mode) => cubit.modify(mode),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              // 语言
              _SettingsSection(
                icon: Icons.translate,
                title: loc.language,
                children: [
                  _SettingsRow(
                    icon: Icons.language,
                    label: loc.language,
                    trailing: _SegmentedSwitch<Locale>(
                      items: {
                        for (final locale in cubit.supportedLocales)
                          locale: _localeLabel(locale),
                      },
                      selected: cubit.currentLocale,
                      onChanged: (locale) => cubit.modifyLocale(locale),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              // 关于：版本
              _SettingsSection(
                icon: Icons.info_outline,
                title: loc.about,
                children: [
                  _SettingsRow(
                    label: loc.versionLabel,
                    trailing: Text(
                      _version.isEmpty ? '-' : _version,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(200),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 语言展示名（简短口径：中文(中国) / English）
  String _localeLabel(Locale locale) {
    const labels = <String, String>{
      'zh_CN': '中文(中国)',
      'en_US': 'English',
    };
    final key = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    return labels[key] ?? locale.toLanguageTag();
  }
}

/// 设置分组卡（品牌渐变小方标 + 标题 + 行，与创作者中心卡同款式）
class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withAlpha(10),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.colorScheme.onSurface.withAlpha(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22.r,
                height: 22.r,
                decoration: BoxDecoration(
                  gradient: BrandColor.gradient,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(icon, size: 13.r, color: Colors.white),
              ),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          ...children,
        ],
      ),
    );
  }
}

/// 设置行（标签 + 右侧控件）
class _SettingsRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Widget trailing;

  const _SettingsRow({
    this.icon,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18.sp, color: theme.colorScheme.onSurface.withAlpha(180)),
          SizedBox(width: 8.w),
        ],
        // Flexible：长文案语言（如英文）下标签收缩省略，不把右侧控件挤出卡片
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        trailing,
      ],
    );
  }
}

/// 分段切换（选中项用品牌渐变胶囊，未选中灰字）
///
/// 用 Wrap 而非 Row：长文案语言 / 窄窗口下段条自动折行，杜绝横向溢出。
class _SegmentedSwitch<T> extends StatelessWidget {
  final Map<T, String> items;
  final T selected;
  final ValueChanged<T> onChanged;

  const _SegmentedSwitch({
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withAlpha(10),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: theme.colorScheme.onSurface.withAlpha(24)),
      ),
      child: Wrap(
        spacing: 2.w,
        runSpacing: 2.h,
        children: [
          for (final entry in items.entries)
            GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 7.h),
                decoration: BoxDecoration(
                  gradient:
                      entry.key == selected ? BrandColor.gradient : null,
                  borderRadius: BorderRadius.circular(15.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.key == selected) ...[
                      Icon(Icons.check, size: 12.sp, color: Colors.white),
                      SizedBox(width: 3.w),
                    ],
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: entry.key == selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: entry.key == selected
                            ? Colors.white
                            : theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
