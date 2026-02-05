part of '../desk_tidy_home_page.dart';

extension _DeskTidyHomeRuntime on _DeskTidyHomePageState {
  // 从热区唤起窗口（Ctrl + 鼠标到达触发区域）
  Future<void> _presentFromHotCorner() async {
    _windowHandle = findMainFlutterWindowHandle() ?? _windowHandle;
    _trayMode = false;
    _updateHotkeyPolling();
    _lastActivationMode = _ActivationMode.hotCorner;

    // 先准备内容，避免白屏闪烁
    await _prepareUiForShow();

    // 加载热区专属窗口布局并应用
    final layout = await AppPreferences.loadHotCornerWindowLayout();
    final screen = getPrimaryScreenSize();
    final bounds = layout.toBounds(screen.x, screen.y);
    await windowManager.setSize(
      Size(bounds.width.toDouble(), bounds.height.toDouble()),
    );
    await windowManager.setPosition(
      Offset(bounds.x.toDouble(), bounds.y.toDouble()),
    );

    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.restore(); // 先恢复窗口状态
    await windowManager.show(); // 再显示窗口
    _scheduleRedrawNudges();

    _dockManager.onPresentFromHotCorner();
    await windowManager.focus();
    await _syncDesktopIconVisibility();
    _onMainWindowPresented();
    _pokeUi();
    // Drop always-on-top after we are visible.
    unawaited(
      Future.delayed(const Duration(milliseconds: 800), () {
        windowManager.setAlwaysOnTop(false);
      }),
    );
  }

  // 从托盘唤起窗口
  Future<void> _presentFromTrayPopup() async {
    _windowHandle = findMainFlutterWindowHandle() ?? _windowHandle;
    _trayMode = false;
    _updateHotkeyPolling();
    _lastActivationMode = _ActivationMode.tray;

    // 先准备内容，避免白屏闪烁
    await _prepareUiForShow();

    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.restore(); // 先恢复窗口状态
    await windowManager.show(); // 再显示窗口
    _scheduleRedrawNudges();
    _dockManager.onPresentFromTray();
    await windowManager.focus();
    await _syncDesktopIconVisibility();
    _onMainWindowPresented();
    _pokeUi();
    unawaited(
      Future.delayed(const Duration(milliseconds: 800), () {
        windowManager.setAlwaysOnTop(false);
      }),
    );
  }

  Future<void> _dismissToTray({required bool fromHotCorner}) async {
    _dockManager.onDismissToTray();
    _trayMode = true;
    _updateHotkeyPolling();
    final hideToken = ++_visibilityToken;
    if (mounted) _setState(() => _panelVisible = false);
    _setupAutoRefresh();
    await windowManager.setSkipTaskbar(true);
    await Future<void>.delayed(_DeskTidyHomePageState._hotAnimDuration);
    if (!mounted) return;
    if (_visibilityToken != hideToken || !_trayMode) {
      if (mounted && !_panelVisible) {
        _setState(() => _panelVisible = true);
        _pokeUi();
      }
      return;
    }
    await windowManager.hide();
  }

  Future<void> _syncDesktopIconVisibility() async {
    await DesktopVisibilityService.instance.checkVisibility();
  }

  void _scheduleSaveWindowBounds() {
    _saveWindowTimer?.cancel();
    _saveWindowTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final isMax = await windowManager.isMaximized();
        final isMin = await windowManager.isMinimized();
        if (isMax || isMin) return;

        final pos = await windowManager.getPosition();
        final size = await windowManager.getSize();

        // 快捷键模式：保存到专属配置（使用屏幕比例）
        if (_lastActivationMode == _ActivationMode.hotkey) {
          final screen = getPrimaryScreenSize();
          await AppPreferences.saveHotkeyWindowLayout(
            xRatio: pos.dx / screen.x,
            yRatio: pos.dy / screen.y,
            wRatio: size.width / screen.x,
            hRatio: size.height / screen.y,
          );
        } else if (_lastActivationMode == _ActivationMode.hotCorner) {
          // 热区模式：保存到热区专属配置（使用屏幕比例）
          final screen = getPrimaryScreenSize();
          await AppPreferences.saveHotCornerWindowLayout(
            xRatio: pos.dx / screen.x,
            yRatio: pos.dy / screen.y,
            wRatio: size.width / screen.x,
            hRatio: size.height / screen.y,
          );
        } else {
          // 其他模式（托盘等）：保存到通用配置
          await AppPreferences.saveWindowBounds(
            x: pos.dx.round(),
            y: pos.dy.round(),
            width: size.width.round(),
            height: size.height.round(),
          );
        }
      } catch (_) {}
    });
  }
}
