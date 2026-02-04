import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/app_preferences.dart';
import '../utils/desktop_helper.dart';

class DesktopVisibilityService {
  DesktopVisibilityService._();
  static final DesktopVisibilityService instance = DesktopVisibilityService._();

  Timer? _timer;
  bool? _lastVisible;

  // Expose state via ValueNotifier if needed, or just callback
  final ValueNotifier<bool> isVisible = ValueNotifier(true);

  /// Starts syncing desktop icon visibility.
  ///
  /// [onVisibilityChanged]: Callback when visibility changes.
  /// [shouldSync]: Optional callback to check if we should sync (e.g. only when hidden).
  void start({
    Function(bool isVisible)? onVisibilityChanged,
    bool Function()? shouldSync,
  }) {
    _timer?.cancel();

    if (shouldSync != null && !shouldSync()) {
      _timer = null;
      return;
    }

    final interval = kDebugMode
        ? const Duration(seconds: 10)
        : const Duration(seconds: 8);

    _timer = Timer.periodic(interval, (_) async {
      if (shouldSync != null && !shouldSync()) return;

      final visible = await isDesktopIconsVisible();

      if (_lastVisible != visible) {
        _lastVisible = visible;
        isVisible.value = visible;
        onVisibilityChanged?.call(visible);

        // Auto-save preference as side effect, preserving original logic
        AppPreferences.saveHideDesktopItems(!visible);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // One-off check
  Future<bool> checkVisibility() async {
    final visible = await isDesktopIconsVisible();
    _lastVisible = visible;
    isVisible.value = visible;
    return visible;
  }
}
