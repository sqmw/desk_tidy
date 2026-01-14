import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../models/shortcut_item.dart';
import '../models/app_category.dart';
import '../setting/settings_page.dart';
import '../providers/theme_notifier.dart';
import '../utils/app_preferences.dart';
import '../utils/app_search_index.dart';
import '../utils/desktop_helper.dart';
import '../utils/tray_helper.dart';
import '../widgets/glass.dart';
import '../widgets/shortcut_card.dart';
import '../widgets/category_strip.dart';
import '../widgets/selectable_shortcut_tile.dart';
import 'all_page.dart';
import 'file_page.dart';
import 'folder_page.dart';
import '../services/window_dock_logic.dart';
import '../services/window_dock_manager.dart';

ThemeModeOption _themeModeOption = ThemeModeOption.dark;
bool _showHidden = false;
bool _autoRefresh = false;
bool _autoLaunch = true;
double _iconSize = 32;

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
  bool _isRefreshing = false;
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

  static const Duration _hotAnimDuration = Duration(milliseconds: 220);
  Timer? _desktopIconSyncTimer;
  Timer? _hotCornerTimer;
  bool? _lastDesktopIconsVisible;
  int _windowHandle = 0;

  int _selectedIndex = 0;
  final TextEditingController _appSearchController = TextEditingController();
  final FocusNode _appSearchFocus = FocusNode();
  String _appSearchQuery = '';
  String? _categoryBeforeSearch;
  bool _searchHasFocus = false;
  Map<String, AppSearchIndex> _searchIndexByPath = {};

  double get _chromeOpacity =>
      (0.12 + 0.28 * _backgroundOpacity).clamp(0.12, 0.42);

  double get _contentPanelOpacity =>
      lerpDouble(0.20, 0.60, _frostStrength)!.clamp(0.0, 1.0);

  double get _contentPanelBlur =>
      lerpDouble(28, 16, _frostStrength)!.clamp(0.0, 40.0);

  // Keep this subtle because the whole content area already sits on a frosted
  // panel; too much opacity makes it look "blackened".
  double get _toolbarPanelOpacity =>
      lerpDouble(0.10, 0.22, _frostStrength)!.clamp(0.0, 1.0);

  double get _toolbarPanelBlur =>
      lerpDouble(14, 8, _frostStrength)!.clamp(0.0, 40.0);

  double get _indicatorOpacity =>
      (0.10 + 0.12 * _backgroundOpacity).clamp(0.10, 0.22);

  List<AppCategory> get _visibleCategories =>
      _categories.where((c) => c.paths.isNotEmpty).toList();

  List<ShortcutItem> get _filteredShortcuts {
    Iterable<ShortcutItem> results = _shortcuts;
    if (!_isEditingCategory && _activeCategoryId != null) {
      final category = _categories.firstWhere(
        (c) => c.id == _activeCategoryId,
        orElse: () => AppCategory.empty,
      );
      if (category.id.isNotEmpty && category.paths.isNotEmpty) {
        final allowed = category.paths;
        results = results.where((s) => allowed.contains(s.path));
      }
    }

    final normalizedQuery = normalizeSearchText(_appSearchQuery);
    if (normalizedQuery.isNotEmpty) {
      results = results.where(
        (shortcut) => _matchesSearch(shortcut, normalizedQuery),
      );
    }

    return results.toList();
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
    _appSearchFocus.addListener(() {
      if (!mounted) return;
      setState(() => _searchHasFocus = _appSearchFocus.hasFocus);
    });
  }

  void _applyDefaults() {
    _hideDesktopItems = false;
  }

  Future<void> _loadPreferences() async {
    final config = await AppPreferences.load();
    if (!mounted) return;
    setState(() {
      _backgroundOpacity = (1.0 - config.transparency).clamp(0.0, 1.0);
      _frostStrength = config.frostStrength;
      _iconSize = config.iconSize;
      _showHidden = config.showHidden;
      _autoRefresh = config.autoRefresh;
      _autoLaunch = config.autoLaunch;
      _hideDesktopItems = config.hideDesktopItems || _hideDesktopItems;
      _themeModeOption = config.themeModeOption;
      _backgroundImagePath = config.backgroundPath;
    });
    _handleThemeChange(_themeModeOption);
    await _loadCategories();
    await _loadShortcuts();
    await _syncDesktopIconVisibility();
    _setupAutoRefresh();
  }

  Future<void> _initTray() async {
    try {
      await _trayHelper.init(
        onShowRequested: () async {
          if (_trayMode) {
            await _presentFromTrayPopup();
          } else {
            _trayMode = false;
            _dockManager.onPresentFromTray();
            await windowManager.setSkipTaskbar(false);
            await windowManager.show();
            await windowManager.restore();
            await windowManager.focus();
            await _syncDesktopIconVisibility();
            if (mounted) setState(() => _panelVisible = true);
          }
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
      if (mounted) setState(() => _panelVisible = false);
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
      _dockManager.onDismissToTray();
      _windowHandle = await windowManager.getId();
      unawaited(_showTrayStartupHint());
    } catch (_) {
      // Tray init failed; keep the app discoverable via taskbar.
      _trayReady = false;
      await windowManager.setPreventClose(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.show();
      await windowManager.focus();
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

  Future<void> _loadCategories() async {
    final stored = await AppPreferences.loadCategories();
    if (!mounted) return;
    setState(() {
      _categories = stored
          .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
          .map(
            (c) => AppCategory(
              id: c.id,
              name: c.name,
              paths: {...c.shortcutPaths},
            ),
          )
          .toList();
    });
  }

  Future<void> _saveCategories() async {
    await AppPreferences.saveCategories(
      _categories
          .map(
            (c) => StoredCategory(
              id: c.id,
              name: c.name,
              shortcutPaths: c.paths.toList(),
            ),
          )
          .toList(),
    );
  }

  Future<void> _loadShortcuts({bool showLoading = true}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final shouldShowLoading = showLoading || _shortcuts.isEmpty;
    try {
      if (shouldShowLoading) {
        setState(() => _isLoading = true);
      }

      final desktopPath = await getDesktopPath();
      _desktopPath = desktopPath;
      final shortcutsPaths = await scanDesktopShortcuts(
        desktopPath,
        showHidden: _showHidden,
      );

      // 快速路径 diff：路径相同则无需解析图标和刷新 UI
      final incomingPaths = [...shortcutsPaths]..sort();
      final currentPaths = _shortcuts.map((e) => e.path).toList()..sort();
      final pathsUnchanged = _pathsEqual(currentPaths, incomingPaths);

      // 如果路径没有变化且不是强制显示加载状态（即非手动刷新），则直接返回
      if (pathsUnchanged && !showLoading) {
        if (shouldShowLoading) {
          setState(() => _isLoading = false);
        }
        return;
      }

      const requestIconSize = 256;

      final shortcutFutures = shortcutsPaths.map((shortcutPath) async {
        final name = shortcutPath.split('\\').last.replaceAll('.lnk', '');

        String targetPath = shortcutPath;
        bool isFolderShortcut = false;
        if (shortcutPath.toLowerCase().endsWith('.lnk')) {
          final target = getShortcutTarget(shortcutPath);
          if (target != null) {
            targetPath = target;
            isFolderShortcut = Directory(targetPath).existsSync();
          }
        }

        // Don't treat folder shortcuts as "apps".
        if (isFolderShortcut) {
          return null;
        }

        final primaryIcon = await extractIconAsync(
          shortcutPath,
          size: requestIconSize,
        );
        final iconData =
            primaryIcon ??
            await extractIconAsync(targetPath, size: requestIconSize);

        return ShortcutItem(
          name: name,
          path: shortcutPath,
          iconPath: '',
          description: '桌面快捷方式',
          targetPath: targetPath,
          iconData: iconData,
        );
      }).toList();

      final shortcutItems = (await Future.wait(
        shortcutFutures,
      )).whereType<ShortcutItem>().toList();

      // 只在数据变化时更新UI，实现无感更新
      if (!_shortcutsEqual(_shortcuts, shortcutItems)) {
        final searchIndex = _buildSearchIndex(shortcutItems);
        setState(() {
          _shortcuts = shortcutItems;
          _searchIndexByPath = searchIndex;
        });
        _syncCategoriesWithShortcuts(shortcutItems);
      }

      if (shouldShowLoading) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('加载快捷方式失败: $e');
      if (shouldShowLoading) {
        setState(() => _isLoading = false);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void _syncCategoriesWithShortcuts(List<ShortcutItem> shortcuts) {
    final existingPaths = shortcuts.map((e) => e.path).toSet();
    bool changed = false;
    bool clearActive = false;
    final updated = _categories.map((c) {
      final filtered = c.paths.where(existingPaths.contains).toSet();
      if (filtered.length != c.paths.length) {
        changed = true;
      }
      return c.copyWith(paths: filtered);
    }).toList();

    if (_activeCategoryId != null) {
      final active = updated.firstWhere(
        (c) => c.id == _activeCategoryId,
        orElse: () => AppCategory.empty,
      );
      if (active.id.isEmpty || active.paths.isEmpty) {
        clearActive = true;
      }
    }

    if (changed || clearActive) {
      setState(() {
        _categories = updated;
        if (clearActive) {
          _activeCategoryId = null;
        }
      });
      unawaited(_saveCategories());
    }
  }

  String _nextCategoryId() =>
      'cat_${DateTime.now().microsecondsSinceEpoch.toString()}';

  void _handleCategorySelected(String? id) {
    if (_isEditingCategory) {
      _cancelInlineCategoryEdit(save: false);
    }
    final shouldClearSearch =
        _appSearchQuery.trim().isNotEmpty && id != null;
    if (shouldClearSearch) {
      _appSearchController.clear();
    }
    setState(() {
      if (shouldClearSearch) {
        _appSearchQuery = '';
        _categoryBeforeSearch = null;
      }
      _activeCategoryId = id;
    });
  }

  void _beginInlineCategoryEdit() {
    if (_isEditingCategory) return;
    final id = _activeCategoryId;
    if (id == null) return;
    final category = _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => AppCategory.empty,
    );
    if (category.id.isEmpty) return;
    setState(() {
      _isEditingCategory = true;
      _editingCategoryId = id;
      _editingSelection = {...category.paths};
      _categoryEditBackup = {
        id: {...category.paths},
      };
    });
  }

  Future<String?> _promptRenameCategoryName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名分类'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '分类名称'),
            onSubmitted: (_) => Navigator.of(context).pop(controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameCategory(AppCategory category) async {
    if (category.id.isEmpty) return;
    if (_isEditingCategory) {
      _cancelInlineCategoryEdit(save: false);
    }

    final name = await _promptRenameCategoryName(category.name);
    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final exists = _categories.any(
      (c) =>
          c.id != category.id && c.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('分类已存在')));
      }
      return;
    }

    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx < 0) return;
    setState(() {
      _categories = [
        ..._categories.take(idx),
        _categories[idx].copyWith(name: trimmed),
        ..._categories.skip(idx + 1),
      ];
    });
    await _saveCategories();
  }

  Future<void> _deleteCategory(AppCategory category) async {
    if (category.id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除分类'),
          content: Text('确定删除“${category.name}”吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    if (_isEditingCategory && _editingCategoryId == category.id) {
      _cancelInlineCategoryEdit(save: false);
    }

    setState(() {
      _categories = _categories.where((c) => c.id != category.id).toList();
      if (_activeCategoryId == category.id) {
        _activeCategoryId = null;
      }
    });
    await _saveCategories();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已删除分类')));
  }

  void _toggleInlineSelection(ShortcutItem shortcut) {
    final id = _editingCategoryId;
    if (id == null) return;
    final idx = _categories.indexWhere((c) => c.id == id);
    if (idx < 0) return;

    final next = {..._editingSelection};
    if (next.contains(shortcut.path)) {
      next.remove(shortcut.path);
    } else {
      next.add(shortcut.path);
    }

    final updated = _categories[idx].copyWith(paths: next);
    setState(() {
      _editingSelection = next;
      _categories = [
        ..._categories.take(idx),
        updated,
        ..._categories.skip(idx + 1),
      ];
    });
  }

  Future<void> _saveInlineCategoryEdit() async {
    _cancelInlineCategoryEdit(save: true);
    await _saveCategories();
  }

  void _cancelInlineCategoryEdit({required bool save}) {
    final id = _editingCategoryId;
    final backup = _categoryEditBackup;
    AppCategory? restoredCategory;
    if (!save && id != null && backup != null && backup.containsKey(id)) {
      final idx = _categories.indexWhere((c) => c.id == id);
      if (idx >= 0) {
        restoredCategory = _categories[idx].copyWith(paths: {...backup[id]!});
      }
    }

    setState(() {
      if (restoredCategory != null) {
        final idx = _categories.indexWhere((c) => c.id == id);
        _categories = [
          ..._categories.take(idx),
          restoredCategory,
          ..._categories.skip(idx + 1),
        ];
      }
      _isEditingCategory = false;
      _editingCategoryId = null;
      _editingSelection = {};
      _categoryEditBackup = null;
    });
  }

  Future<AppCategory?> _createCategory(
    String name, {
    ShortcutItem? initialShortcut,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final exists = _categories.any(
      (c) => c.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('分类已存在')));
      }
      return null;
    }

    final newCategory = AppCategory(
      id: _nextCategoryId(),
      name: trimmed,
      paths: initialShortcut == null ? <String>{} : {initialShortcut.path},
    );

    setState(() {
      _categories = [..._categories, newCategory];
      if (initialShortcut != null && _activeCategoryId == null) {
        _activeCategoryId = newCategory.id;
      }
    });
    await _saveCategories();
    return newCategory;
  }

  Future<void> _toggleShortcutInCategory(
    AppCategory category,
    ShortcutItem shortcut,
  ) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx < 0) return;
    final updatedPaths = {...category.paths};
    final alreadyIn = updatedPaths.contains(shortcut.path);
    if (alreadyIn) {
      updatedPaths.remove(shortcut.path);
    } else {
      updatedPaths.add(shortcut.path);
    }
    final updated = category.copyWith(paths: updatedPaths);
    setState(() {
      _categories = [
        ..._categories.take(idx),
        updated,
        ..._categories.skip(idx + 1),
      ];
      if (updated.paths.isEmpty && _activeCategoryId == updated.id) {
        _activeCategoryId = null;
      }
    });
    await _saveCategories();
    if (!mounted) return;
    final text = alreadyIn ? '已从分类移除' : '已添加到分类';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$text：${category.name}')));
  }

  Future<String?> _promptCategoryName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建分类'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '分类名称'),
            onSubmitted: (_) => Navigator.of(context).pop(controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCategoryMenuForShortcut(
    ShortcutItem shortcut,
    Offset position,
  ) async {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'new',
        child: ListTile(leading: Icon(Icons.add), title: Text('新建分类')),
      ),
    ];
    if (_categories.isNotEmpty) {
      items.add(const PopupMenuDivider());
      items.addAll(
        _categories.map((c) {
          final selected = c.paths.contains(shortcut.path);
          return PopupMenuItem(
            value: c.id,
            child: ListTile(
              leading: Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
              ),
              title: Text(c.name),
            ),
          );
        }),
      );
    }

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: items,
    );

    if (result == null) return;

    if (result == 'new') {
      final name = await _promptCategoryName();
      if (name == null) return;
      final created = await _createCategory(name, initialShortcut: shortcut);
      if (!mounted || created == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加到分类：${created.name}')));
      return;
    }

    final target = _categories.firstWhere(
      (c) => c.id == result,
      orElse: () => AppCategory.empty,
    );
    if (target.id.isEmpty) return;
    await _toggleShortcutInCategory(target, shortcut);
  }

  void _reorderVisibleCategories(int oldIndex, int newIndex) {
    final visible = _visibleCategories;
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = visible.removeAt(oldIndex);
    visible.insert(newIndex, moved);

    final empties = _categories.where((c) => c.paths.isEmpty).toList();
    setState(() {
      _categories = [...visible, ...empties];
    });
    unawaited(_saveCategories());
  }

  bool _pathsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // 比较两个快捷方式列表是否相等
  bool _shortcutsEqual(List<ShortcutItem> oldList, List<ShortcutItem> newList) {
    if (oldList.length != newList.length) return false;

    // 使用Set来比较，性能更好
    final oldPathSet = oldList.map((item) => item.path).toSet();
    final newPathSet = newList.map((item) => item.path).toSet();

    return oldPathSet.length == newPathSet.length &&
        oldPathSet.containsAll(newPathSet);
  }

  Map<String, AppSearchIndex> _buildSearchIndex(
    List<ShortcutItem> shortcuts,
  ) {
    final index = <String, AppSearchIndex>{};
    for (final shortcut in shortcuts) {
      index[shortcut.path] = AppSearchIndex.fromName(shortcut.name);
    }
    return index;
  }

  bool _matchesSearch(ShortcutItem shortcut, String normalizedQuery) {
    final cached = _searchIndexByPath[shortcut.path];
    final index = cached ?? AppSearchIndex.fromName(shortcut.name);
    if (cached == null) {
      _searchIndexByPath[shortcut.path] = index;
    }
    return index.matchesPrefix(normalizedQuery);
  }

  bool _isCategoryAvailable(String id) {
    return _categories.any((c) => c.id == id && c.paths.isNotEmpty);
  }

  void _updateSearchQuery(String value) {
    final hadQuery = _appSearchQuery.trim().isNotEmpty;
    final hasQuery = value.trim().isNotEmpty;

    setState(() {
      _appSearchQuery = value;

      if (!_isEditingCategory) {
        if (!hadQuery && hasQuery) {
          _categoryBeforeSearch ??= _activeCategoryId;
          _activeCategoryId = null;
        } else if (hadQuery && !hasQuery) {
          final restore = _categoryBeforeSearch;
          _categoryBeforeSearch = null;
          if (restore != null && _isCategoryAvailable(restore)) {
            _activeCategoryId = restore;
          }
        }
      } else {
        _categoryBeforeSearch = null;
      }
    });
  }

  void _clearSearch({bool keepFocus = false, bool restoreCategory = true}) {
    final hasQuery =
        _appSearchQuery.trim().isNotEmpty ||
        _appSearchController.text.trim().isNotEmpty;
    if (!hasQuery) {
      if (keepFocus) _appSearchFocus.requestFocus();
      return;
    }

    final restore =
        restoreCategory && !_isEditingCategory ? _categoryBeforeSearch : null;
    setState(() {
      _appSearchQuery = '';
      _categoryBeforeSearch = null;
      if (restore != null && _isCategoryAvailable(restore)) {
        _activeCategoryId = restore;
      }
    });
    _appSearchController.clear();
    if (keepFocus) _appSearchFocus.requestFocus();
  }

  void _toggleMaximize() {
    if (_isMaximized) {
      windowManager.restore();
    } else {
      windowManager.maximize();
    }
    setState(() => _isMaximized = !_isMaximized);
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

  void _onNavigationRailItemSelected(int index) {
    if (_isEditingCategory) {
      _cancelInlineCategoryEdit(save: false);
    }
    setState(() => _selectedIndex = index);
    if (index == 0) {
      _loadShortcuts(showLoading: false);
    }
  }

  void _onNavigationRailPointer(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons == kSecondaryMouseButton &&
        _selectedIndex != 1) {
      _showHiddenMenu(event.position);
    }
  }

  Future<void> _showHiddenMenu(Offset globalPosition) async {
    const menuItemValue = 0;
    final label = _showHidden ? '隐藏隐藏文件/文件夹' : '显示隐藏文件/文件夹';
    final icon = _showHidden ? Icons.visibility_off : Icons.visibility;

    final result = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: menuItemValue,
          child: ListTile(
            leading: Icon(icon),
            title: Text(label),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );

    if (result == menuItemValue) {
      setState(() => _showHidden = !_showHidden);
      _loadShortcuts();
    }
  }

  // 设置自动刷新
  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (_autoRefresh) {
      // 每5秒刷新一次桌面
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!mounted) return;
        await _loadShortcuts(showLoading: false);
      });
    }
  }

  @override
  void dispose() {
    _hotCornerTimer?.cancel();
    _desktopIconSyncTimer?.cancel();
    _saveWindowTimer?.cancel();
    _dragEndTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _dockManager.dispose();
    windowManager.removeListener(this);
    _windowFocusNotifier.dispose();
    _appSearchController.dispose();
    _appSearchFocus.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_trayReady) {
      await windowManager.hide();
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

  @override
  void onWindowBlur() {
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
    if (mounted) setState(() => _panelVisible = false);

    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.show();
    await windowManager.restore();
    await windowManager.setPosition(Offset.zero, animate: false);
    _dockManager.onPresentFromHotCorner();
    await windowManager.focus();
    await _syncDesktopIconVisibility();
    // Drop always-on-top after we are visible.
    unawaited(
      Future.delayed(const Duration(milliseconds: 800), () {
        windowManager.setAlwaysOnTop(false);
      }),
    );

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _panelVisible = true);
    });
  }

  // 从托盘唤起窗口
  Future<void> _presentFromTrayPopup() async {
    _windowHandle = findMainFlutterWindowHandle() ?? _windowHandle;
    _trayMode = false;
    if (mounted) setState(() => _panelVisible = false);

    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.show();
    await windowManager.restore();
    _dockManager.onPresentFromTray();
    await windowManager.focus();
    await _syncDesktopIconVisibility();
    unawaited(
      Future.delayed(const Duration(milliseconds: 800), () {
        windowManager.setAlwaysOnTop(false);
      }),
    );

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _panelVisible = true);
    });
  }

  Future<void> _dismissToTray({required bool fromHotCorner}) async {
    _dockManager.onDismissToTray();
    _trayMode = true;
    if (mounted) setState(() => _panelVisible = false);
    await windowManager.setSkipTaskbar(true);
    await Future<void>.delayed(_hotAnimDuration);
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
    setState(() {
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
      setState(() => _hideDesktopItems = !visible);
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
        await AppPreferences.saveWindowBounds(
          x: pos.dx.round(),
          y: pos.dy.round(),
          width: size.width.round(),
          height: size.height.round(),
        );
      } catch (_) {}
    });
  }

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
                              blurSigma: 20,
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
                                    icon: Tooltip(
                                      message: '应用',
                                      child: Icon(Icons.apps),
                                    ),
                                    label: const Text('应用'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Tooltip(
                                      message: '全部',
                                      child: Icon(Icons.all_inbox),
                                    ),
                                    label: const Text('全部'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Tooltip(
                                      message: '文件夹',
                                      child: Icon(Icons.folder),
                                    ),
                                    label: const Text('文件夹'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Tooltip(
                                      message: '文件',
                                      child: Icon(Icons.insert_drive_file),
                                    ),
                                    label: const Text('文件'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Tooltip(
                                      message: '设置',
                                      child: Icon(Icons.settings),
                                    ),
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

  Widget _buildTitleBar() {
    final theme = Theme.of(context);
    final scale = _uiScale(context);
    final titleBarHeight = 34.0 * scale;
    final titleButtonSize = 32.0 * scale;
    return MouseRegion(
      onEnter: (_) {},
      child: GestureDetector(
        onPanStart: (_) => windowManager.startDragging(),
        child: GlassContainer(
          opacity: _chromeOpacity,
          blurSigma: 20,
          borderRadius: BorderRadius.zero,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.16),
              width: 0.8,
            ),
          ),
          child: SizedBox(
            height: titleBarHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10 * scale),
              child: Row(
                children: [
                  const Spacer(),
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: titleButtonSize,
                          height: titleButtonSize,
                        ),
                        icon: const Icon(Icons.remove),
                        onPressed: _minimizeWindow,
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: titleButtonSize,
                          height: titleButtonSize,
                        ),
                        icon: Icon(
                          _isMaximized ? Icons.filter_none : Icons.crop_square,
                        ),
                        onPressed: _toggleMaximize,
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: titleButtonSize,
                          height: titleButtonSize,
                        ),
                        icon: const Icon(Icons.close),
                        onPressed: _closeWindow,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final effectiveShowHidden = _showHidden;
    switch (_selectedIndex) {
      case 0:
        return _buildApplicationContent();
      case 1:
        return AllPage(
          desktopPath: _desktopPath,
          showHidden: effectiveShowHidden,
        );
      case 2:
        return FolderPage(
          desktopPath: _desktopPath,
          showHidden: effectiveShowHidden,
        );
      case 3:
        return FilePage(
          desktopPath: _desktopPath,
          showHidden: effectiveShowHidden,
        );
      case 4:
        return SettingsPage(
          transparency: (1.0 - _backgroundOpacity).clamp(0.0, 1.0),
          frostStrength: _frostStrength,
          iconSize: _iconSize,
          showHidden: _showHidden,
          autoRefresh: _autoRefresh,
          autoLaunch: _autoLaunch,
          hideDesktopItems: _hideDesktopItems,
          themeModeOption: _themeModeOption,
          backgroundPath: _backgroundImagePath,
          onTransparencyChanged: (v) {
            setState(() => _backgroundOpacity = (1.0 - v).clamp(0.0, 1.0));
            AppPreferences.saveTransparency(v);
          },
          onFrostStrengthChanged: (v) {
            setState(() => _frostStrength = v);
            AppPreferences.saveFrostStrength(v);
          },
          onIconSizeChanged: (v) {
            setState(() => _iconSize = v);
            AppPreferences.saveIconSize(v);
          },
          onShowHiddenChanged: (v) {
            setState(() => _showHidden = v);
            AppPreferences.saveShowHidden(v);
            _loadShortcuts();
          },
          onAutoRefreshChanged: (v) {
            setState(() => _autoRefresh = v);
            AppPreferences.saveAutoRefresh(v);
            _setupAutoRefresh();
          },
          onAutoLaunchChanged: (v) async {
            final previous = _autoLaunch;
            setState(() => _autoLaunch = v);
            final ok = await setAutoLaunchEnabled(v);
            if (!mounted) return;
            if (!ok) {
              setState(() => _autoLaunch = previous);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('开机启动设置失败')));
              return;
            }
            await AppPreferences.saveAutoLaunch(v);
          },
          onHideDesktopItemsChanged: _handleHideDesktopItemsChanged,
          onThemeModeChanged: (v) {
            _handleThemeChange(v);
            if (v != null) {
              AppPreferences.saveThemeMode(v);
            }
          },
          onBackgroundPathChanged: (path) async {
            final previous = _backgroundImagePath;
            final saved = await AppPreferences.backupAndSaveBackgroundPath(
              path,
            );
            if (!mounted) return;
            if (saved != null && saved.isNotEmpty) {
              unawaited(FileImage(File(saved)).evict());
            } else if (previous != null && previous.isNotEmpty) {
              unawaited(FileImage(File(previous)).evict());
            }
            setState(() => _backgroundImagePath = saved);
          },
        );
      default:
        return _buildApplicationContent();
    }
  }

  Future<void> _handleHideDesktopItemsChanged(bool hide) async {
    setState(() => _hideDesktopItems = hide);
    AppPreferences.saveHideDesktopItems(hide);
    final ok = await setDesktopIconsVisible(!hide);
    if (!mounted) return;
    if (!ok) {
      setState(() => _hideDesktopItems = !hide);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('切换失败，请重试')));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(hide ? '已隐藏系统桌面图标' : '已显示系统桌面图标')));
    await _syncDesktopIconVisibility();
  }

  void _handleThemeChange(ThemeModeOption? option) {
    if (option == null) return;
    setState(() => _themeModeOption = option);

    switch (option) {
      case ThemeModeOption.light:
        appThemeNotifier.value = ThemeMode.light;
        break;
      case ThemeModeOption.dark:
        appThemeNotifier.value = ThemeMode.dark;
        break;
      case ThemeModeOption.system:
        appThemeNotifier.value = ThemeMode.system;
        break;
    }
  }

  Widget _buildSearchBar(double scale) {
    final theme = Theme.of(context);
    final hasQuery = _appSearchQuery.trim().isNotEmpty;
    final iconSize = (18 * scale).clamp(16.0, 22.0);
    final borderColor = _searchHasFocus
        ? theme.colorScheme.primary.withValues(alpha: 0.45)
        : theme.dividerColor.withValues(alpha: 0.16);
    final iconColor = _searchHasFocus
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.72);
    final opacity = (_toolbarPanelOpacity + (_searchHasFocus ? 0.06 : 0.0))
        .clamp(0.0, 1.0);

    return GlassContainer(
      borderRadius: BorderRadius.circular(14),
      opacity: opacity,
      blurSigma: _toolbarPanelBlur,
      border: Border.all(color: borderColor, width: 1),
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: iconSize, color: iconColor),
          SizedBox(width: 6 * scale),
          Expanded(
            child: TextField(
              controller: _appSearchController,
              focusNode: _appSearchFocus,
              onChanged: _updateSearchQuery,
              autocorrect: false,
              enableSuggestions: false,
              maxLines: 1,
              textInputAction: TextInputAction.search,
              cursorColor: theme.colorScheme.primary,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索应用（支持拼音前缀）',
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (hasQuery)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: 28 * scale,
                height: 28 * scale,
              ),
              iconSize: iconSize,
              tooltip: '清除',
              onPressed: () => _clearSearch(keepFocus: true),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchCountChip(
    double scale, {
    required int matchCount,
    required int totalCount,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        '匹配 $matchCount/$totalCount',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildApplicationContent() {
    final scale = _uiScale(context);
    final shortcuts = _filteredShortcuts;
    final searchActive = normalizeSearchText(_appSearchQuery).isNotEmpty;
    final isFiltering = _activeCategoryId != null;
    final editingCategory = _isEditingCategory;
    final editingName = _categories
        .firstWhere(
          (c) => c.id == _editingCategoryId,
          orElse: () => AppCategory.empty,
        )
        .name;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            10 * scale,
            10 * scale,
            10 * scale,
            6 * scale,
          ),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(16),
            // Use a lighter tint here; the whole content already sits on a
            // frosted panel, so a dark tint makes this strip look "blackened".
            color: Colors.white,
            opacity: _toolbarPanelOpacity,
            blurSigma: _toolbarPanelBlur,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.16),
            ),
            padding: EdgeInsets.fromLTRB(
              10 * scale,
              6 * scale,
              10 * scale,
              10 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryStrip(
                  categories: _categories,
                  activeCategoryId: _activeCategoryId,
                  totalCount: _shortcuts.length,
                  scale: scale,
                  onAllSelected: () => _handleCategorySelected(null),
                  onCategorySelected: (id) => _handleCategorySelected(id),
                  onReorder: _reorderVisibleCategories,
                  onRenameRequested: _renameCategory,
                  onDeleteRequested: _deleteCategory,
                  onEditRequested: (_) => _beginInlineCategoryEdit(),
                ),
                SizedBox(height: 8 * scale),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final showCount =
                        searchActive && constraints.maxWidth > 420 * scale;
                    return Row(
                      children: [
                        Expanded(child: _buildSearchBar(scale)),
                        if (showCount) ...[
                          SizedBox(width: 8 * scale),
                          _buildSearchCountChip(
                            scale,
                            matchCount: shortcuts.length,
                            totalCount: _shortcuts.length,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (editingCategory)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 4 * scale,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420 * scale;

                Future<void> handleDelete() async {
                  final id = _editingCategoryId;
                  if (id == null) return;
                  final category = _categories.firstWhere(
                    (c) => c.id == id,
                    orElse: () => AppCategory.empty,
                  );
                  if (category.id.isEmpty) return;
                  await _deleteCategory(category);
                }

                Widget actions;
                if (compact) {
                  final iconSize = (constraints.maxWidth * 0.045).clamp(
                    20 * scale,
                    24 * scale,
                  );
                  final btnWidth = (constraints.maxWidth * 0.085).clamp(
                    40 * scale,
                    56 * scale,
                  );
                  final btnHeight = (constraints.maxWidth * 0.070).clamp(
                    34 * scale,
                    40 * scale,
                  );
                  final btnConstraints = BoxConstraints.tightFor(
                    width: btnWidth,
                    height: btnHeight,
                  );
                  actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: '删除',
                        child: IconButton(
                          onPressed: handleDelete,
                          constraints: btnConstraints,
                          padding: EdgeInsets.zero,
                          iconSize: iconSize,
                          visualDensity: VisualDensity.compact,
                          color: Theme.of(context).colorScheme.error,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                      Tooltip(
                        message: '取消',
                        child: IconButton(
                          onPressed: () =>
                              _cancelInlineCategoryEdit(save: false),
                          constraints: btnConstraints,
                          padding: EdgeInsets.zero,
                          iconSize: iconSize,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      Tooltip(
                        message: '保存',
                        child: IconButton(
                          onPressed: _saveInlineCategoryEdit,
                          constraints: btnConstraints,
                          padding: EdgeInsets.zero,
                          iconSize: iconSize,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.check),
                        ),
                      ),
                    ],
                  );
                } else {
                  actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: handleDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => _cancelInlineCategoryEdit(save: false),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: _saveInlineCategoryEdit,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('保存'),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '编辑：$editingName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    actions,
                  ],
                );
              },
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : shortcuts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        searchActive
                            ? '没有匹配的应用'
                            : isFiltering
                                ? '该分类暂无应用'
                                : '未找到桌面快捷方式',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      if (!isFiltering && !searchActive) ...[
                        const SizedBox(height: 8),
                        Text(
                          '桌面路径: $_desktopPath',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisSpacing = 12.0 * scale;
                    final mainAxisSpacing = 12.0 * scale;
                    final estimatedTextHeight = _estimateTextHeight();
                    final padding = math.max(8.0, _iconSize * 0.28);
                    final iconContainerSize = math.max(28.0, _iconSize * 1.65);
                    final tileMaxExtent = math.max(
                      120.0,
                      iconContainerSize + padding * 2,
                    );
                    final cardHeight =
                        padding * 0.6 * 2 +
                        iconContainerSize +
                        padding * 0.6 +
                        estimatedTextHeight;
                    final aspectRatio = cardHeight <= 0
                        ? 1
                        : tileMaxExtent / cardHeight;

                    final grid = GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        14 * scale,
                        0,
                        14 * scale,
                        14 * scale,
                      ),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: tileMaxExtent,
                        crossAxisSpacing: crossAxisSpacing,
                        mainAxisSpacing: mainAxisSpacing,
                        childAspectRatio: aspectRatio.toDouble(),
                      ),
                      itemCount: shortcuts.length,
                      itemBuilder: (context, index) {
                        final shortcut = shortcuts[index];
                        if (editingCategory) {
                          return SelectableShortcutTile(
                            shortcut: shortcut,
                            iconSize: _iconSize,
                            scale: scale,
                            selected: _editingSelection.contains(shortcut.path),
                            onTap: () => _toggleInlineSelection(shortcut),
                          );
                        }
                        return ShortcutCard(
                          shortcut: shortcut,
                          iconSize: _iconSize,
                          windowFocusNotifier: _windowFocusNotifier,
                          onDeleted: () {
                            _loadShortcuts(showLoading: false);
                          },
                          onCategoryMenuRequested: _showCategoryMenuForShortcut,
                        );
                      },
                    );

                    return grid;
                  },
                ),
        ),
      ],
    );
  }

  double _estimateTextHeight() {
    final size = (_iconSize * 0.34).clamp(10, 18);
    // allow up to 2 lines with some spacing
    return size * 2.9 + 6;
  }
}
