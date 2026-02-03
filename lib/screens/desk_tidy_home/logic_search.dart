part of '../desk_tidy_home_page.dart';

extension _DeskTidyHomeSearchLogic on _DeskTidyHomePageState {
  Map<String, AppSearchIndex> _buildSearchIndex(List<ShortcutItem> shortcuts) {
    final index = <String, AppSearchIndex>{};
    for (final shortcut in shortcuts) {
      index[shortcut.path] = AppSearchIndex.fromName(shortcut.name);
    }
    return index;
  }

  /// 获取快捷方式的搜索索引（带缓存）
  AppSearchIndex _getSearchIndex(ShortcutItem shortcut) {
    final cached = _searchIndexByPath[shortcut.path];
    if (cached != null) return cached;

    final index = AppSearchIndex.fromName(shortcut.name);
    _searchIndexByPath[shortcut.path] = index;
    return index;
  }

  /// 处理搜索框的键盘导航
  KeyEventResult _handleSearchNavigation(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // 首先处理应该直接传给 TextField 的按键
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    // Shift+左右键：移动光标（不选择文本）
    if (isShift &&
        (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight)) {
      final text = _appSearchController.text;
      final selection = _appSearchController.selection;
      if (text.isEmpty) return KeyEventResult.handled;

      int newOffset;
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        newOffset = (selection.baseOffset - 1).clamp(0, text.length);
      } else {
        newOffset = (selection.baseOffset + 1).clamp(0, text.length);
      }

      _appSearchController.selection = TextSelection.collapsed(
        offset: newOffset,
      );
      return KeyEventResult.handled;
    }

    final shortcuts = _filteredShortcuts;
    if (shortcuts.isEmpty) {
      // 即使没有结果，ESC 也应该能关闭窗口
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _dismissToTray(fromHotCorner: false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // 全局 ESC 处理 (无论是否有选中项)
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _dismissToTray(fromHotCorner: false);
      return KeyEventResult.handled;
    }

    // 如果还没有选中项，且按下了方向键/Tab，则初始化选中
    if (_searchSelectedIndex == -1) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        _setState(() => _searchSelectedIndex = 0);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored; // 其他键交给输入框移动光标
    }

    // 已有选中项，进行网格/列表导航
    int nextIndex = _searchSelectedIndex;
    final int total = shortcuts.length;
    final int cols = _gridCrossAxisCount;
    // 向上取整计算行数
    final int rows = (total + cols - 1) ~/ cols;

    // 当前坐标
    final int currentCol = _searchSelectedIndex % cols;
    final int currentRow = _searchSelectedIndex ~/ cols;

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      // Tab 线性循环
      if (isShift) {
        nextIndex = (nextIndex - 1 + total) % total;
      } else {
        nextIndex = (nextIndex + 1) % total;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // 右键线性循环
      nextIndex = (nextIndex + 1) % total;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // 左键线性循环
      nextIndex = (nextIndex - 1 + total) % total;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      // 下键：列内循环
      // 逻辑：尝试去下一行的同一列。如果该位置为空（最后一行没填满），则回到第一行。
      int targetRow = currentRow + 1;
      if (targetRow >= rows) {
        targetRow = 0; // Wrap to top
      }

      int targetIndex = targetRow * cols + currentCol;

      // 如果目标索引超出了总数（发生在最后一行），说明这一列在最后一行没有元素
      // 此时应该跳到第一行（Wrap to top）
      if (targetIndex >= total) {
        targetIndex = currentCol; // First row, current col
      }
      nextIndex = targetIndex;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      // 上键：列内循环
      int targetRow = currentRow - 1;
      if (targetRow < 0) {
        // Wrap to bottom
        targetRow = rows - 1;
      }

      int targetIndex = targetRow * cols + currentCol;

      // 如果目标索引超出总数（发生在最后一行空缺），说明这一列在最后一行没有元素
      // 此时应该去倒数第二行（即 targetRow - 1）
      // 特殊情况：如果总共只有1行，targetRow=0, targetIndex ok.
      if (targetIndex >= total) {
        targetRow = math.max(0, targetRow - 1);
        targetIndex = targetRow * cols + currentCol;
      }
      nextIndex = targetIndex;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _openSelectedSearchResult();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      // ESC 键：隐藏窗口
      _dismissToTray(fromHotCorner: false);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }

    if (nextIndex != _searchSelectedIndex) {
      _setState(() => _searchSelectedIndex = nextIndex);
      _ensureSearchSelectionVisible(nextIndex);
    }
    return KeyEventResult.handled;
  }

  // ...

  // 提取 LayoutMetrics 类或方法来统一计算
  _LayoutMetrics _calculateLayoutMetrics(double scale) {
    final padding = math.max(8.0, _iconSize * 0.28);
    final iconContainerSize = math.max(28.0, _iconSize * 1.65);
    final estimatedTextHeight = _estimateTextHeight();
    final cardHeight =
        padding * 0.6 * 2 +
        iconContainerSize +
        padding * 0.6 +
        estimatedTextHeight;
    final mainAxisSpacing = 12.0 * scale;
    return _LayoutMetrics(
      cardHeight: cardHeight,
      mainAxisSpacing: mainAxisSpacing,
      horizontalPadding: 28.0 * scale,
    );
  }

  /// 确保选中的搜索结果可见（自动滚动）
  void _ensureSearchSelectionVisible(int index) {
    if (!_gridScrollController.hasClients) return;

    // 获取当前的 scale (假设从 MediaQuery 或 stored state 获取，这里简化为一个getter)
    // 注意：_buildApplicationContent 中有个 local scale，
    // 我们需要确保 _ensureSearchSelectionVisible 能访问到或者近似计算。
    // 由于 scale 并不经常变，我们可以存储一个成员变量 _currentScale
    final scale = _currentScale;

    final metrics = _calculateLayoutMetrics(scale);

    // 计算目标行的偏移量
    final int row = index ~/ _gridCrossAxisCount;
    final double itemExtent = metrics.cardHeight + metrics.mainAxisSpacing;
    final double targetOffset = row * itemExtent;

    // 获取当前滚动位置
    final double currentScroll = _gridScrollController.offset;
    final double viewportHeight =
        _gridScrollController.position.viewportDimension;

    // 如果目标在视口上方，滚上去
    if (targetOffset < currentScroll) {
      _gridScrollController.animateTo(
        targetOffset - metrics.mainAxisSpacing, // 留一点余量
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    // 如果目标在视口下方，滚下去（注意这里要减去视口高度）
    else if (targetOffset + metrics.cardHeight >
        currentScroll + viewportHeight) {
      _gridScrollController.animateTo(
        targetOffset +
            metrics.cardHeight -
            viewportHeight +
            metrics.mainAxisSpacing,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  /// 打开当前选中的搜索结果
  void _openSelectedSearchResult() {
    final shortcuts = _filteredShortcuts;
    if (shortcuts.isEmpty) return;

    // 如果没有选中项，默认打开第一个
    final index = _searchSelectedIndex < 0 ? 0 : _searchSelectedIndex;
    if (index >= shortcuts.length) return;

    final shortcut = shortcuts[index];
    final resolvedPath = shortcut.targetPath.isNotEmpty
        ? shortcut.targetPath
        : shortcut.path;

    openWithDefault(resolvedPath);

    // 如果是快捷键模式，打开后隐藏窗口
    if (_lastActivationMode == _ActivationMode.hotkey) {
      _dismissToTray(fromHotCorner: false);
    }
  }

  bool _isCategoryAvailable(String id) {
    return _categories.any((c) => c.id == id && c.paths.isNotEmpty);
  }

  void _updateSearchQuery(String value) {
    final hadQuery = _appSearchQuery.trim().isNotEmpty;
    final hasQuery = value.trim().isNotEmpty;

    _setState(() {
      _appSearchQuery = value;
      // 搜索内容变化时先重置，后面会在帧回调中根据结果数量决定是否选中第一个
      _searchSelectedIndex = -1;

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

    // [Feature] 自动选中第一个搜索结果（如果有结果的话）
    if (hasQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final results = _filteredShortcuts;
        if (results.isNotEmpty && _searchSelectedIndex == -1) {
          _setState(() => _searchSelectedIndex = 0);
        }
      });
    }
  }

  void _clearSearch({bool keepFocus = false, bool restoreCategory = true}) {
    final hasQuery =
        _appSearchQuery.trim().isNotEmpty ||
        _appSearchController.text.trim().isNotEmpty;
    if (!hasQuery) {
      if (keepFocus) _appSearchFocus.requestFocus();
      return;
    }

    final restore = restoreCategory && !_isEditingCategory
        ? _categoryBeforeSearch
        : null;
    _setState(() {
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

  void _onNavigationRailItemSelected(int index) {
    if (_isEditingCategory) {
      _cancelInlineCategoryEdit(save: false);
    }
    _setState(() => _selectedIndex = index);
    if (index == 0) {
      _loadShortcuts(showLoading: false);
    } else {
      _cancelShortcutLoad();
    }
    _setupAutoRefresh();
  }

  void _cancelShortcutLoad() {
    _shortcutLoadToken++;
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
      _setState(() => _showHidden = !_showHidden);
      _loadShortcuts();
    }
  }

  // 设置自动刷新
  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    if (!_autoRefresh) return;
    if (_trayMode || !_panelVisible) return;
    if (_selectedIndex != 0) return;

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_autoRefreshTick());
    });
  }

  void _onMainWindowPresented() {
    _setupAutoRefresh();
    unawaited(_autoRefreshTick(ignoreAutoRefreshEnabled: true));
  }

  Future<void> _autoRefreshTick({bool ignoreAutoRefreshEnabled = false}) async {
    if (!mounted) return;
    if (_trayMode || !_panelVisible) return;
    if (_selectedIndex != 0) return;
    if (!ignoreAutoRefreshEnabled && !_autoRefresh) return;
    if (_autoRefreshProbeInFlight) return;

    if (!_hasLoadedShortcutsOnce) {
      await _loadShortcuts(showLoading: true);
      return;
    }

    _autoRefreshProbeInFlight = true;
    try {
      final desktopPath = _desktopPath.isNotEmpty
          ? _desktopPath
          : await getDesktopPath();
      if (!mounted) return;
      if (desktopPath.isEmpty) return;

      final desktopScanPaths = desktopLocations(desktopPath);
      final foundDesktop = await compute(
        _scanPathsInIsolate,
        _ScanRequest(
          desktopPaths: desktopScanPaths,
          startMenuPaths: const [],
          showHidden: _showHidden,
        ),
      );
      if (!mounted) return;
      if (_trayMode || !_panelVisible) return;
      if (_selectedIndex != 0) return;
      if (!ignoreAutoRefreshEnabled && !_autoRefresh) return;

      final snapshot = foundDesktop.map((e) => e.toLowerCase()).toList()
        ..sort();
      if (_pathsEqual(_autoRefreshDesktopPathsSnapshot, snapshot)) return;

      _autoRefreshDesktopPathsSnapshot = snapshot;
      await _loadShortcuts(
        showLoading: false,
        desktopShortcutPathsOverride: foundDesktop,
      );
    } catch (_) {
      // Ignore auto refresh probe failures.
    } finally {
      _autoRefreshProbeInFlight = false;
    }
  }
}
