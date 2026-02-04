part of '../desk_tidy_home_page.dart';

class DeskTidyHomePage extends StatefulWidget {
  const DeskTidyHomePage({super.key});

  @override
  State<DeskTidyHomePage> createState() => _DeskTidyHomePageState();
}

class _DeskTidyHomePageState extends State<DeskTidyHomePage>
    with WindowListener {
  final TrayHelper _trayHelper = TrayHelper();
  late final WindowDockManager _dockManager;

  bool _trayReady = false;
  Timer? _saveWindowTimer;
  Timer? _dragEndTimer;
  Timer? _autoRefreshTimer;
  bool _hasLoadedShortcutsOnce = false;
  bool _autoRefreshProbeInFlight = false;
  List<String> _autoRefreshDesktopPathsSnapshot = const [];
  int _shortcutLoadToken = 0;
  List<ShortcutItem> _shortcuts = [];
  List<AppCategory> _categories = [];
  String? _activeCategoryId;
  bool _isEditingCategory = false;
  String? _editingCategoryId;
  Set<String> _editingSelection = {};
  Map<String, Set<String>>? _categoryEditBackup;
  String _desktopPath = '';
  bool _isLoading = true;
  bool _isMaximized = false;
  final ValueNotifier<bool> _windowFocusNotifier = ValueNotifier(true);

  // Controls how much of the desktop shows through (via the background layer).
  // 1.0 = fully opaque, 0.0 = fully transparent.
  double _backgroundOpacity = 0.8;
  double _frostStrength = 0.82;
  String? _backgroundImagePath;
  bool _hideDesktopItems = false;
  bool _panelVisible = true;
  bool _trayMode = false;
  bool _beautifyAppIcons = false;
  bool _beautifyDesktopIcons = false;
  IconBeautifyStyle _beautifyStyle = IconBeautifyStyle.cute;
  bool _enableDesktopBoxes = false;
  bool _iconIsolatesEnabled = true;
  bool _showRecycleBin = true;
  bool _showThisPC = true;
  bool _showControlPanel = false;
  bool _showNetwork = false;
  bool _showUserFiles = false;

  static const Duration _hotAnimDuration = Duration(milliseconds: 220);
  Timer? _desktopIconSyncTimer;
  Timer? _hotCornerTimer;
  bool? _lastDesktopIconsVisible;
  int _windowHandle = 0;
  _ActivationMode? _lastActivationMode;

  int _selectedIndex = 0;
  final TextEditingController _appSearchController = TextEditingController();
  final FocusNode _appSearchFocus = FocusNode();
  String _appSearchQuery = '';
  String? _categoryBeforeSearch;
  bool _searchHasFocus = false;
  Map<String, AppSearchIndex> _searchIndexByPath = {};
  int _searchSelectedIndex = -1; // 搜索结果选中索引，-1 表示未选中
  int _gridCrossAxisCount = 1; // 网格布局列数，用于键盘导航
  final ScrollController _gridScrollController = ScrollController(); // 网格滚动控制器
  double _currentScale = 1.0;

  void _setState(VoidCallback fn) => setState(fn);

  double get _chromeOpacity =>
      (0.12 + 0.28 * _backgroundOpacity).clamp(0.12, 0.42);

  double get _chromeBlur => 24;

  double get _contentPanelOpacity =>
      lerpDouble(0.20, 0.60, _frostStrength)!.clamp(0.0, 1.0);

  double get _contentPanelBlur => 22;

  // Keep this subtle because the whole content area already sits on a frosted
  // panel; too much opacity makes it look "blackened".
  double get _toolbarPanelOpacity =>
      lerpDouble(0.10, 0.22, _frostStrength)!.clamp(0.0, 1.0);

  double get _toolbarPanelBlur => 11;

  double get _indicatorOpacity =>
      (0.10 + 0.12 * _backgroundOpacity).clamp(0.10, 0.22);

  List<AppCategory> get _visibleCategories =>
      _categories.where((c) => c.paths.isNotEmpty).toList();

  List<ShortcutItem> get _filteredShortcuts {
    List<ShortcutItem> results = _shortcuts.toList();

    // 分类过滤
    if (!_isEditingCategory && _activeCategoryId != null) {
      final category = _categories.firstWhere(
        (c) => c.id == _activeCategoryId,
        orElse: () => AppCategory.empty,
      );
      if (category.id.isNotEmpty && category.paths.isNotEmpty) {
        final allowed = category.paths;
        results = results.where((s) => allowed.contains(s.path)).toList();
      }
    }

    // 搜索过滤（使用模糊匹配器，按分数排序）
    final normalizedQuery = normalizeSearchText(_appSearchQuery);
    if (normalizedQuery.isNotEmpty) {
      results = FuzzyMatcher.filter<ShortcutItem>(
        _appSearchQuery,
        results,
        (shortcut) => _getSearchIndex(shortcut),
      );
    }

    return results;
  }

  double _uiScale(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    // Desktop windows vary a lot; keep controls compact by default.
    return (height / 980).clamp(0.72, 1.0);
  }

  @override
  void initState() {
    super.initState();

    _windowHandle = findMainFlutterWindowHandle() ?? 0;
    _dockManager = WindowDockManager(
      windowManager: windowManager,
      getWindowHandle: () => _windowHandle,
      isCursorInsideWindow: _isCursorInsideWindow,
      dismissToTray: _dismissToTray,
    );

    _applyDefaults();
    _loadPreferences();
    _dockManager.start();
    _startDesktopIconSync();
    _startHotCornerWatcher();

    // Start in tray; keep the window out of taskbar until user opens it.
    windowManager.setSkipTaskbar(true);

    windowManager.isMaximized().then((value) {
      if (mounted) {
        setState(() => _isMaximized = value);
      }
    });

    windowManager.addListener(this);
    _initTray();
    _initHotkey();
    _appSearchFocus.addListener(() {
      if (!mounted) return;
      setState(() => _searchHasFocus = _appSearchFocus.hasFocus);
    });
  }

  /// 初始化全局热键

  @override
  void dispose() {
    _hotCornerTimer?.cancel();
    _desktopIconSyncTimer?.cancel();
    _saveWindowTimer?.cancel();
    _dragEndTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _dockManager.dispose();
    HotkeyService.instance.dispose();
    windowManager.removeListener(this);
    _windowFocusNotifier.dispose();
    _appSearchController.dispose();
    _appSearchFocus.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_trayReady) {
      await _dismissToTray(fromHotCorner: false);
      return;
    }
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  void onWindowMoved() {
    _scheduleSaveWindowBounds();
    if (_dockManager.shouldSuppressMoveTracking()) return;
    _dockManager.markWindowMoving();

    // 检测拖动结束：如果窗口停止移动一段时间，认为鼠标已松开
    _dragEndTimer?.cancel();
    _dragEndTimer = Timer(const Duration(milliseconds: 150), () {
      unawaited(_dockManager.onMouseUp());
    });
  }

  DateTime _ignoreBlurUntil = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void onWindowBlur() {
    if (DateTime.now().isBefore(_ignoreBlurUntil)) {
      // 刚唤醒时忽略失去焦点事件（防止焦点抢夺导致的误触自动隐藏）
      // 保持视觉上的焦点状态，虽然实际上可能失去了系统焦点
      return;
    }

    // 如果当前在设置页面（Index 2），不自动隐藏
    // 允许用户在设置页面进行各种操作（如选择文件、复制文本）而不受自动隐藏干扰
    if (_selectedIndex == 2) return;

    _windowFocusNotifier.value = false;
    // 窗口失去焦点时，可能是点击了外部，检查是否需要隐藏
    unawaited(_dockManager.onMouseClickOutside());
  }

  @override
  void onWindowFocus() {
    _windowFocusNotifier.value = true;
  }

  @override
  void onWindowResized() {
    _scheduleSaveWindowBounds();
  }

  // 热区监视器（用于从托盘唤起窗口）

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = _uiScale(context);
    final railMinWidth = 48.0 * scale;
    final railPadH = 2.0 * scale;
    final railPadV = 4.0 * scale;
    final backgroundPath = _backgroundImagePath;
    final backgroundExists =
        backgroundPath != null &&
        backgroundPath.isNotEmpty &&
        File(backgroundPath).existsSync();

    final content = Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedSlide(
        duration: _hotAnimDuration,
        curve: Curves.easeOutCubic,
        offset: _panelVisible ? Offset.zero : const Offset(0, -0.03),
        child: AnimatedOpacity(
          duration: _hotAnimDuration,
          curve: Curves.easeOutCubic,
          opacity: _panelVisible ? 1.0 : 0.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: _backgroundOpacity,
                  child: backgroundExists
                      ? Image.file(File(backgroundPath), fit: BoxFit.cover)
                      : Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                ),
              ),
              Column(
                children: [
                  _buildTitleBar(),
                  Expanded(
                    child: Row(
                      children: [
                        Listener(
                          onPointerDown: _onNavigationRailPointer,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: railPadH,
                              vertical: railPadV,
                            ),
                            child: GlassContainer(
                              borderRadius: BorderRadius.circular(18),
                              opacity: _chromeOpacity,
                              blurSigma: _chromeBlur,
                              border: Border.all(
                                color: theme.dividerColor.withValues(
                                  alpha: 0.16,
                                ),
                              ),
                              child: NavigationRail(
                                backgroundColor: Colors.transparent,
                                minWidth: railMinWidth,
                                useIndicator: true,
                                indicatorColor: theme.colorScheme.primary
                                    .withValues(alpha: _indicatorOpacity),
                                selectedIconTheme: IconThemeData(
                                  color: theme.colorScheme.primary,
                                ),
                                unselectedIconTheme: IconThemeData(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                                selectedLabelTextStyle: theme
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                unselectedLabelTextStyle: theme
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.72),
                                    ),
                                selectedIndex: _selectedIndex,
                                onDestinationSelected:
                                    _onNavigationRailItemSelected,
                                labelType: NavigationRailLabelType.none,
                                destinations: [
                                  NavigationRailDestination(
                                    icon: Icon(Icons.apps),
                                    label: const Text('应用'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.all_inbox),
                                    label: const Text('全部'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.settings),
                                    label: const Text('设置'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        VerticalDivider(
                          thickness: 1,
                          width: 1,
                          color: theme.dividerColor.withValues(alpha: 0.12),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              10 * scale,
                              6 * scale,
                              10 * scale,
                              10 * scale,
                            ),
                            child: GlassContainer(
                              borderRadius: BorderRadius.circular(18),
                              opacity: _contentPanelOpacity,
                              blurSigma: _contentPanelBlur,
                              border: Border.all(
                                color: theme.dividerColor.withValues(
                                  alpha: 0.16,
                                ),
                              ),
                              child: _buildContent(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) {
        // 点击窗口内部：如果是从托盘触发，设置为false；否则取消待执行的隐藏
        unawaited(_dockManager.onMouseClickInside());
      },
      child: MouseRegion(
        onEnter: (_) => _dockManager.onMouseEnter(),
        onExit: (_) {
          // 鼠标离开窗口区域：如果是从tray触发进入过app后离开，立即开始260ms倒计时隐藏
          unawaited(_dockManager.onMouseExit());
        },
        child: content,
      ),
    );
  }
}
