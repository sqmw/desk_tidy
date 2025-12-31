import 'dart:ui';

class WindowDockLogic {
  const WindowDockLogic._();

  static double clampSize(double value, double min, double max) =>
      value.clamp(min, max).toDouble();

  static Rect snapZone(Size screenSize) {
    final left = clampSize(screenSize.width / 6, 32, 800);
    final top = clampSize(screenSize.height / 3, 32, 600);
    return Rect.fromLTWH(0, 0, left, top);
  }

  static Rect hotCornerZone(Size screenSize) {
    final left = clampSize(screenSize.width / 7, 32, 800);
    final top = clampSize(screenSize.height / 3, 32, 600);
    return Rect.fromLTWH(0, 0, left, top);
  }

  static bool shouldSnapToTopLeft(Offset windowTopLeft, Rect snapZone) {
    if (windowTopLeft.dx < 0 || windowTopLeft.dy < 0) return true;
    return snapZone.contains(windowTopLeft);
  }
}

