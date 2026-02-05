part of '../desk_tidy_home_page.dart';

extension _DeskTidyHomeRefreshLogic on _DeskTidyHomePageState {
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
      final foundDesktopEntries = await compute(
        _scanPathsInIsolate,
        _ScanRequest(
          desktopPaths: desktopScanPaths,
          desktopShortcutPaths: const [],
          startMenuPaths: const [],
          showHidden: _showHidden,
        ),
      );
      if (!mounted) return;
      if (_trayMode || !_panelVisible) return;
      if (_selectedIndex != 0) return;
      if (!ignoreAutoRefreshEnabled && !_autoRefresh) return;

      final foundDesktopPaths = foundDesktopEntries
          .map((e) => e['path'] ?? '')
          .where((p) => p.isNotEmpty)
          .toList();
      final snapshot = foundDesktopPaths.map((e) => e.toLowerCase()).toList()
        ..sort();
      if (_pathsEqual(_autoRefreshDesktopPathsSnapshot, snapshot)) return;

      _autoRefreshDesktopPathsSnapshot = snapshot;
      await _loadShortcuts(
        showLoading: false,
        desktopShortcutPathsOverride: foundDesktopPaths,
      );
    } catch (_) {
      // Ignore auto refresh probe failures.
    } finally {
      _autoRefreshProbeInFlight = false;
    }
  }
}
