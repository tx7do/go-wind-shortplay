/// JSON 解析的防御式取值工具。
///
/// 后端字段以 camelCase 为主，但个别接口（如上传任务）文档中出现了
/// snake_case，这里统一做宽松解析。
library;

// ignore_for_file: avoid_redundant_argument_values

int asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String && v.isNotEmpty) return int.tryParse(v);
  return null;
}

String asStr(Object? v, [String fallback = '']) {
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return fallback;
}

/// 通用分页结果。
class PageData<T> {
  const PageData({
    required this.items,
    required this.hasMore,
    this.total = 0,
  });

  final List<T> items;
  final bool hasMore;
  final int total;

  /// 从 `{"items":[...],"total":n,"hasMore":bool}` 形态解析。
  ///
  /// 部分接口不返回 hasMore，则按 `pageNum * pageSize < total` 推断。
  static PageData<T> parse<T>(
    Map<String, dynamic> json, {
    required T Function(Map<String, dynamic>) parseItem,
    required int pageNum,
    required int pageSize,
    String itemsKey = 'items',
  }) {
    final rawItems = json[itemsKey];
    final items = <T>[];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map<String, dynamic>) items.add(parseItem(e));
      }
    }
    final total = asInt(json['total']);
    final hasMore =
        asBool(json['hasMore'], items.isNotEmpty && pageNum * pageSize < total);
    return PageData(items: items, hasMore: hasMore, total: total);
  }
}
