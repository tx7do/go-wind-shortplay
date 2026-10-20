import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart'
    show ApiStatusException, localizedErrorText;
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/widgets/video_card.dart';
import 'package:shortplay_app/src/features/hot/services/hot_service.dart';

/// 热榜页（游客可访问）：热度分倒序榜单，前三名品牌色高亮。
class HotPage extends StatefulWidget {
  const HotPage({super.key});

  @override
  State<HotPage> createState() => _HotPageState();
}

class _HotPageState extends State<HotPage> {
  final HotService _hotService = HotService();

  List<Video>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _items = null;
    });
    try {
      final items = await _hotService.hot(limit: 50);
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiStatusException catch (e) {
      if (!mounted) return;
      setState(() => _error = localizedErrorText(S.of(context), e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = localizedErrorText(S.of(context), e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final items = _items;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department, size: 20.sp, color: BrandColor.rose),
            SizedBox(width: 6.w),
            Text(loc.hotList),
          ],
        ),
      ),
      body: items == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : items == null
              ? EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: loc.errorOccurred,
                  subtitle: _error!,
                  actionLabel: loc.retry,
                  onAction: _load,
                )
              : items.isEmpty
                  ? EmptyState(icon: Icons.local_fire_department, title: loc.hotListEmpty)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 8.h),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => SizedBox(height: 4.h),
                            itemBuilder: (context, index) {
                              final video = items[index];
                              // 榜单配色：前三名品牌渐变系高亮，其余中性（对齐搜索热榜）
                              final rankColors = [
                                isDark
                                    ? BrandColor.roseBright
                                    : BrandColor.roseDeep,
                                BrandColor.violet,
                                isDark
                                    ? const Color(0xFFFFB43A)
                                    : const Color(0xFFE8890C),
                              ];
                              final rank = index + 1;
                              final rankColor = index < rankColors.length
                                  ? rankColors[index]
                                  : theme.colorScheme.onSurface.withAlpha(110);
                              return Row(
                                children: [
                                  SizedBox(
                                    width: 26.w,
                                    child: Text(
                                      '$rank',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800,
                                        fontStyle: FontStyle.italic,
                                        color: rankColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Expanded(child: VideoListCard(video: video)),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
    );
  }
}
