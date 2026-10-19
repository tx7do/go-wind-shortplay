import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';
import 'const.dart';
import 'fonts.dart';
import 'snackbar_color.dart' show SnackBarColor;
import 'app_theme_extension.dart';

class DarkColor {
  // 深空黑微紫调（docs/design-language.md 深色模式），非死黑非蓝灰
  static const Color bgColor = DarkPalette.bg;
  static const Color surfaceColor = DarkPalette.surface;
  static const Color cardColor = DarkPalette.card;
  static const Color onSurface = Color(0xFFF4F4F8);
  static const Color cursorColor = BrandColor.roseBright;
}

/// 暗色语义色板（显式指定，主色提亮一档保证黑底可读）
ColorScheme _buildDarkColorScheme(Color seedColor) => ColorScheme(
  brightness: Brightness.dark,
  primary: BrandColor.roseBright,
  onPrimary: Colors.white,
  primaryContainer: const Color(0xFF3D1526),
  onPrimaryContainer: const Color(0xFFFFD3E1),
  secondary: const Color(0xFFA78BFA),
  onSecondary: const Color(0xFF1B1030),
  secondaryContainer: const Color(0xFF291D3F),
  onSecondaryContainer: const Color(0xFFE4D8FF),
  tertiary: const Color(0xFFA78BFA),
  onTertiary: const Color(0xFF1B1030),
  tertiaryContainer: const Color(0xFF291D3F),
  onTertiaryContainer: const Color(0xFFE4D8FF),
  error: const Color(0xFFFF6B6B),
  onError: Colors.white,
  errorContainer: const Color(0xFF3D1414),
  onErrorContainer: const Color(0xFFFFD1D1),
  surface: DarkPalette.surface,
  onSurface: DarkColor.onSurface,
  onSurfaceVariant: const Color(0xFF9B9BA8),
  outline: const Color(0xFF33333F),
  outlineVariant: DarkPalette.divider,
  shadow: Colors.black,
  inverseSurface: DarkPalette.snackBar,
  onInverseSurface: DarkPalette.onSnackBar,
  inversePrimary: BrandColor.rose,
  surfaceTint: Colors.transparent,
);

/// 标题栏主题
AppBarTheme _buildAppBarTheme(ColorScheme colorScheme) => AppBarTheme(
  backgroundColor: DarkPalette.surface,
  surfaceTintColor: Colors.transparent,
  titleSpacing: kDefaultPadding,
  elevation: 0,
  scrolledUnderElevation: 0.5,
  titleTextStyle: TextStyle(
    color: DarkColor.onSurface,
    fontSize: 17.sp,
    fontWeight: FontWeight.w700,
  ),
  iconTheme: IconThemeData(color: DarkColor.onSurface),
);

/// 实心主按钮
FilledButtonThemeData _buildFilledButtonTheme(ColorScheme colorScheme) =>
    FilledButtonThemeData(
      style: ButtonStyle(
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF2C2C38);
          }
          return colorScheme.primary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF6E6E7C);
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
OutlinedButtonThemeData _buildOutlinedButtonTheme(ColorScheme colorScheme) =>
    OutlinedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
        ),
        minimumSize: WidgetStateProperty.all(Size(0, 46.h)),
        side: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.disabled)
              ? const Color(0xFF2C2C38)
              : colorScheme.primary.withAlpha(170);
          return BorderSide(color: color, width: 1.2);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF6E6E7C);
          }
          return colorScheme.primary;
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );

/// 文本按钮
TextButtonThemeData _buildTextButtonTheme(ColorScheme colorScheme) =>
    TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(colorScheme.primary),
        textStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );

/// 文本选择
TextSelectionThemeData _buildTextSelectionTheme(Color seedColor) =>
    TextSelectionThemeData(
      selectionColor: seedColor.withAlpha((0.4 * 255).round()),
      selectionHandleColor: seedColor,
      cursorColor: DarkColor.cursorColor,
    );

/// 图标
const _iconTheme = IconThemeData(color: DarkColor.onSurface);

///
const _snackBarColor = SnackBarColor(
  error: Color(0xFFFF6B6B),
  info: Color(0xFF34D399),
  warning: Color(0xFFFFB43A),
  success: Color(0xFF34D399),
);

/// 弹出菜单
PopupMenuThemeData _buildPopupMenuTheme(ColorScheme colorScheme) =>
    PopupMenuThemeData(
      color: DarkColor.cardColor,
      surfaceTintColor: Colors.transparent,
      iconColor: DarkColor.onSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    );

/// 分割线
const _dividerTheme = DividerThemeData(color: DarkPalette.divider);

/// 构建 Scrollbar 主题
ScrollbarThemeData _buildScrollbarTheme(Color seedColor) => ScrollbarThemeData(
  thumbColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.hovered)) {
      return seedColor.withAlpha((0.5 * 255).round());
    }
    return seedColor.withAlpha((0.3 * 255).round());
  }),
  radius: const Radius.circular(4),
  thickness: WidgetStateProperty.all(6),
  thumbVisibility: WidgetStateProperty.all(true),
);

/// 输入框：填充式圆角，聚焦时品牌色描边
InputDecorationTheme _buildInputDecorationTheme(ColorScheme colorScheme) =>
    InputDecorationTheme(
      filled: true,
      fillColor: DarkPalette.inputFill,
      hintStyle: TextStyle(color: const Color(0xFF6E6E7C), fontSize: 14.sp),
      labelStyle: TextStyle(color: const Color(0xFF9B9BA8), fontSize: 14.sp),
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
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error, width: 1.4),
      ),
    );

/// 正文/标题字阶：与亮色一致的重字重层级
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
ThemeData _buildDarkTheme(Color seedColor) {
  final colorScheme = _buildDarkColorScheme(seedColor);
  return ThemeData(
    platform: TargetPlatform.iOS,
    useMaterial3: true,
    fontFamily: kDefaultFontFamily,
    fontFamilyFallback: AppFont.fontFamilyFallback,
    textTheme: _buildTextTheme(),
    colorScheme: colorScheme,
    scaffoldBackgroundColor: DarkColor.bgColor,
    primaryColor: colorScheme.primary,
    appBarTheme: _buildAppBarTheme(colorScheme),
    textSelectionTheme: _buildTextSelectionTheme(seedColor),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _buildFilledButtonTheme(colorScheme).style,
    ),
    outlinedButtonTheme: _buildOutlinedButtonTheme(colorScheme),
    textButtonTheme: _buildTextButtonTheme(colorScheme),
    filledButtonTheme: _buildFilledButtonTheme(colorScheme),
    iconTheme: _iconTheme,
    popupMenuTheme: _buildPopupMenuTheme(colorScheme),
    dividerTheme: _dividerTheme,
    scrollbarTheme: _buildScrollbarTheme(seedColor),
    inputDecorationTheme: _buildInputDecorationTheme(colorScheme),
    cardTheme: CardThemeData(
      elevation: 0,
      color: DarkColor.cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: DarkColor.cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      titleTextStyle: TextStyle(
        color: DarkColor.onSurface,
        fontSize: 17.sp,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: DarkColor.onSurface.withAlpha(200),
        fontSize: 14.sp,
        height: 1.5,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: DarkPalette.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: DarkPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      dragHandleColor: const Color(0xFF3C3C4A),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: BrandColor.roseBright,
      unselectedLabelColor: const Color(0xFF8A8A96),
      labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
      indicatorColor: BrandColor.roseBright,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: DarkPalette.chipFill,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
      ),
      labelStyle: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFC6C6D2),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: DarkPalette.snackBar,
      contentTextStyle: TextStyle(fontSize: 13.sp, color: DarkPalette.onSnackBar),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return const Color(0xFF55555F);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return const Color(0xFF33333F);
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BrandColor.roseBright,
      linearTrackColor: Color(0xFF2C2C38),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: DarkPalette.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      AppThemeExtension(snackBarColor: _snackBarColor),
    ],
  );
}

/// 获取暗黑系主题
/// [seedColor] 种子颜色，用于动态生成配色方案
ThemeData getDarkTheme({Color? seedColor}) {
  final color = seedColor ?? BrandColor.rose;
  return _buildDarkTheme(color);
}
