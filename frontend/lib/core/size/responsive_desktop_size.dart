import 'package:flutter/widgets.dart';

class ResponsiveDesktopSize {
  static final double _baseHeight = 982.0; // Referans yükseklik
  static final double _baseWidth = 1512.0; // Referans genişlik

  // Yükseklik oranı
  static double _heightRatio(BuildContext context) {
    return MediaQuery.sizeOf(context).height / _baseHeight;
  }

  // Genişlik oranı
  static double _widthRatio(BuildContext context) {
    return MediaQuery.sizeOf(context).width / _baseWidth;
  }

  // Responsive yüksekliği al
  static double rh(BuildContext context, double height) {
    return height * _heightRatio(context);
  }

  // Responsive genişliği al
  static double rw(BuildContext context, double width) {
    return width * _widthRatio(context);
  }

  static double sp(BuildContext context, double size) {
    // Genişlik ve yükseklik oranlarının ortalamasını al
    double ratio = (_heightRatio(context) + _widthRatio(context)) / 2;
    return size * ratio;
  }
}
