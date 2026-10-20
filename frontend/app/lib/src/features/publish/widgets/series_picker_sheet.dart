import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart'
    show ApiStatusException, localizedErrorText;
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/widgets/cover_image.dart';
import 'package:shortplay_app/src/features/series/services/series_service.dart';
import 'package:get_it/get_it.dart' show GetIt;

/// 选剧弹层（发布挂靠）：我的剧集分页列表 + 新建剧集入口 + 「不挂靠」。
class SeriesPickerSheet extends StatefulWidget {
  /// 当前已选剧（0=未挂靠）
  final int selectedId;

  /// 选中回调（null=取消挂靠）
  final ValueChanged<Series?> onSelected;

  const SeriesPickerSheet({
    super.key,
    this.selectedId = 0,
    required this.onSelected,
  });

  /// 弹出选剧弹层
  static Future<void> show(
    BuildContext context, {
    int selectedId = 0,
    required ValueChanged<Series?> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => SeriesPickerSheet(
        selectedId: selectedId,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<SeriesPickerSheet> createState() => _SeriesPickerSheetState();
}

class _SeriesPickerSheetState extends State<SeriesPickerSheet> {
  final SeriesService _seriesService = SeriesService();
  final ScrollController _scrollController = ScrollController();

  final List<Series> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _pageNum = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNext();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      _pageNum += 1;
      final uid = GetIt.instance<UserAuthCache>().userId;
      final page = await _seriesService.listSeries(
        authorId: uid,
        paging: PaginationQuery(pageNum: _pageNum, pageSize: 20),
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _pageNum -= 1;
      setState(() => _loading = false);
      EasyLoading.showToast(localizedErrorText(S.of(context), e));
    }
  }

  Future<void> _createSeries() async {
    final loc = S.of(context);
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.newSeries),
        content: TextField(
          controller: controller,
          maxLength: 100,
          autofocus: true,
          decoration: InputDecoration(
            labelText: loc.seriesTitleLabel,
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
    if (created != true || !mounted) return;
    final title = controller.text.trim();
    if (title.isEmpty) return;
    try {
      final series = await _seriesService.createSeries(title: title);
      if (!mounted) return;
      EasyLoading.showToast(S.of(context).seriesCreated);
      widget.onSelected(series);
      Navigator.of(context).pop();
    } on ApiStatusException catch (e) {
      EasyLoading.showToast(localizedErrorText(S.of(context), e));
    } catch (_) {
      EasyLoading.showToast(S.of(context).errorOccurred);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 12.w, 8.h),
              child: Row(
                children: [
                  Text(
                    loc.chooseSeries,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _createSeries,
                    icon: Icon(Icons.add_rounded, size: 16.sp),
                    label: Text(loc.newSeries),
                  ),
                ],
              ),
            ),
            // 不挂靠
            ListTile(
              leading: Icon(
                Icons.close_rounded,
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
              title: Text(loc.attachSeriesNone),
              selected: widget.selectedId == 0,
              onTap: () {
                widget.onSelected(null);
                Navigator.of(context).pop();
              },
            ),
            Expanded(
              child: _items.isEmpty && _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? EmptyState(
                          icon: Icons.movie_outlined,
                          title: loc.seriesEmptyMine,
                          actionLabel: loc.newSeries,
                          onAction: _createSeries,
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(bottom: 12.h),
                          itemCount:
                              _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _items.length) {
                              return Padding(
                                padding: EdgeInsets.all(10.h),
                                child: Center(
                                  child: _loading
                                      ? const CircularProgressIndicator(
                                          strokeWidth: 2)
                                      : Text(
                                          loc.allLoaded,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: theme
                                                .colorScheme.onSurface
                                                .withAlpha(110),
                                          ),
                                        ),
                                ),
                              );
                            }
                            final series = _items[index];
                            final selected = series.id == widget.selectedId;
                            return ListTile(
                              leading: CoverImage(
                                url: series.coverDisplayUrl,
                                width: 56.w,
                                height: 38.h,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              title: Text(
                                series.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                loc.seriesUpdatedTo(
                                  series.publishedCount,
                                  series.episodeCount,
                                ),
                                style: TextStyle(fontSize: 11.sp),
                              ),
                              trailing: selected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: theme.colorScheme.primary,
                                    )
                                  : null,
                              onTap: () {
                                widget.onSelected(series);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
