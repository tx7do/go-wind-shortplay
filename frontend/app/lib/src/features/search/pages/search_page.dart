import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/common/services/tag_service.dart';
import 'package:shortplay_app/src/features/common/widgets/paged_video_list.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/search/services/search_history_store.dart';
import 'package:shortplay_app/src/features/search/services/search_service.dart';
import 'package:shortplay_app/src/features/series/widgets/paged_series_list.dart';

/// 搜索页：关键词/标签搜索封面卡片列表 → 进详情
class SearchPage extends StatefulWidget {
  /// 初始关键词（feed 标签点击等场景）
  final String? initialKeyword;

  const SearchPage({super.key, this.initialKeyword});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SearchService _searchService = SearchService();
  final TagService _tagService = TagService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _keyword = '';
  Timer? _debounce;
  List<String> _hotTags = [];
  List<String> _hotKeywords = [];

  /// 本地搜索历史（[SearchHistoryStore] 内存镜像，setState 驱动）
  List<String> _history = const [];

  @override
  void initState() {
    super.initState();
    _keyword = widget.initialKeyword ?? '';
    _controller.text = _keyword;
    if (_keyword.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
        _loadHotTags();
        _loadHotKeywords();
      });
    }
    _history = searchHistoryStore.items;
    // 首次进入装载本地历史（后续共享内存缓存）
    searchHistoryStore.load().then((_) {
      if (mounted) setState(() => _history = searchHistoryStore.items);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHotTags() async {
    try {
      final page = await _tagService.list(
        const PaginationQuery(pageNum: 1, pageSize: 15),
      );
      if (!mounted) return;
      setState(() => _hotTags = page.items.map((t) => t.name).toList());
    } catch (_) {
      // 热门标签失败静默
    }
  }

  Future<void> _loadHotKeywords() async {
    // 热搜词（服务端按真实搜索频次聚合）尽力而为
    final kws = await _searchService.hotKeywords(limit: 10);
    if (!mounted) return;
    setState(() => _hotKeywords = kws);
  }

  /// 记录搜索历史（去重置顶，落盘尽力而为）
  Future<void> _recordHistory(String keyword) async {
    await searchHistoryStore.record(keyword);
    if (!mounted) return;
    setState(() => _history = searchHistoryStore.items);
  }

  /// 清空搜索历史
  Future<void> _clearHistory() async {
    await searchHistoryStore.clear();
    if (!mounted) return;
    setState(() => _history = const []);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final kw = value.trim();
      if (!mounted) return;
      setState(() => _keyword = kw);
      if (kw.isNotEmpty && !kw.startsWith('#')) {
        unawaited(_recordHistory(kw));
      }
    });
  }

  /// 剧集搜索（剧名模糊；# 标签开头不出剧集结果）
  Future<PageData<Series>> _seriesLoader(PaginationQuery query) async {
    final keyword = _keyword.replaceFirst(RegExp('^#'), '');
    if (keyword.isEmpty || _keyword.startsWith('#')) {
      return const PageData<Series>(items: [], hasMore: false);
    }
    return _searchService.searchSeries(keyword: keyword, query: query);
  }

  /// 关键词搜索 / 标签聚合（# 开头走标签精确匹配）
  Future<PageData<Video>> _loader(PaginationQuery query) async {
    final keyword = _keyword.replaceFirst(RegExp('^#'), '');
    if (keyword.isEmpty) {
      return const PageData<Video>(items: [], hasMore: false);
    }
    if (_keyword.startsWith('#')) {
      return _searchService.byTag(tag: keyword, query: query);
    }
    return _searchService.search(keyword: keyword, query: query);
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);
    final hasKeyword = _keyword.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.only(right: 16.w),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (value) => setState(() => _keyword = value.trim()),
            style: TextStyle(fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: loc.searchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              prefixIconColor: theme.colorScheme.onSurface.withAlpha(110),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _keyword = '');
                        _focusNode.requestFocus();
                      },
                    ),
              filled: true,
              fillColor: theme.colorScheme.onSurface.withAlpha(12),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 8.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
          ),
        ),
      ),
      body: hasKeyword
          ? DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: loc.videosTab),
                      Tab(text: loc.seriesTab),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        PagedVideoList(
                          key: ValueKey('search-video-$_keyword'),
                          loader: _loader,
                          emptyText: loc.searchEmpty(_keyword),
                        ),
                        PagedSeriesList(
                          key: ValueKey('search-series-$_keyword'),
                          loader: _seriesLoader,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : _buildDiscover(theme, loc),
    );
  }

  Widget _buildDiscover(ThemeData theme, S loc) {
    final isDark = theme.brightness == Brightness.dark;
    // 榜单式配色：前三名品牌渐变系高亮，其余中性
    final rankColors = [
      isDark ? BrandColor.roseBright : BrandColor.roseDeep,
      BrandColor.violet,
      isDark ? const Color(0xFFFFB43A) : const Color(0xFFE8890C),
    ];

    if (_hotTags.isEmpty && _hotKeywords.isEmpty && _history.isEmpty) {
      return EmptyState(
        icon: Icons.search_rounded,
        title: loc.searchSomeKeyword,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // 本地搜索历史（chips + 清空）
            if (_history.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 18.sp,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      loc.searchHistory,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _clearHistory,
                    borderRadius: BorderRadius.circular(100),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 14.sp,
                            color: theme.colorScheme.onSurface.withAlpha(120),
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            loc.searchHistoryClear,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: _history
                    .map(
                      (kw) => InkWell(
                        onTap: () {
                          _controller.text = kw;
                          setState(() => _keyword = kw);
                        },
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withAlpha(14),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            kw,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: theme.colorScheme.onSurface.withAlpha(200),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 18.h),
            ],
            // 热搜词（服务端按真实搜索频次聚合）
            if (_hotKeywords.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 18.sp,
                    color: BrandColor.rose,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    loc.hotKeywords,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              ...List.generate(_hotKeywords.length, (index) {
                final kw = _hotKeywords[index];
                final rank = index + 1;
                final rankColor = index < rankColors.length
                    ? rankColors[index]
                    : theme.colorScheme.onSurface.withAlpha(110);
                return InkWell(
                  onTap: () {
                    _controller.text = kw;
                    setState(() => _keyword = kw);
                  },
                  borderRadius: BorderRadius.circular(10.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 10.h,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22.w,
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              color: rankColor,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            kw,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: index < 3
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              SizedBox(height: 18.h),
            ],
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 18.sp,
                  color: BrandColor.rose,
                ),
                SizedBox(width: 6.w),
                Text(
                  loc.hotTags,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            ...List.generate(_hotTags.length, (index) {
              final tag = _hotTags[index];
              final rank = index + 1;
              final rankColor = index < rankColors.length
                  ? rankColors[index]
                  : theme.colorScheme.onSurface.withAlpha(110);
              return InkWell(
                onTap: () {
                  _controller.text = '#$tag';
                  setState(() => _keyword = '#$tag');
                },
                borderRadius: BorderRadius.circular(10.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6.w,
                    vertical: 11.h,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22.w,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            color: rankColor,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: index < 3
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (index < 3)
                        Icon(
                          Icons.local_fire_department,
                          size: 14.sp,
                          color: rankColor,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
