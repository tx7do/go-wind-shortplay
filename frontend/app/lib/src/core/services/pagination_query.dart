/// 通用分页查询参数
///
/// shortplay 后端（protojson）分页约定：`pageNum`（从 1 起）+ `pageSize`
/// （缺省 10，上限 50），部分接口用 `page`/`pageSize`（如标签列表、收藏列表）。
/// 统一封装两种形态，服务层直接 `query.toQueryMap()` 或 `query.toPageMap()`。
class PaginationQuery {
  /// 页码（从 1 起）
  final int pageNum;

  /// 每页数量（上限 50）
  final int pageSize;

  const PaginationQuery({
    this.pageNum = 1,
    this.pageSize = 10,
  });

  /// 是否第一页
  bool get isFirstPage => pageNum <= 1;

  /// 生成 `pageNum/pageSize` 形态的 query 参数（Feed/评论/通知/作品列表等）
  Map<String, dynamic> toQueryMap() {
    return {
      'pageNum': pageNum,
      'pageSize': pageSize,
    };
  }

  /// 生成 `page/pageSize` 形态的 query 参数（标签列表/收藏列表等）
  Map<String, dynamic> toPageMap() {
    return {
      'page': pageNum,
      'pageSize': pageSize,
    };
  }

  /// 下一页
  PaginationQuery nextPage() {
    return PaginationQuery(pageNum: pageNum + 1, pageSize: pageSize);
  }

  /// 复制并修改部分字段
  PaginationQuery copyWith({int? pageNum, int? pageSize}) {
    return PaginationQuery(
      pageNum: pageNum ?? this.pageNum,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

/// 通用分页响应
///
/// protojson 中 int64 的 total 是字符串（"total":"3"），需用 core.utilities
/// 的 `jsonInt` 兼容解析，由各 service 负责；本类承载解析结果供 bloc/widgets 使用。
class PageData<T> {
  final List<T> items;

  /// 总条数（后端可能缺省，缺省时用 items.length）
  final int total;

  /// 是否还有下一页（Feed 特有字段；其他列表按 total/pageNum 推断）
  final bool hasMore;

  const PageData({
    required this.items,
    this.total = 0,
    this.hasMore = false,
  });

  /// 按 total 推断是否还有下一页
  factory PageData.inferHasMore({
    required List<T> items,
    required int total,
    required int pageNum,
    required int pageSize,
  }) {
    final loaded = pageNum * pageSize;
    return PageData(
      items: items,
      total: total,
      hasMore: items.isNotEmpty && loaded < total,
    );
  }
}
