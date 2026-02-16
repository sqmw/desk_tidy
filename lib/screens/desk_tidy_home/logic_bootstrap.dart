part of '../desk_tidy_home_page.dart';

extension _DeskTidyHomeBootstrap on _DeskTidyHomePageState {
  void _initHotkey() {
    final service = HotkeyService.instance;
    // 注册 Ctrl + Shift + Space
    service.register(
      HotkeyConfig.showWindow,
      callback: (_) => _presentFromHotkey(),
    );
    // 同时注册备选 Alt + Shift + Space
    service.register(
      HotkeyConfig.showWindowAlt,
      callback: (_) => _presentFromHotkey(),
    );
    _updateHotkeyPolling();
  }

  void _updateHotkeyPolling() {
    final service = HotkeyService.instance;
    // Keep polling while the panel is visible so a second hotkey press can
    // re-top and force a redraw when the window appears "stuck".
    final shouldPoll =
        _trayMode || !_windowFocusNotifier.value || _panelVisible;
    if (shouldPoll) {
      service.startPolling(
        interval: _panelVisible && _windowFocusNotifier.value
            ? const Duration(milliseconds: 120)
            : const Duration(milliseconds: 80),
      );
      return;
    }
    service.stopPolling();
  }

  void _pokeUi() {
    if (!mounted) return;
    _setState(() {});
    SchedulerBinding.instance.scheduleFrame();
  }

  Future<void> _awaitUiFrame({
    Duration timeout = const Duration(milliseconds: 120),
  }) async {
    final binding = WidgetsBinding.instance;
    final frameFuture = binding.endOfFrame;
    binding.scheduleFrame();
    try {
      await frameFuture.timeout(timeout);
    } catch (_) {}
  }

  Future<void> _prepareUiForShow({bool forceAppTab = false}) async {
    _visibilityToken++;
    if (mounted) {
      _setState(() {
        _panelVisible = true;
        if (forceAppTab) _selectedIndex = 0;
      });
    }
    await _awaitUiFrame();
  }

  Future<void> _nudgeWindowSizeForRedraw({required int token}) async {
    if (!mounted) return;
    if (_trayMode || !_panelVisible) return;
    if (_visibilityToken != token) return;
    try {
      final currentSize = await windowManager.getSize();
      await windowManager.setSize(
        Size(currentSize.width + 1, currentSize.height),
      );
      await windowManager.setSize(currentSize);
    } catch (_) {}
    _pokeUi();
  }

  Future<void> _forceRefreshWindowSurfaceForHotkey() async {
    final token = _visibilityToken;
    await _nudgeWindowSizeForRedraw(token: token);
    _scheduleRedrawNudges();
  }

  void _scheduleRedrawNudges() {
    final token = _visibilityToken;
    unawaited(_nudgeWindowSizeForRedraw(token: token));
    unawaited(
      Future.delayed(
        const Duration(milliseconds: 160),
        () => _nudgeWindowSizeForRedraw(token: token),
      ),
    );
    unawaited(
      Future.delayed(
        const Duration(milliseconds: 420),
        () => _nudgeWindowSizeForRedraw(token: token),
      ),
    );
  }

  Future<void> _ensureWindowOpaque() async {
    try {
      await windowManager.setOpacity(1.0);
    } catch (_) {}
    unawaited(
      Future.delayed(const Duration(milliseconds: 120), () async {
        try {
          await windowManager.setOpacity(1.0);
        } catch (_) {}
      }),
    );
  }

  void _ensurePanelVisible() {
    if (!mounted) return;
    if (_trayMode) return;
    if (!_panelVisible) {
      _setState(() => _panelVisible = true);
    }
  }

  void _focusSearchForHotkeyActivation() {
    if (!mounted) return;
    _onMainWindowPresented();
    _focusSearchField(selectAllIfHasText: true);
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;
        _focusSearchField(selectAllIfHasText: true);
      }),
    );
  }

  Future<void> _bringWindowToFrontFromHotkey() async {
    _windowHandle = findMainFlutterWindowHandle() ?? _windowHandle;
    _trayMode = false;
    _lastActivationMode = _ActivationMode.hotkey;
    _ignoreBlurUntil = DateTime.now().add(const Duration(milliseconds: 600));
    await _prepareUiForShow(forceAppTab: true);

    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.restore();
    await windowManager.show();
    await _forceRefreshWindowSurfaceForHotkey();

    _dockManager.onPresentFromHotkey();
    _updateHotkeyPolling();
    await _ensureWindowOpaque();
    _ensurePanelVisible();
    _pokeUi();

    forceSetForegroundWindow(_windowHandle);
    await windowManager.focus();

    _focusSearchForHotkeyActivation();

    unawaited(
      Future.delayed(const Duration(milliseconds: 800), () {
        windowManager.setAlwaysOnTop(false);
      }),
    );
  }

  /// 从热键唤起窗口并聚焦搜索框
  Future<void> _presentFromHotkey() async {
    if (_hotkeyPresentInFlight) {
      _hotkeyRefocusRequested = true;
      return;
    }
    _hotkeyPresentInFlight = true;

    try {
      // If the window is already visible, a second hotkey press is typically
      // intended to bring it to the top (not to redo layout/opacity work).
      if (!_trayMode && _panelVisible) {
        await _bringWindowToFrontFromHotkey();
        return;
      }

      _windowHandle = findMainFlutterWindowHandle() ?? _windowHandle;
      _trayMode = false;
      _lastActivationMode = _ActivationMode.hotkey;
      // _startHotCornerWatcher removed (handled by service)
      // 设置600ms的“忽略失去焦点”宽限期，防止唤醒时的焦点抢夺导致误触自动隐藏
      _ignoreBlurUntil = DateTime.now().add(const Duration(milliseconds: 600));

      // 先准备内容，避免白屏闪烁
      await _prepareUiForShow(forceAppTab: true);

      // 加载快捷键专属窗口布局并应用
      final layout = await AppPreferences.loadHotkeyWindowLayout();
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

      await _forceRefreshWindowSurfaceForHotkey();

      await _ensureWindowOpaque();
      _ensurePanelVisible();

      _dockManager.onPresentFromHotkey();
      _updateHotkeyPolling();

      // 使用强制前台窗口方法获取真正的键盘焦点
      forceSetForegroundWindow(_windowHandle);
      await windowManager.focus(); // 也调用 Flutter 的 focus 作为补充
      await _syncDesktopIconVisibility();
      // _startDesktopIconSync removed (handled by service)
      _pokeUi();

      unawaited(
        Future.delayed(const Duration(milliseconds: 800), () {
          windowManager.setAlwaysOnTop(false);
        }),
      );

      _focusSearchForHotkeyActivation();
    } finally {
      unawaited(_ensureWindowOpaque());
      _ensurePanelVisible();
      _pokeUi();
      _hotkeyPresentInFlight = false;
      if (_hotkeyRefocusRequested) {
        _hotkeyRefocusRequested = false;
        unawaited(_bringWindowToFrontFromHotkey());
      }
    }
  }

  void _applyDefaults() {
    _hideDesktopItems = false;
  }

  Future<void> _loadPreferences() async {
    final config = await AppPreferences.load();
    if (!mounted) return;
    _setState(() {
      _backgroundOpacity = (1.0 - config.transparency).clamp(0.0, 1.0);
      _frostStrength = config.frostStrength;
      _iconSize = config.iconSize;
      _showHidden = config.showHidden;
      _autoRefresh = config.autoRefresh;
      _autoLaunch = config.autoLaunch;
      _hideDesktopItems = config.hideDesktopItems || _hideDesktopItems;
      _themeModeOption = config.themeModeOption;
      _backgroundImagePath = config.backgroundPath;
      _beautifyAppIcons = config.beautifyAppIcons;
      _beautifyDesktopIcons = config.beautifyDesktopIcons;
      _beautifyStyle = config.beautifyStyle;
      _enableDesktopBoxes = config.enableDesktopBoxes;
      _iconIsolatesEnabled = config.iconIsolatesEnabled;
      _showRecycleBin = config.showRecycleBin;
      _showThisPC = config.showThisPC;
      _showControlPanel = config.showControlPanel;
      _showNetwork = config.showNetwork;
      _showUserFiles = config.showUserFiles;
    });
    appFrostStrengthNotifier.value = _frostStrength;
    setIconIsolatesEnabled(_iconIsolatesEnabled);
    final actualIconIsolates = iconIsolatesEnabled;
    if (actualIconIsolates != _iconIsolatesEnabled && mounted) {
      _setState(() => _iconIsolatesEnabled = actualIconIsolates);
    }
    _handleThemeChange(_themeModeOption);

    final desktopPath = await getDesktopPath();
    if (!mounted) return;
    _setState(() => _desktopPath = desktopPath);

    await _loadCategories();

    // Launch boxes if enabled
    await BoxLauncher.instance.updateBoxes(
      enabled: _enableDesktopBoxes,
      desktopPath: _desktopPath,
    );
  }

  Future<void> _initTray() async {
    try {
      await _trayHelper.init(
        onShowRequested: () async {
          if (_trayMode) {
            await _presentFromTrayPopup();
          } else {
            _trayMode = false;
            _lastActivationMode = _ActivationMode.tray;
            // _startHotCornerWatcher removed
            _dockManager.onPresentFromTray();
            await windowManager.setSkipTaskbar(false);
            await windowManager.show();
            await windowManager.restore();
            _scheduleRedrawNudges();
            await windowManager.focus();
            await _syncDesktopIconVisibility();
            if (mounted) _setState(() => _panelVisible = true);
            // _startDesktopIconSync removed
            _onMainWindowPresented();
            unawaited(_ensureWindowOpaque());
            _pokeUi();
          }
          _updateHotkeyPolling();
        },
        onHideRequested: () async {
          await _dismissToTray(fromHotCorner: false);
        },
        onQuitRequested: () async {
          await windowManager.setPreventClose(false);
          await windowManager.close();
        },
      );
      _trayReady = true;
      await windowManager.setPreventClose(true);
      _trayMode = true;
      if (mounted) _setState(() => _panelVisible = false);
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
      _dockManager.onDismissToTray();
      _windowHandle = await windowManager.getId();
      _windowHandle = await windowManager.getId();
      _updateHotkeyPolling();
      // Service syncs removed
      unawaited(_showTrayStartupHint());
    } catch (_) {
      // Tray init failed; keep the app discoverable via taskbar.
      _trayReady = false;
      await windowManager.setPreventClose(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.show();
      await windowManager.focus();
      _onMainWindowPresented();
      _onMainWindowPresented();
      _updateHotkeyPolling();
      // Service syncs removed
    }
  }

  Future<void> _showTrayStartupHint() async {
    try {
      final handle = await windowManager.getId();
      _windowHandle = handle;
      showTrayBalloon(
        windowHandle: handle,
        title: 'Desk Tidy',
        message: 'Desk Tidy 已隐藏在系统托盘',
      );
    } catch (_) {
      // Ignore tray hint failures.
    }
  }
}
