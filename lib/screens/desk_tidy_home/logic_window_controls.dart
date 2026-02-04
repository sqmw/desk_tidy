part of '../desk_tidy_home_page.dart';

extension _DeskTidyHomeWindowControls on _DeskTidyHomePageState {
  void _toggleMaximize() {
    if (_isMaximized) {
      windowManager.restore();
    } else {
      windowManager.maximize();
    }
    _setState(() => _isMaximized = !_isMaximized);
  }

  void _minimizeWindow() {
    _dismissToTray(fromHotCorner: false);
  }

  void _closeWindow() {
    if (_trayReady) {
      _dismissToTray(fromHotCorner: false);
    } else {
      windowManager.close();
    }
  }
}
