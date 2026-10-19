import 'package:flutter/material.dart';

/// 品牌设计令牌（与 App 图标「玫瑰红→紫」渐变同源，docs/design-language.md）
///
/// 国内 C 端短视频审美基线：高饱和品牌色 + 大圆角 + 重标题字重，
/// 刻意避开 MD3 默认的粉彩容器 / 胶囊指示器观感。
class BrandColor {
  BrandColor._();

  /// 品牌主色（App 图标渐变起点，点赞/主 CTA 同色）
  static const Color rose = Color(0xFFFF3D77);

  /// 品牌渐变终点（紫）
  static const Color violet = Color(0xFF8B5CF6);

  /// 深一档的玫瑰红（白底小字号文本用，保证对比度）
  static const Color roseDeep = Color(0xFFE62E66);

  /// 暗色模式主色（黑底上提亮一档）
  static const Color roseBright = Color(0xFFFF5C8F);

  /// 收藏 / 星标（国内习惯的琥珀黄，与点赞红区分）
  static const Color collect = Color(0xFFFFB43A);

  /// 品牌渐变（左上→右下 135°）
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [rose, violet],
  );
}

/// 亮色模式语义色
class LightPalette {
  static const Color bg = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color inputFill = Color(0xFFF2F3F8);
  static const Color chipFill = Color(0xFFF1F2F7);
  static const Color divider = Color(0xFFECECF2);
  static const Color snackBar = Color(0xFF2B2B33);
  static const Color onSnackBar = Color(0xFFF5F5FA);
}

/// 暗色模式语义色（深空黑微紫调，非纯灰）
class DarkPalette {
  static const Color bg = Color(0xFF0C0C12);
  static const Color surface = Color(0xFF16161E);
  static const Color card = Color(0xFF1E1E28);
  static const Color inputFill = Color(0xFF23232E);
  static const Color chipFill = Color(0xFF23232E);
  static const Color divider = Color(0xFF262631);
  static const Color snackBar = Color(0xFF2E2E3A);
  static const Color onSnackBar = Color(0xFFF5F5FA);
}
