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
    // Polling uses GetAsyncKeyState and keeps the CPU awake; only run it when
    // the window is hidden in tray mode.
    if (_trayMode) {
      service.startPolling(
        interval: kDebugMode
            ? const Duration(milliseconds: 280)
            : const Duration(milliseconds: 220),
      );
      return;
    }
    service.stopPolling();
  }

  /// 从热键唤起窗口并聚焦搜索框
  Future<void> _presentFromHotkey() async {
    _windowHandle = findMainFlutterWindowHandle() ?? _windowHandle;
    _trayMode = false;
    _lastActivationMode = _ActivationMode.hotkey;
    _startHotCornerWatcher();
    // 设置600ms的“忽略失去焦点”宽限期，防止唤醒时的焦点抢夺导致误触自动隐藏
    _ignoreBlurUntil = DateTime.now().add(const Duration(milliseconds: 600));

    // 先准备内容，避免白屏闪烁
    if (mounted) _setState(() => _panelVisible = true);

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

    // [Anti-Flash] 先设置透明度为0，防止白屏闪烁
    await windowManager.setOpacity(0.0);

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

    // 等待一帧渲染
    await Future.delayed(const Duration(milliseconds: 50));
    await windowManager.setOpacity(1.0);

    _dockManager.onPresentFromHotkey();
    _updateHotkeyPolling();

    // 使用强制前台窗口方法获取真正的键盘焦点
    forceSetForegroundWindow(_windowHandle);
    await windowManager.focus(); // 也调用 Flutter 的 focus 作为补充
    await _syncDesktopIconVisibility();
    _startDesktopIconSync();

    unawaited(
      Future.delayed(const Duration(milliseconds: 800), () {
        windowManager.setAlwaysOnTop(false);
      }),
    );

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 切换到应用页面并聚焦搜索框
      if (_selectedIndex != 0) {
        _setState(() => _selectedIndex = 0);
      }
      _onMainWindowPresented();
      // 延迟一小段时间确保原生焦点已完全切换
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _appSearchFocus.requestFocus();
      });
    });
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
            _startHotCornerWatcher();
            _dockManager.onPresentFromTray();
            await windowManager.setSkipTaskbar(false);
            await windowManager.show();
            await windowManager.restore();
            await windowManager.focus();
            await _syncDesktopIconVisibility();
            if (mounted) _setState(() => _panelVisible = true);
            _startDesktopIconSync();
            _onMainWindowPresented();
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
      _updateHotkeyPolling();
      _startDesktopIconSync();
      _startHotCornerWatcher();
      unawaited(_showTrayStartupHint());
    } catch (_) {
      // Tray init failed; keep the app discoverable via taskbar.
      _trayReady = false;
      await windowManager.setPreventClose(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.show();
      await windowManager.focus();
      _onMainWindowPresented();
      _updateHotkeyPolling();
      _startDesktopIconSync();
      _startHotCornerWatcher();
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
