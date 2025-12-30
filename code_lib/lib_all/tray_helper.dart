import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class TrayHelper {
  final SystemTray _tray = SystemTray();
  bool _initialized = false;

  Future<void> init({
    required VoidCallback onExitRequested,
  }) async {
    if (_initialized) return;

    try {
      final iconPath = _resolveTrayIconPath();
      await _tray.initSystemTray(
        title: 'Desk Tidy',
        iconPath: iconPath,
      );

      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: '显示/隐藏',
          onClicked: (_) async {
            final visible = await windowManager.isVisible();
            if (visible) {
              await windowManager.hide();
            } else {
              await windowManager.show();
              await windowManager.focus();
            }
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: '退出',
          onClicked: (_) => onExitRequested(),
        ),
      ]);

      await _tray.setContextMenu(menu);

      _tray.registerSystemTrayEventHandler((eventName) async {
        if (eventName == kSystemTrayEventClick ||
            eventName == kSystemTrayEventRightClick) {
          await windowManager.show();
          await windowManager.focus();
        }
      });

      _initialized = true;
    } catch (_) {
      // If tray init fails (missing icon file, plugin issues), do not crash.
      _initialized = false;
      rethrow;
    }
  }

  String _resolveTrayIconPath() {
    // Dev fallback: use the Windows runner icon if available.
    final cwd = Directory.current.path;
    final candidate = File(
      '$cwd\\windows\\runner\\resources\\app_icon.ico',
    );
    if (candidate.existsSync()) return candidate.path;

    // If not found, system_tray still needs a path; fall back to executable path
    // (Windows uses the process icon in many cases).
    return Platform.resolvedExecutable;
  }
}
