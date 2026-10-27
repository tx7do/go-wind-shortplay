import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/api_error_messages.dart'
    show localizedErrorText;
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/common/widgets/video_card.dart';
import 'package:shortplay_app/src/features/history/services/history_service.dart';

/// 分页观看历史列表（我的页「历史」tab）
class PagedHistoryList extends StatefulWidget {
  final String? emptyText;

  const PagedHistoryList({super.key, this.emptyText});

  @override
  State<PagedHistoryList> createState() => _PagedHistoryListState();
}

class _PagedHistoryListState extends State<PagedHistoryList> {
  final ScrollController _scrollController = ScrollController();
  final HistoryService _historyService = HistoryService();
  final List<HistoryEntry> _items = [];

  bool _loading = false;
  bool _hasMore = true;
  String? _error;
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
        _scrollController.position.maxScrollExtent - 300) {
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      _pageNum += 1;
      final page = await _historyService.history(
        paging: PaginationQuery(pageNum: _pageNum, pageSize: 10),
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      _pageNum -= 1;
      setState(() {
        _loading = false;
        _error = localizedErrorText(S.of(context), e);
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _pageNum = 0;
      _hasMore = true;
    });
    await _loadNext();
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);

    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: loc.errorOccurred,
        subtitle: _error!,
        actionLabel: loc.retry,
        onAction: _refresh,
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: widget.emptyText ?? loc.historyEmpty,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            itemCount: _items.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) => SizedBox(height: 4.h),
            itemBuilder: (context, index) {
              if (index >= _items.length) {
                return Padding(
                  padding: EdgeInsets.all(12.h),
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : Text(
                            loc.allLoaded,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: theme.colorScheme.onSurface.withAlpha(110),
                            ),
                          ),
                  ),
                );
              }
              final entry = _items[index];
              final video = entry.video;
              final card = VideoListCard(video: video);
              // 断点续播进度条（有进度且未到片尾）
              if (!entry.resumable) return card;
              final ratio = (entry.progressSeconds / video.duration).clamp(
                0.0,
                1.0,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  card,
                  Transform.translate(
                    offset: Offset(0, -6.h),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 3.h,
                          valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.primary,
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(24),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
