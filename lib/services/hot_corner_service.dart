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
  bool _armed = false;

  /// Starts watching for hot corner activation.
  ///
  /// [onTrigger]: Callback to execute when hot corner is activated.
  /// [shouldWatch]: Optional callback to check if we should even check (e.g. is docked or in tray).
  void start({required VoidCallback onTrigger, bool Function()? shouldWatch}) {
    _timer?.cancel();

    // Hot-corner needs to feel instant; long intervals make it look like
    // "need to shake twice". Keep this lightweight (cursor pos + ctrl state).
    final interval = kDebugMode
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 80);

    _isPolling = true;
    _timer = Timer.periodic(interval, (_) async {
      if (!_isPolling) return;

      // Check condition again
      if (shouldWatch != null && !shouldWatch()) {
        _armed = false;
        return;
      }

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

      final active = inHotCorner && ctrlDown;
      if (!active) {
        _armed = false;
        return;
      }

      // Edge-trigger to avoid repeated activation while holding Ctrl in the zone.
      if (_armed) return;
      _armed = true;

      if (active) {
        onTrigger();
      }
    });
  }

  void stop() {
    _isPolling = false;
    _armed = false;
    _timer?.cancel();
    _timer = null;
  }
}
