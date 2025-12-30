import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class TrayHelper {
  final SystemTray _tray = SystemTray();
  bool _initialized = false;

  Future<void> init({
    required VoidCallback onShowRequested,
    required VoidCallback onHideRequested,
    required VoidCallback onQuitRequested,
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
          label: '显示主窗口',
          onClicked: (_) => onShowRequested(),
        ),
        MenuItemLabel(
          label: '隐藏到托盘',
          onClicked: (_) => onHideRequested(),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: '退出(隐藏到托盘)',
          onClicked: (_) => onHideRequested(),
        ),
        MenuItemLabel(
          label: '彻底退出',
          onClicked: (_) => onQuitRequested(),
        ),
      ]);

      await _tray.setContextMenu(menu);

      _tray.registerSystemTrayEventHandler((eventName) async {
        if (eventName == kSystemTrayEventClick) {
          onShowRequested();
          return;
        }
        if (eventName == kSystemTrayEventRightClick) {
          // Keep default behavior: show menu.
          return;
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
