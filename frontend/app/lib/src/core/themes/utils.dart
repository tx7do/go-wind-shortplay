import 'package:flutter/material.dart';

// 调用的时候需要把hex改一下，比如#223344 needs change to 0xFF223344
// 即把#换成0xFF即可
MaterialColor createMaterialColor(Color color) {
  const List<double> strengths = <double>[.05];
  final Map<int, Color> swatch = <int, Color>{};
  final int argb = color.toARGB32();
  final int r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.toARGB32(), swatch);
}
