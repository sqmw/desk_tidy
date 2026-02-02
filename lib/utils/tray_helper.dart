import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';

import 'package:url_launcher/url_launcher.dart';

class TrayHelper {
  final SystemTray _tray = SystemTray();
  bool _initialized = false;
  static const String _trayIconAsset = 'windows/runner/resources/app_icon.ico';

  Future<void> init({
    required VoidCallback onShowRequested,
    required VoidCallback onHideRequested,
    required VoidCallback onQuitRequested,
  }) async {
    if (_initialized) return;

    try {
      final iconPath = _resolveTrayIconPath();
      final ok = await _tray.initSystemTray(
        title: 'Desk Tidy',
        iconPath: iconPath,
        toolTip: 'Desk Tidy',
      );
      if (!ok) {
        throw StateError('System tray initialization failed.');
      }

      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(label: '显示主窗口', onClicked: (_) => onShowRequested()),
        MenuItemLabel(label: '隐藏到托盘', onClicked: (_) => onHideRequested()),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Star 支持我们🌟',
          onClicked: (_) => launchUrl(
            Uri.parse('https://github.com/sqmw/desk_tidy'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        MenuSeparator(),
        MenuItemLabel(label: '退出(隐藏到托盘)', onClicked: (_) => onHideRequested()),
        MenuItemLabel(label: '彻底退出', onClicked: (_) => onQuitRequested()),
      ]);

      await _tray.setContextMenu(menu);

      _tray.registerSystemTrayEventHandler((eventName) async {
        if (eventName == kSystemTrayEventClick) {
          onShowRequested();
          return;
        }
        if (eventName == kSystemTrayEventRightClick) {
          // Explicitly pop up the context menu on Windows.
          await _tray.popUpContextMenu();
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

  String _resolveTrayIconPath() => _trayIconAsset;
}
