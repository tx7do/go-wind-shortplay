/// 类型转换工具集
library;

/// 字符串解析成Duration
Duration parseDuration(String s) {
  int hours = 0;
  int minutes = 0;
  int micros;
  List<String> parts = s.split(':');
  if (parts.length > 2) {
    hours = int.parse(parts[parts.length - 3]);
  }
  if (parts.length > 1) {
    minutes = int.parse(parts[parts.length - 2]);
  }
  micros = (double.parse(parts[parts.length - 1]) * 1000000).round();
  return Duration(hours: hours, minutes: minutes, microseconds: micros);
}

/// 字符串解析成Duration（单位：秒）
Duration secondStringToDuration(String second) {
  if (second.isEmpty) {
    return const Duration();
  }

  var n = int.parse(second);
  return Duration(seconds: n);
}

/// 解析bool字符串
bool parseBool(String s) {
  if (s.isEmpty) {
    return false;
  }
  return bool.parse(s);
}

/// 解析 protojson 风格的整数字段
///
/// 后端为 protojson 序列化：int64/uint64 一律输出为字符串（如 "likeCount":"1"），
/// uint32/int32 输出为 JSON 数字。本函数兼容两种形态，统一转成 Dart int。
int jsonInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
    final doubleParsed = double.tryParse(value);
    if (doubleParsed != null) return doubleParsed.round();
  }
  return fallback;
}

/// 解析 protojson 风格的字符串/枚举字段（枚举为字符串全名，如 "VIDEO_STATUS_PUBLISHED"）
String jsonString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

/// 安全解析 bool（protojson 中 bool 为 JSON 布尔，缺省 false）
bool jsonBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is String) return value == 'true' || value == '1';
  if (value is num) return value != 0;
  return fallback;
}
