part of '../shortcut_card.dart';

extension _ShortcutCardMenu on _ShortcutCardState {
  Future<void> _copyToClipboard(
    String raw, {
    required String label,
    required bool quoted,
  }) async {
    final value = quoted ? _quote(raw) : raw;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied $label')));
  }

  String _quote(String raw) => '"${raw.replaceAll('"', '\\"')}"';

  Future<void> _showShortcutMenu(Offset globalPosition) async {
    final shortcut = widget.shortcut;
    final resolvedPath = shortcut.targetPath.isNotEmpty
        ? shortcut.targetPath
        : shortcut.path;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: [
        const PopupMenuItem(
          value: 'open',
          child: ListTile(leading: Icon(Icons.open_in_new), title: Text('打开')),
        ),
        if (!shortcut.isSystemItem) ...[
          const PopupMenuItem(
            value: 'open_with',
            child: ListTile(
              leading: Icon(Icons.app_registration),
              title: Text('使用其他应用打开'),
            ),
          ),
          const PopupMenuItem(
            value: 'show_in_explorer',
            child: ListTile(
              leading: Icon(Icons.folder_open),
              title: Text('在文件资源管理器中显示'),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'categorize',
            child: ListTile(
              leading: Icon(Icons.bookmarks_outlined),
              title: Text('添加到分类'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete),
              title: Text('删除(回收站)'),
            ),
          ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'copy_name',
          child: ListTile(leading: Icon(Icons.copy), title: Text('复制名称')),
        ),
        if (!shortcut.isSystemItem) ...[
          const PopupMenuItem(
            value: 'copy_path',
            child: ListTile(leading: Icon(Icons.link), title: Text('复制路径')),
          ),
          const PopupMenuItem(
            value: 'copy_folder',
            child: ListTile(
              leading: Icon(Icons.folder),
              title: Text('复制所在文件夹'),
            ),
          ),
        ],
      ],
    );

    switch (result) {
      case 'open':
        if (shortcut.isSystemItem) {
          SystemItemInfo.open(shortcut.systemItemType!);
        } else {
          openWithDefault(resolvedPath);
        }
        widget.onLaunched?.call();
        break;
      case 'open_with':
        // Reuse internal method or prompt
        // Note: openWithApp is available in desktop_helper
        final picked = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: ['exe', 'bat', 'cmd', 'com', 'lnk'],
        );
        if (picked != null && picked.files.isNotEmpty) {
          final appPath = picked.files.single.path;
          if (appPath != null) {
            await openWithApp(appPath, resolvedPath);
          }
        }
        break;
      case 'show_in_explorer':
        await showInExplorer(shortcut.path);
        break;
      case 'categorize':
        await widget.onCategoryMenuRequested?.call(shortcut, globalPosition);
        break;
      case 'delete':
        final ok = moveToRecycleBin(shortcut.path);
        if (!mounted) break;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ok ? '已移动到回收站' : '删除失败')));
        if (ok) {
          widget.onDeleted?.call();
        }
        break;
      case 'copy_name':
        await _copyToClipboard(shortcut.name, label: 'name', quoted: false);
        break;
      case 'copy_path':
        await _copyToClipboard(resolvedPath, label: 'path', quoted: true);
        break;
      case 'copy_folder':
        await _copyToClipboard(
          path.dirname(resolvedPath),
          label: 'folder',
          quoted: true,
        );
        break;
      default:
        break;
    }
  }
}
