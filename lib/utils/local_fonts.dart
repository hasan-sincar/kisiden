import 'package:flutter/material.dart';

class LocalFonts {
  static TextStyle poppins({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<String>? fontFamilyFallback,
    TextOverflow? overflow,
  }) {
    return TextStyle(
      fontFamily: 'Poppins',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFamilyFallback: fontFamilyFallback,
      overflow: overflow,
    );
  }

  static TextTheme poppinsTextTheme(TextTheme base) {
    return base.apply(fontFamily: 'Poppins');
  }
}
