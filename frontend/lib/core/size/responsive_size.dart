import 'package:flutter/widgets.dart';
import 'responsive_mobile_size.dart';
import 'responsive_desktop_size.dart';

class ResponsiveSize {
  static bool _isMobile(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    const mobileBase = 430.0;
    const desktopBase = 1512.0;

    return (width - mobileBase).abs() < (width - desktopBase).abs();
  }

  static double rw(BuildContext context, double size) {
    return _isMobile(context)
        ? ResponsiveMobileSize.rw(context, size)
        : ResponsiveDesktopSize.rw(context, size);
  }

  static double rh(BuildContext context, double size) {
    return _isMobile(context)
        ? ResponsiveMobileSize.rh(context, size)
        : ResponsiveDesktopSize.rh(context, size);
  }

  static double sp(BuildContext context, double size) {
    return _isMobile(context)
        ? ResponsiveMobileSize.sp(context, size)
        : ResponsiveDesktopSize.sp(context, size);
  }

  static bool isMobile(BuildContext context) {
    return _isMobile(context);
  }
}
