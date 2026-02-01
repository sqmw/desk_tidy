part of '../desk_tidy_home_page.dart';

extension _DeskTidyHomeRuntime on _DeskTidyHomePageState {
  void _startHotCornerWatcher() {
    _hotCornerTimer?.cancel();
    _hotCornerTimer = Timer.periodic(const Duration(milliseconds: 520), (
      _,
    ) async {
      if (!mounted) return;
      if (!_trayMode && !_dockManager.isDocked) return;

      final cursorPos = getCursorScreenPosition();
      if (cursorPos == null) return;
      final screen = getPrimaryScreenSize();
      final hotZone = WindowDockLogic.hotCornerZone(
        Size(screen.x.toDouble(), screen.y.toDouble()),
      );
      final inHotCorner = hotZone.contains(
        Offset(cursorPos.x.toDouble(), cursorPos.y.toDouble()),
      );
      final ctrlDown = isCtrlPressed();

      if (_trayMode && inHotCorner && ctrlDown) {
        await _presentFromHotCorner();
      }
    });
  }

  // 从热区唤起窗口（Ctrl + 鼠标到达触发区域）
  Future<void> _presentFromHotCorner() async {
    _windowHandle = findMainFlutterWindowHandle() ?? _windowHandle;
    _trayMode = false;
    _lastActivationMode = _ActivationMode.hotCorner;

    // 先准备内容，避免白屏闪烁
    if (mounted) _setState(() => _panelVisible = true);

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

    // [Fix] Force a tiny resize to trigger WM_SIZE and sync child HWND in Release mode
    final currentSize = await windowManager.getSize();
    await windowManager.setSize(
      Size(currentSize.width + 1, currentSize.height),
    );
    await windowManager.setSize(currentSize);

    _dockManager.onPresentFromHotCorner();
    await windowManager.focus();
    await _syncDesktopIconVisibility();
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
    _lastActivationMode = _ActivationMode.tray;

    // 先准备内容，避免白屏闪烁
    if (mounted) _setState(() => _panelVisible = true);

    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.restore(); // 先恢复窗口状态
    await windowManager.show(); // 再显示窗口
    _dockManager.onPresentFromTray();
    await windowManager.focus();
    await _syncDesktopIconVisibility();
    unawaited(
      Future.delayed(const Duration(milliseconds: 800), () {
        windowManager.setAlwaysOnTop(false);
      }),
    );
  }

  Future<void> _dismissToTray({required bool fromHotCorner}) async {
    _dockManager.onDismissToTray();
    _trayMode = true;
    if (mounted) _setState(() => _panelVisible = false);
    await windowManager.setSkipTaskbar(true);
    await Future<void>.delayed(_DeskTidyHomePageState._hotAnimDuration);
    await windowManager.hide();
  }

  Future<bool> _isCursorInsideWindow() async {
    // 这里的判定通过获取当前鼠标位置，以及窗口位置即可判定
    try {
      if (_windowHandle == 0) {
        _windowHandle = findMainFlutterWindowHandle() ?? 0;
      }
      if (_windowHandle != 0 && isCursorOverWindowHandle(_windowHandle)) {
        return true;
      }
      final cursor = getCursorScreenPosition();
      if (cursor == null) return false;
      final rect = getWindowRectForHandle(_windowHandle);
      if (rect != null) {
        return rect.containsPoint(math.Point(cursor.x, cursor.y));
      }
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      final x = cursor.x.toDouble();
      final y = cursor.y.toDouble();
      return x >= pos.dx &&
          y >= pos.dy &&
          x <= (pos.dx + size.width) &&
          y <= (pos.dy + size.height);
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncDesktopIconVisibility() async {
    final visible = await isDesktopIconsVisible();
    if (!mounted) return;
    _lastDesktopIconsVisible = visible;
    _setState(() {
      _hideDesktopItems = !visible;
    });
  }

  void _startDesktopIconSync() {
    _desktopIconSyncTimer?.cancel();
    _desktopIconSyncTimer = Timer.periodic(const Duration(milliseconds: 900), (
      _,
    ) async {
      if (!mounted) return;
      final visible = await isDesktopIconsVisible();
      if (!mounted) return;
      if (_lastDesktopIconsVisible == visible) return;
      _lastDesktopIconsVisible = visible;
      _setState(() => _hideDesktopItems = !visible);
      AppPreferences.saveHideDesktopItems(!visible);
    });
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
