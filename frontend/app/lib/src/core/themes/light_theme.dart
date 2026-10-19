import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';
import 'const.dart';
import 'fonts.dart';
import 'snackbar_color.dart' show SnackBarColor;
import 'app_theme_extension.dart';

/// 默认主题色（品牌玫瑰红，与 App 图标渐变同源）
const Color kDefaultSeedColor = BrandColor.rose;

class LightColor {
  static const Color bgColor = LightPalette.bg;
  static const Color primaryColor = BrandColor.rose;
  static const Color onPrimaryColor = Colors.white;
  static const Color inputTextColor = Color(0xFF17171C);
  static const Color inputFillColor = LightPalette.inputFill;
  static const Color cursorColor = BrandColor.rose;
  static const Color accentColor = BrandColor.violet;
}

/// 亮色语义色板（显式指定，不走 MD3 fromSeed 的粉彩调和）
ColorScheme _buildLightColorScheme(Color seedColor) => ColorScheme(
  brightness: Brightness.light,
  primary: seedColor,
  onPrimary: LightColor.onPrimaryColor,
  primaryContainer: const Color(0xFFFFE9F1),
  onPrimaryContainer: const Color(0xFFC21E52),
  secondary: BrandColor.violet,
  onSecondary: Colors.white,
  secondaryContainer: const Color(0xFFF1EBFF),
  onSecondaryContainer: const Color(0xFF6D28D9),
  tertiary: BrandColor.violet,
  onTertiary: Colors.white,
  tertiaryContainer: const Color(0xFFF1EBFF),
  onTertiaryContainer: const Color(0xFF6D28D9),
  error: const Color(0xFFF53F3F),
  onError: Colors.white,
  errorContainer: const Color(0xFFFFECEC),
  onErrorContainer: const Color(0xFFC02929),
  surface: LightPalette.surface,
  onSurface: const Color(0xFF1B1B22),
  onSurfaceVariant: const Color(0xFF6E6E7A),
  outline: const Color(0xFFE3E3EC),
  outlineVariant: LightPalette.divider,
  shadow: Colors.black,
  inverseSurface: LightPalette.snackBar,
  onInverseSurface: LightPalette.onSnackBar,
  inversePrimary: BrandColor.roseBright,
  surfaceTint: Colors.transparent,
);

/// 标题栏主题
final _appBarTheme = AppBarTheme(
  backgroundColor: LightPalette.surface,
  surfaceTintColor: Colors.transparent,
  titleSpacing: kDefaultPadding,
  elevation: 0,
  scrolledUnderElevation: 0.5,
  titleTextStyle: TextStyle(
    color: const Color(0xFF1B1B22),
    fontSize: 17.sp,
    fontWeight: FontWeight.w700,
  ),
  iconTheme: const IconThemeData(color: Color(0xFF1B1B22)),
);

/// 实心主按钮
final _elevatedButtonTheme = ElevatedButtonThemeData(
  style: ButtonStyle(
    elevation: WidgetStateProperty.all(0),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return const Color(0xFFE8E8EF);
      }
      return LightColor.primaryColor;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return const Color(0xFF9C9CA8);
      }
      return Colors.white;
    }),
    textStyle: WidgetStateProperty.all(
      TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
    ),
    minimumSize: WidgetStateProperty.all(Size(0, 46.h)),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
);

/// 描边次按钮
final _outlinedButtonTheme = OutlinedButtonThemeData(
  style: ButtonStyle(
    textStyle: WidgetStateProperty.all(
      TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
    ),
    minimumSize: WidgetStateProperty.all(Size(0, 46.h)),
    side: WidgetStateProperty.resolveWith((states) {
      final color = states.contains(WidgetState.disabled)
          ? const Color(0xFFD9D9E3)
          : LightColor.primaryColor.withAlpha(150);
      return BorderSide(color: color, width: 1.2);
    }),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
);

/// 文本按钮
final _textButtonTheme = TextButtonThemeData(
  style: ButtonStyle(
    foregroundColor: WidgetStateProperty.all(BrandColor.roseDeep),
    textStyle: WidgetStateProperty.all(
      TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
    ),
  ),
);

/// 文本
const _textSelectionThemeData = TextSelectionThemeData(
  selectionColor: Color(0xFFFFD3E1),
  selectionHandleColor: BrandColor.rose,
  cursorColor: LightColor.cursorColor,
);

/// 图标
const _iconTheme = IconThemeData(color: Color(0xFF1B1B22));

///
const _snackBarColor = SnackBarColor(
  error: Color(0xFFF53F3F),
  info: Color(0xFF10B981),
  warning: Color(0xFFFFB43A),
  success: Color(0xFF10B981),
);

/// 弹出菜单
const _popupMenuTheme = PopupMenuThemeData(
  color: LightPalette.surface,
  surfaceTintColor: Colors.transparent,
  iconColor: Color(0xFF1B1B22),
  elevation: 8,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  ),
);

/// 分割线
const _dividerTheme = DividerThemeData(color: LightPalette.divider);

/// 构建 Scrollbar 主题
ScrollbarThemeData _buildScrollbarTheme(Color primaryColor) => ScrollbarThemeData(
  thumbColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.hovered)) {
      return primaryColor.withAlpha((0.5 * 255).round());
    }
    return primaryColor.withAlpha((0.25 * 255).round());
  }),
  radius: const Radius.circular(4),
  thickness: WidgetStateProperty.all(6),
  thumbVisibility: WidgetStateProperty.all(true),
);

/// 输入框：填充式圆角，聚焦时品牌色描边（国内主流表单样式）
InputDecorationTheme _buildInputDecorationTheme(ColorScheme colorScheme) =>
    InputDecorationTheme(
      filled: true,
      fillColor: LightPalette.inputFill,
      hintStyle: TextStyle(color: const Color(0xFF9C9CA8), fontSize: 14.sp),
      labelStyle: TextStyle(color: const Color(0xFF6E6E7A), fontSize: 14.sp),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF53F3F), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF53F3F), width: 1.4),
      ),
    );

/// 正文/标题字阶：中文重字重层级（比 MD3 默认更紧凑有力）
TextTheme _buildTextTheme() => TextTheme(
  headlineMedium: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w800, height: 1.25),
  headlineSmall: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, height: 1.25),
  titleLarge: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, height: 1.3),
  titleMedium: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, height: 1.35),
  titleSmall: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, height: 1.35),
  bodyLarge: TextStyle(fontSize: 15.sp, height: 1.5),
  bodyMedium: TextStyle(fontSize: 14.sp, height: 1.5),
  bodySmall: TextStyle(fontSize: 12.sp, height: 1.45),
  labelLarge: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
  labelMedium: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
  labelSmall: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w500),
);

///
ThemeData _buildLightTheme(Color seedColor) {
  final colorScheme = _buildLightColorScheme(seedColor);
  return ThemeData(
    platform: TargetPlatform.iOS,
    useMaterial3: true,
    fontFamily: kDefaultFontFamily,
    fontFamilyFallback: AppFont.fontFamilyFallback,
    textTheme: _buildTextTheme(),
    colorScheme: colorScheme,
    scaffoldBackgroundColor: LightColor.bgColor,
    primaryColor: colorScheme.primary,
    appBarTheme: _appBarTheme,
    textSelectionTheme: _textSelectionThemeData,
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    textButtonTheme: _textButtonTheme,
    filledButtonTheme: FilledButtonThemeData(
      style: _elevatedButtonTheme.style,
    ),
    iconTheme: _iconTheme,
    popupMenuTheme: _popupMenuTheme,
    dividerTheme: _dividerTheme,
    scrollbarTheme: _buildScrollbarTheme(colorScheme.primary),
    inputDecorationTheme: _buildInputDecorationTheme(colorScheme),
    cardTheme: CardThemeData(
      elevation: 0,
      color: LightPalette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: LightPalette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      titleTextStyle: TextStyle(
        color: const Color(0xFF1B1B22),
        fontSize: 17.sp,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: const Color(0xFF1B1B22).withAlpha(200),
        fontSize: 14.sp,
        height: 1.5,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: LightPalette.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: LightPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: BrandColor.roseDeep,
      unselectedLabelColor: const Color(0xFF8A8A96),
      labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
      indicatorColor: BrandColor.rose,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: LightPalette.chipFill,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
      ),
      labelStyle: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF4A4A56),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: LightPalette.snackBar,
      contentTextStyle: TextStyle(fontSize: 13.sp, color: LightPalette.onSnackBar),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return const Color(0xFFB9B9C6);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return const Color(0xFFE3E3EC);
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BrandColor.rose,
      linearTrackColor: Color(0xFFE8E8EF),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: LightPalette.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      AppThemeExtension(snackBarColor: _snackBarColor),
    ]);
}

/// 获取光亮系主题
/// [seedColor] 种子颜色，用于动态生成配色方案
ThemeData getLightTheme({Color? seedColor}) {
  final color = seedColor ?? kDefaultSeedColor;
  return _buildLightTheme(color);
}
