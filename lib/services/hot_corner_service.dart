import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../services/window_dock_logic.dart';
import '../utils/desktop_helper.dart';

class HotCornerService {
  HotCornerService._();
  static final HotCornerService instance = HotCornerService._();

  Timer? _timer;
  bool _isPolling = false;

  /// Starts watching for hot corner activation.
  ///
  /// [onTrigger]: Callback to execute when hot corner is activated.
  /// [shouldWatch]: Optional callback to check if we should even check (e.g. is docked or in tray).
  void start({required VoidCallback onTrigger, bool Function()? shouldWatch}) {
    _timer?.cancel();

    // Initial check
    if (shouldWatch != null && !shouldWatch()) return;

    final interval = kDebugMode
        ? const Duration(milliseconds: 1500)
        : const Duration(milliseconds: 1200);

    _isPolling = true;
    _timer = Timer.periodic(interval, (_) async {
      if (!_isPolling) return;

      // Check condition again
      if (shouldWatch != null && !shouldWatch()) return;

      final cursorPos = getCursorScreenPosition();
      if (cursorPos == null) return;

      final screen = getPrimaryScreenSize();
      final hotZone = WindowDockLogic.hotCornerZone(
        Size(screen.x.toDouble(), screen.y.toDouble()),
      );

      final inHotCorner = hotZone.contains(
        Offset(cursorPos.x.toDouble(), cursorPos.y.toDouble()),
      );

      // Must hold CTRL
      final ctrlDown = isCtrlPressed();

      if (inHotCorner && ctrlDown) {
        onTrigger();
      }
    });
  }

  void stop() {
    _isPolling = false;
    _timer?.cancel();
    _timer = null;
  }
}
