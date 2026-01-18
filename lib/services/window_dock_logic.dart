import 'dart:ui';

class WindowDockLogic {
  const WindowDockLogic._();

  static const double _hotCornerTopPx = 10;

  static double clampSize(double value, double min, double max) =>
      value.clamp(min, max).toDouble();

  /// 窗口吸附区域（左上角）
  /// 当窗口左上角在此区域内松开鼠标时，会自动吸附到左上角
  static Rect snapZone(Size screenSize) {
    // 缩小吸附区域，避免误触发
    final left = clampSize(screenSize.width / 12, 32, 200);
    final top = clampSize(screenSize.height / 8, 32, 150);
    return Rect.fromLTWH(0, 0, left, top);
  }

  static Rect hotCornerZone(Size screenSize) {
    // Small zone near the top edge to avoid interfering with moving the mouse
    // to the left side of full-screen apps. Horizontal reach is 1/4 screen.
    final left = clampSize(screenSize.width / 4, 48, 900);
    final top = clampSize(_hotCornerTopPx, 6, 24);
    return Rect.fromLTWH(0, 0, left, top);
  }

  static bool shouldSnapToTopLeft(Offset windowTopLeft, Rect snapZone) {
    if (windowTopLeft.dx < 0 || windowTopLeft.dy < 0) return true;
    return snapZone.contains(windowTopLeft);
  }
}
