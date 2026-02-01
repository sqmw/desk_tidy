part of '../../desk_tidy_home_page.dart';

extension _DeskTidyHomeShortcutLoading on _DeskTidyHomePageState {
  Future<void> _loadShortcuts({
    bool showLoading = true,
    bool forceReloadIcons = false,
  }) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final shouldShowLoading = showLoading || _shortcuts.isEmpty;
    try {
      if (shouldShowLoading) {
        _setState(() => _isLoading = true);
      }

      final desktopPath = await getDesktopPath();
      _desktopPath = desktopPath;

      // Collect all root paths to scan (User Desktop + Public Desktop)
      final desktopScanPaths = desktopLocations(desktopPath);

      // Start Menu Integration
      final startMenuScanPaths = <String>[];
      try {
        final startMenuPaths = await getStartMenuLocations();
        startMenuScanPaths.addAll(startMenuPaths);
      } catch (e) {
        print('Error getting start menu locations: $e');
      }

      final shortcutsPaths = <String>[];

      // System Tools paths
      try {
        final tools = await findSystemTools();
        shortcutsPaths.addAll(tools);
      } catch (e) {
        print('Error finding system tools: $e');
      }

      // Offload heavy directory scanning to Isolate
      try {
        final foundInIsolate = await compute(
          _scanPathsInIsolate,
          _ScanRequest(
            desktopPaths: desktopScanPaths,
            startMenuPaths: startMenuScanPaths,
            showHidden: _showHidden,
          ),
        );
        shortcutsPaths.addAll(foundInIsolate);
        print('Isolate scan completed. Found ${foundInIsolate.length} items.');
      } catch (e) {
        print('Isolate scan failed: $e');
      }

      // 快速路径 diff：路径相同则无需解析图标和刷新 UI
      final incomingPaths = [...shortcutsPaths]..sort();
      final currentPaths = _shortcuts.map((e) => e.path).toList()..sort();
      final pathsUnchanged = _pathsEqual(currentPaths, incomingPaths);

      // 如果路径没有变化且不是强制显示加载状态（即非手动刷新），则直接返回
      if (pathsUnchanged && !showLoading && !forceReloadIcons) {
        if (shouldShowLoading) {
          _setState(() => _isLoading = false);
        }
        return;
      }

      const requestIconSize = 256;
      final existingIcons = <String, Uint8List?>{};
      for (final shortcut in _shortcuts) {
        existingIcons[shortcut.path] = shortcut.iconData;
      }

      final shortcutItems = <ShortcutItem>[];
      final seenTargetPaths = <String>{};

      for (final shortcutPath in shortcutsPaths) {
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
          continue;
        }

        // De-duplication
        final normTarget = targetPath.toLowerCase().trim();
        if (seenTargetPaths.contains(normTarget)) continue;
        seenTargetPaths.add(normTarget);

        shortcutItems.add(
          ShortcutItem(
            name: name,
            path: shortcutPath,
            iconPath: '',
            description: '应用',
            targetPath: targetPath,
            iconData: existingIcons[shortcutPath],
          ),
        );
      }

      // 插入已启用的系统项目（先用占位图标，后续异步补齐）
      final systemItemsToLoad = <SystemItemType>[];
      if (_showThisPC) systemItemsToLoad.add(SystemItemType.thisPC);
      if (_showRecycleBin) systemItemsToLoad.add(SystemItemType.recycleBin);
      if (_showControlPanel) systemItemsToLoad.add(SystemItemType.controlPanel);
      if (_showNetwork) systemItemsToLoad.add(SystemItemType.network);
      if (_showUserFiles) systemItemsToLoad.add(SystemItemType.userFiles);

      for (final type in systemItemsToLoad) {
        final virtualPath = SystemItemInfo.virtualPath(type);
        shortcutItems.add(
          ShortcutItem.system(type, iconData: existingIcons[virtualPath]),
        );
      }

      // 按名称自然排序（字母顺序），使系统项目与普通应用自然混合
      shortcutItems.sort((a, b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      final searchIndex = _buildSearchIndex(shortcutItems);
      _setState(() {
        _shortcuts = shortcutItems;
        _searchIndexByPath = searchIndex;
      });
      _syncCategoriesWithShortcuts(shortcutItems);

      if (shouldShowLoading) {
        _setState(() => _isLoading = false);
      }

      final loadToken = ++_shortcutLoadToken;
      unawaited(
        _hydrateShortcutIcons(
          shortcutItems,
          loadToken,
          requestIconSize,
          forceReloadIcons,
        ),
      );
    } catch (e) {
      print('加载快捷方式失败: $e');
      if (shouldShowLoading) {
        _setState(() => _isLoading = false);
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
      _setState(() {
        _categories = updated;
        if (clearActive) {
          _activeCategoryId = null;
        }
      });
      unawaited(_saveCategories());
    }
  }
}
