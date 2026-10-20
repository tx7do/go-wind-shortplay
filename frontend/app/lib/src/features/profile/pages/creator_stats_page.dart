import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart'
    show ApiStatusException, localizedErrorText;
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/profile/services/user_service.dart';

/// 创作者数据页（本人口径）：近 7/14/30 天的播放/点赞/发布柱状图。
/// 无图表库依赖，柱体用 Container 按最大值归一化绘制（对齐项目自绘范式）。
class CreatorStatsPage extends StatefulWidget {
  const CreatorStatsPage({super.key});

  @override
  State<CreatorStatsPage> createState() => _CreatorStatsPageState();
}

class _CreatorStatsPageState extends State<CreatorStatsPage> {
  final UserService _userService = UserService();

  List<TrendPoint>? _points;
  int _days = 7;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final points = await _userService.creatorTrends(days: _days);
      if (!mounted) return;
      setState(() => _points = points);
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
    final points = _points;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.creatorStatsTitle),
        actions: [
          // 天数切换（7/14/30）
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: Center(
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7D')),
                  ButtonSegment(value: 14, label: Text('14D')),
                  ButtonSegment(value: 30, label: Text('30D')),
                ],
                selected: {_days},
                onSelectionChanged: (selection) {
                  setState(() => _days = selection.first);
                  _load();
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        ],
      ),
      body: points == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : points == null
              ? EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: loc.errorOccurred,
                  subtitle: _error!,
                  actionLabel: loc.retry,
                  onAction: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.all(16.w),
                    children: [
                      _Legend(theme: theme),
                      SizedBox(height: 12.h),
                      _TrendBars(points: points, theme: theme),
                      SizedBox(height: 16.h),
                      Text(
                        loc.creatorStatsHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: theme.colorScheme.onSurface.withAlpha(110),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// 图例（播放=品牌玫瑰红 / 点赞=品牌紫 / 发布=中性）
class _Legend extends StatelessWidget {
  final ThemeData theme;

  const _Legend({required this.theme});

  Widget item(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: theme.colorScheme.onSurface.withAlpha(160),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item(BrandColor.rose, loc.creatorPlays),
        SizedBox(width: 14.w),
        item(BrandColor.violet, loc.creatorLikes),
        SizedBox(width: 14.w),
        item(
          theme.colorScheme.onSurface.withAlpha(120),
          loc.creatorPublished,
        ),
      ],
    );
  }
}

/// 柱状图：每天一组三根细柱（播放/点赞/发布），高度按全体最大值归一化
class _TrendBars extends StatelessWidget {
  final List<TrendPoint> points;
  final ThemeData theme;

  const _TrendBars({required this.points, required this.theme});

  int _maxOf(int Function(TrendPoint) pick) {
    var max = 0;
    for (final p in points) {
      final v = pick(p);
      if (v > max) max = v;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final maxPlays = _maxOf((p) => p.plays);
    final maxLikes = _maxOf((p) => p.likes);
    final maxPub = _maxOf((p) => p.published);
    final barAreaHeight = 180.h;

    if (points.isEmpty) {
      return EmptyState(icon: Icons.bar_chart_rounded, title: loc.hotListEmpty);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          SizedBox(
            height: barAreaHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in points)
                  Expanded(
                    child: Tooltip(
                      message: '${p.date}\n'
                          '${loc.creatorPlays} ${p.plays} · '
                          '${loc.creatorLikes} ${p.likes} · '
                          '${loc.creatorPublished} ${p.published}',
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _bar(maxPlays, p.plays, BrandColor.rose),
                            _bar(maxLikes, p.likes, BrandColor.violet),
                            _bar(
                              maxPub,
                              p.published,
                              theme.colorScheme.onSurface.withAlpha(110),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          // 日期轴：首/中/尾三个刻度
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in _axisLabels())
                Text(
                  d.substring(5),
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: theme.colorScheme.onSurface.withAlpha(110),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _axisLabels() {
    if (points.length <= 2) {
      return points.map((p) => p.date).toList();
    }
    final mid = points[points.length ~/ 2].date;
    return [points.first.date, mid, points.last.date];
  }

  /// 单根柱：宽度固定，高度按值/最大值占比（值 0 时给 2px 底线保持可见）
  Widget _bar(int max, int value, Color color) {
    final ratio = max <= 0 ? 0.0 : value / max;
    final height = (ratio * 160.h).clamp(2.0, 160.h);
    return Container(
      width: 5.w,
      height: height,
      margin: EdgeInsets.symmetric(horizontal: 1.w),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.vertical(top: Radius.circular(2.r)),
      ),
    );
  }
}
