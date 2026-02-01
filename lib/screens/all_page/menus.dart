part of '../all_page.dart';

extension _AllPageMenus on _AllPageState {
  Future<void> _showEntityMenu(
    FileSystemEntity entity,
    String displayName,
    Offset position, {
    BuildContext? anchorContext,
  }) async {
    _entityMenuActive = true;
    final isDir = entity is Directory;

    Future.microtask(() async {
      if (!mounted) return;
      final result = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx + 1,
          position.dy + 1,
        ),
        items: [
          const PopupMenuItem(
            value: 'open',
            child: ListTile(
              leading: Icon(Icons.open_in_new),
              title: Text('打开'),
            ),
          ),
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
            value: 'move',
            child: ListTile(
              leading: Icon(Icons.drive_file_move),
              title: Text('移动到..'),
            ),
          ),
          const PopupMenuItem(
            value: 'copy',
            child: ListTile(leading: Icon(Icons.copy), title: Text('复制到...')),
          ),
          PopupMenuItem(
            value: 'copy_clipboard',
            child: ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制到剪贴板(系统)'),
              trailing: Text(
                'Ctrl+C',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              trailing: Text(
                'F2',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('删除(回收站)'),
              trailing: Text(
                'Del',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'copy_name',
            child: ListTile(leading: Icon(Icons.copy), title: Text('复制名称')),
          ),
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
      );

      _entityMenuActive = false;
      if (!mounted || result == null) return;

      switch (result) {
        case 'open':
          if (isDir) {
            _openFolder(entity.path);
          } else {
            await openWithDefault(entity.path);
          }
          break;
        case 'open_with':
          await _promptOpenWith(entity.path);
          break;
        case 'show_in_explorer':
          await showInExplorer(entity.path);
          break;
        case 'delete':
          _deleteEntity(entity);
          break;
        case 'move':
          _promptMove(entity);
          break;
        case 'copy':
          _promptCopy(entity);
          break;
        case 'copy_clipboard':
          final ok = copyEntityPathsToClipboard([entity.path]);
          if (mounted) _showSnackBar(ok ? '已复制到剪贴板' : '复制到剪贴板失败');
          break;
        case 'copy_name':
          await _copyToClipboard(displayName, label: '名称', quoted: false);
          break;
        case 'copy_path':
          await _copyToClipboard(entity.path, label: '路径', quoted: true);
          break;
        case 'copy_folder':
          await _copyToClipboard(
            path.dirname(entity.path),
            label: '文件夹',
            quoted: true,
          );
          break;
        case 'rename':
          _promptRename(entity, anchorContext);
          break;
      }
    });
  }

  Future<void> _showPageMenu(Offset position) async {
    if (_entityMenuActive) return;
    Future.microtask(() async {
      if (!mounted) return;
      final result = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx + 1,
          position.dy + 1,
        ),
        items: [
          const PopupMenuItem(
            value: 'new_folder',
            child: ListTile(
              leading: Icon(Icons.create_new_folder),
              title: Text('新建文件夹'),
            ),
          ),
          const PopupMenuItem(
            value: 'refresh',
            child: ListTile(leading: Icon(Icons.refresh), title: Text('刷新')),
          ),
          PopupMenuItem(
            value: 'paste',
            child: ListTile(
              leading: const Icon(Icons.paste),
              title: const Text('粘贴'),
              trailing: Text(
                'Ctrl+V',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      );

      if (!mounted || result == null) return;
      switch (result) {
        case 'new_folder':
          await _promptNewFolder();
          break;
        case 'refresh':
          _refresh();
          break;
        case 'paste':
          await _handlePaste();
          break;
      }
    });
  }
}
