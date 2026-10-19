import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/api_error_messages.dart'
    show localizedErrorText;
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/widgets/video_card.dart';

/// 分页视频列表（作品 / 收藏 / 搜索结果共用）
///
/// 滚动到底自动翻页；空态/错误态由 [emptyText] / 错误重试兜底。
class PagedVideoList extends StatefulWidget {
  /// 分页加载函数
  final Future<PageData<Video>> Function(PaginationQuery query) loader;

  /// 角标文案（如本人作品的状态）
  final String? Function(Video video)? badgeOf;

  final String? emptyText;

  const PagedVideoList({
    super.key,
    required this.loader,
    this.badgeOf,
    this.emptyText,
  });

  @override
  State<PagedVideoList> createState() => _PagedVideoListState();
}

class _PagedVideoListState extends State<PagedVideoList> {
  final ScrollController _scrollController = ScrollController();
  final List<Video> _items = [];

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
      final page = await widget.loader(
        PaginationQuery(pageNum: _pageNum, pageSize: 10),
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
        icon: Icons.movie_filter_outlined,
        title: widget.emptyText ?? loc.noWorksYet,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      // 宽窗（桌面/平板横屏）下列表内容收窄居中，避免全屏拉伸
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
              final video = _items[index];
              return VideoListCard(
                video: video,
                badgeLabel: widget.badgeOf?.call(video),
              );
            },
          ),
        ),
      ),
    );
  }
}
