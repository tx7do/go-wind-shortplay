import 'package:get_it/get_it.dart' show GetIt;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shortplay_app/src/core/utilities/logger.dart' show debug;

/// 本地搜索历史（SharedPreferences 持久化，最近在前，去重、容量裁剪）
class SearchHistoryStore {
  SearchHistoryStore();

  static const String _key = 'sp.search.history';
  static const int _cap = 10;

  /// 内存缓存（load 后生效；变更同步落盘，尽力而为）
  List<String> _items = [];

  List<String> get items => List.unmodifiable(_items);

  /// 启动装载（尽力而为：读取失败视为空）
  Future<void> load() async {
    try {
      final prefs = GetIt.instance<SharedPreferences>();
      _items = prefs.getStringList(_key) ?? const [];
    } catch (e) {
      debug('load search history failed (ignored): $e');
    }
  }

  /// 记录一次搜索（去重置顶；与栈顶相同则忽略）
  Future<void> record(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return;
    if (_items.isNotEmpty && _items.first == kw) return;
    _items
      ..remove(kw)
      ..insert(0, kw);
    if (_items.length > _cap) {
      _items.removeRange(_cap, _items.length);
    }
    await _persist();
  }

  /// 清空
  Future<void> clear() async {
    _items = [];
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = GetIt.instance<SharedPreferences>();
      await prefs.setStringList(_key, _items);
    } catch (e) {
      debug('persist search history failed (ignored): $e');
    }
  }
}

/// 全局单例（页面间共享同一份历史）
final SearchHistoryStore searchHistoryStore = SearchHistoryStore();
