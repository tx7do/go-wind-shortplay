import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/features/common/services/tag_service.dart';
import 'package:shortplay_app/src/features/common/widgets/paged_video_list.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/search/services/search_service.dart';

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
            onSubmitted: (value) =>
                setState(() => _keyword = value.trim()),
            style: TextStyle(fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: loc.searchHint,
              prefixIcon: const Icon(Icons.search),
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
              fillColor: theme.colorScheme.surfaceContainerHighest,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.r),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
          ),
        ),
      ),
      body: hasKeyword
          ? PagedVideoList(
              key: ValueKey('search-$_keyword'),
              loader: _loader,
              emptyText: loc.searchEmpty(_keyword),
            )
          : _buildHotTags(theme, loc),
    );
  }

  Widget _buildHotTags(ThemeData theme, S loc) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department,
              size: 16.sp,
              color: theme.colorScheme.error,
            ),
            SizedBox(width: 4.w),
            Text(
              loc.hotTags,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (_hotTags.isEmpty)
          Text(
            loc.searchSomeKeyword,
            style: TextStyle(
              fontSize: 13.sp,
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          )
        else
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: _hotTags.map((tag) {
              return ActionChip(
                label: Text('#$tag'),
                onPressed: () {
                  _controller.text = '#$tag';
                  setState(() => _keyword = '#$tag');
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
