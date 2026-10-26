import 'package:flutter/material.dart';
import 'package:frontend/core/size/responsive_size.dart';

class AppTextStyles {
  static TextStyle style(
    BuildContext context, {
    double fontSize = 14,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    TextDecoration? decoration,
    String fontFamily = 'Inter',
    TextOverflow? textOverFlow = TextOverflow.ellipsis,
    double? height = 1.18,
  }) {
    final scaledFontSize = ResponsiveSize.sp(context, fontSize);
    final resolvedFontSize = ResponsiveSize.isMobile(context)
        ? scaledFontSize + 2
        : scaledFontSize;

    return TextStyle(
      fontSize: resolvedFontSize,
      color: color ?? Colors.black,
      fontWeight: fontWeight,
      decoration: decoration ?? TextDecoration.none,
      fontFamily: fontFamily,
      height: height,
      overflow: textOverFlow,
    );
  }
}
