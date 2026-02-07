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

  Future<void> _openShortcutFromHome(ShortcutItem shortcut) async {
    if (shortcut.isSystemItem) {
      SystemItemInfo.open(shortcut.systemItemType!);
      if (_lastActivationMode == _ActivationMode.hotkey) {
        _dismissToTray(fromHotCorner: false);
      }
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

    final launched = await openWithDefault(_launchPathForShortcut(shortcut));
    if (!launched) {
      OperationManager.instance.quickTask('启动失败，请重试', success: false);
      return;
    }
    if (_lastActivationMode == _ActivationMode.hotkey) {
      _dismissToTray(fromHotCorner: false);
    }
  }
}
