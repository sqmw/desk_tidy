part of '../../desk_tidy_home_page.dart';

extension _DeskTidyHomeShortcutLaunch on _DeskTidyHomePageState {
  bool _isBrokenShortcut(ShortcutItem shortcut) {
    if (shortcut.isSystemItem) return false;
    final ext = path.extension(shortcut.path).toLowerCase();
    if (ext != '.lnk') return false;

    final target = shortcut.targetPath.trim();
    if (target.isEmpty || target.toLowerCase() == shortcut.path.toLowerCase()) {
      return false;
    }

    return !File(target).existsSync() && !Directory(target).existsSync();
  }

  String _launchPathForShortcut(ShortcutItem shortcut) {
    final ext = path.extension(shortcut.path).toLowerCase();
    if (ext == '.lnk' || ext == '.appref-ms') {
      // Launch through the shortcut file so Windows can apply Start-In/cmdline.
      return shortcut.path;
    }
    if (shortcut.targetPath.isNotEmpty) return shortcut.targetPath;
    return shortcut.path;
  }

  Future<bool> _confirmDeleteBrokenShortcut(ShortcutItem shortcut) async {
    final target = shortcut.targetPath;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('快捷方式已失效'),
          content: Text('找不到目标文件：\n$target\n\n是否删除该快捷方式？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return shouldDelete ?? false;
  }

  Future<LaunchFeedbackSession> _launchShortcutWithFeedback(
    ShortcutItem shortcut, {
    required bool showTaskbarIndicator,
  }) {
    return LaunchFeedbackService.instance.launchWithPerceptibleFeedback(
      launchPath: _launchPathForShortcut(shortcut),
      targetPath: shortcut.targetPath,
      preferredIconBytes: shortcut.iconData,
      showTaskbarIndicator: showTaskbarIndicator,
    );
  }

  void _setShortcutLaunching(String shortcutPath, bool launching) {
    if (!mounted) return;
    final currentlyLaunching = _launchingShortcutPaths.contains(shortcutPath);
    if (currentlyLaunching == launching) return;

    _setState(() {
      if (launching) {
        _launchingShortcutPaths.add(shortcutPath);
      } else {
        _launchingShortcutPaths.remove(shortcutPath);
      }
    });
  }

  void _trackShortcutLaunchReady({
    required ShortcutItem shortcut,
    required Future<void> ready,
  }) {
    final pathKey = shortcut.path;
    unawaited(
      ready.whenComplete(() {
        _setShortcutLaunching(pathKey, false);
      }),
    );
  }

  void _notifyLaunchFailedInTray(ShortcutItem shortcut) {
    final shown = showTrayBalloon(
      windowHandle: _windowHandle,
      title: 'Desk Tidy',
      message: '启动失败：${shortcut.name}',
    );
    if (!shown) {
      OperationManager.instance.quickTask('启动失败，请重试', success: false);
    }
  }

  Future<void> _launchShortcutFromHotkeyInBackground(
    ShortcutItem shortcut,
  ) async {
    _setShortcutLaunching(shortcut.path, true);
    final session = await _launchShortcutWithFeedback(
      shortcut,
      showTaskbarIndicator: true,
    );
    if (!session.launched) {
      _setShortcutLaunching(shortcut.path, false);
      _notifyLaunchFailedInTray(shortcut);
      return;
    }
    _trackShortcutLaunchReady(shortcut: shortcut, ready: session.ready);
  }

  Future<void> _openShortcutFromHome(ShortcutItem shortcut) async {
    final fromHotkey = _lastActivationMode == _ActivationMode.hotkey;

    if (shortcut.isSystemItem) {
      if (fromHotkey) {
        unawaited(_dismissToTray(fromHotCorner: false));
      }
      SystemItemInfo.open(shortcut.systemItemType!);
      return;
    }

    if (_isBrokenShortcut(shortcut)) {
      final shouldDelete = await _confirmDeleteBrokenShortcut(shortcut);
      if (!shouldDelete) return;
      final deleted = moveToRecycleBin(shortcut.path);
      OperationManager.instance.quickTask(
        deleted ? '已移动到回收站' : '删除失败',
        success: deleted,
      );
      if (deleted) {
        await _loadShortcuts(showLoading: false);
      }
      return;
    }

    if (fromHotkey) {
      // Render one frame of launch feedback, then dismiss without blocking.
      unawaited(_launchShortcutFromHotkeyInBackground(shortcut));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_dismissToTray(fromHotCorner: false));
      });
      return;
    }

    _setShortcutLaunching(shortcut.path, true);
    final session = await _launchShortcutWithFeedback(
      shortcut,
      showTaskbarIndicator: true,
    );
    if (!session.launched) {
      _setShortcutLaunching(shortcut.path, false);
      OperationManager.instance.quickTask('启动失败，请重试', success: false);
      return;
    }
    _trackShortcutLaunchReady(shortcut: shortcut, ready: session.ready);
  }
}
