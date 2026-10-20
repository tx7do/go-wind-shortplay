import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/features/common/services/tag_service.dart';
import 'package:shortplay_app/src/features/common/widgets/paged_video_list.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
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
      });
    }
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

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _keyword = value.trim());
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
          : _buildHotTags(theme, loc),
    );
  }

  Widget _buildHotTags(ThemeData theme, S loc) {
    final isDark = theme.brightness == Brightness.dark;
    // 榜单式配色：前三名品牌渐变系高亮，其余中性
    final rankColors = [
      isDark ? BrandColor.roseBright : BrandColor.roseDeep,
      BrandColor.violet,
      isDark ? const Color(0xFFFFB43A) : const Color(0xFFE8890C),
    ];

    if (_hotTags.isEmpty) {
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
