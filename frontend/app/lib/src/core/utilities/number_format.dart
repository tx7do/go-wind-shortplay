/// 数字展示格式化工具（短视频计数习惯：万 / 亿 缩写）
class NumberFormatUtils {
  NumberFormatUtils._();

  /// 计数缩写：1234 → 1234，12345 → 1.2w，1234567 → 123.4w，123456789 → 1.2亿
  static String formatCount(int count) {
    if (count < 0) return '0';
    if (count < 10000) return '$count';
    if (count < 100000000) {
      final wan = count / 10000;
      return '${wan < 10 ? wan.toStringAsFixed(1) : wan.round()}w';
    }
    final yi = count / 100000000;
    return '${yi < 10 ? yi.toStringAsFixed(1) : yi.round()}亿';
  }
}
