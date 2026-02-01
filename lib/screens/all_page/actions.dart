part of '../all_page.dart';

extension _AllPageActions on _AllPageState {
  void _selectEntity(FileSystemEntity entity, String displayName) {
    if (_renameOverlay.isActive) _renameOverlay.hide();
    _setState(() {
      _selected = _EntitySelectionInfo(
        name: displayName,
        fullPath: entity.path,
        folderPath: path.dirname(entity.path),
        entity: entity,
      );
    });
  }

  Future<void> _copyToClipboard(
    String raw, {
    required String label,
    required bool quoted,
  }) async {
    final value = quoted ? '"${raw.replaceAll('"', '\\"')}"' : raw;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showSnackBar('已复制 $label');
  }

  void _promptRename(FileSystemEntity entity, [BuildContext? anchorContext]) {
    final currentName = path.basename(entity.path);
    Rect? anchorRect;

    if (anchorContext != null) {
      final renderBox = anchorContext.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final topLeft = renderBox.localToGlobal(Offset.zero);
        anchorRect = Rect.fromLTWH(
          topLeft.dx,
          topLeft.dy,
          renderBox.size.width,
          renderBox.size.height,
        );
      }
    }

    if (anchorRect == null) {
      final size = MediaQuery.of(context).size;
      anchorRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 3),
        width: 300,
        height: 40,
      );
    }

    _renameOverlay.show(
      context: context,
      anchorRect: anchorRect,
      currentName: currentName,
      onRename: (newName) async {
        if (newName == currentName) return;
        final parentDir = path.dirname(entity.path);
        final newPath = path.join(parentDir, newName);
        try {
          await entity.rename(newPath);
          _showSnackBar('已重命名为 $newName');
          _refresh();
        } catch (e) {
          _showSnackBar('重命名失败: $e');
        }
      },
    );
  }

  Future<void> _renameEntity(FileSystemEntity entity, String newName) async {
    if (newName.isEmpty) return;
    final parent = path.dirname(entity.path);
    final ext = path.extension(entity.path);
    String finalName = newName;
    if (ext.toLowerCase() == '.lnk' &&
        !newName.toLowerCase().endsWith('.lnk')) {
      finalName = '$newName.lnk';
    } else if (ext.isNotEmpty &&
        !newName.toLowerCase().endsWith(ext.toLowerCase())) {
      finalName = '$newName$ext';
    }
    if (path.basename(entity.path) == finalName) return;
    final newPath = path.join(parent, finalName);
    try {
      await entity.rename(newPath);
      _showSnackBar('已重命名为 $newName');
      _refresh();
    } catch (e) {
      _showSnackBar('重命名失败: $e');
    }
  }

  Future<void> _handlePaste() async {
    final files = getClipboardFilePaths();
    if (files.isEmpty) {
      _showSnackBar('剪贴板中没有文件');
      return;
    }
    final targetDir = _currentPath ?? widget.desktopPath;
    int successCount = 0;
    for (final srcPath in files) {
      final result = await copyEntityToDirectory(srcPath, targetDir);
      if (result.success) successCount++;
    }
    if (successCount > 0) {
      _showSnackBar('已粘贴 $successCount 个项目');
      _refresh();
    } else {
      _showSnackBar('粘贴失败', success: false);
    }
  }

  Future<void> _promptNewFolder() async {
    final controller = TextEditingController(text: '新建文件夹');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
          onSubmitted: (_) => Navigator.of(context).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final base = _currentPath ?? widget.desktopPath;
    final created = await createNewFolder(base, preferredName: name);
    if (created != null) {
      _showSnackBar('已创建 ${path.basename(created)}');
      _refresh();
    } else {
      _showSnackBar('创建失败', success: false);
    }
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    final fileName = path.basename(entity.path);
    final success = moveToRecycleBin(entity.path);
    if (!mounted) return;
    if (success) {
      _showSnackBar('已移动至回收站: $fileName');
      _setState(() => _selected = null);
      _refresh();
    } else {
      _showSnackBar('删除失败', success: false);
    }
  }

  Future<void> _promptMove(FileSystemEntity entity) async {
    final initial = _currentPath ?? path.dirname(entity.path);
    final targetDir = await showFolderPicker(
      context: context,
      initialPath: initial,
      showHidden: widget.showHidden,
    );
    if (targetDir == null || targetDir.isEmpty) return;
    final dest = path.join(targetDir, path.basename(entity.path));
    try {
      if (File(dest).existsSync() || Directory(dest).existsSync()) {
        _showSnackBar('目标已存在同名项');
        return;
      }
      await entity.rename(dest);
      _showSnackBar('已移动到 $dest');
      _refresh();
    } catch (e) {
      _showSnackBar('移动失败: $e');
    }
  }

  Future<void> _promptCopy(FileSystemEntity entity) async {
    final initial = _currentPath ?? path.dirname(entity.path);
    final targetDir = await showFolderPicker(
      context: context,
      initialPath: initial,
      showHidden: widget.showHidden,
    );
    if (targetDir == null || targetDir.isEmpty) return;
    final result = await copyEntityToDirectory(entity.path, targetDir);
    if (!mounted) return;
    if (result.success) {
      _showSnackBar('已复制到 ${result.destPath}');
      _refresh();
    } else {
      _showSnackBar('复制失败: ${result.message ?? 'unknown'}');
    }
  }

  Future<void> _promptOpenWith(String targetPath) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['exe', 'bat', 'cmd', 'com', 'lnk'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final appPath = picked.files.single.path;
    if (appPath == null || appPath.isEmpty) return;
    await openWithApp(appPath, targetPath);
  }

  void _showSnackBar(String message, {bool success = true}) {
    OperationManager.instance.quickTask(message, success: success);
  }
}
