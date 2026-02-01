part of '../file_page.dart';

extension _FilePageActions on _FilePageState {
  void _showSnackBar(String message, {bool success = true}) {
    OperationManager.instance.quickTask(message, success: success);
  }

  Future<void> _handlePaste() async {
    final files = getClipboardFilePaths();
    if (files.isEmpty) {
      _showSnackBar('剪贴板中没有文件');
      return;
    }
    final targetDir = widget.desktopPath;
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

  Future<void> _deleteFile(String filePath) async {
    final fileName = path.basename(filePath);
    final success = moveToRecycleBin(filePath);
    if (!mounted) return;
    if (success) {
      _showSnackBar('已移动至回收站: $fileName');
      _setState(() => _selectedPath = null);
      _refresh();
    } else {
      _showSnackBar('删除失败', success: false);
    }
  }

  Future<void> _promptNewFolderPage() async {
    final controller = TextEditingController(text: '新建文件夹');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '文件夹名称'),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final created = await createNewFolder(
      widget.desktopPath,
      preferredName: name,
    );
    if (created != null) {
      _showSnackBar('已创建 ${path.basename(created)}');
      _refresh();
    } else {
      _showSnackBar('创建失败', success: false);
    }
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

  Future<void> _promptRenameFile(BuildContext context, File file) async {
    final currentName = path.basename(file.path);
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新名称'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == currentName) return;
    final parentDir = path.dirname(file.path);
    final newPath = path.join(parentDir, newName);
    try {
      await file.rename(newPath);
      if (mounted) {
        _showSnackBar('已重命名为 $newName');
        _refresh();
      }
    } catch (e) {
      if (mounted) _showSnackBar('重命名失败: $e', success: false);
    }
  }

  Future<void> _promptMoveFile(BuildContext context, File file) async {
    final targetDir = await showFolderPicker(
      context: context,
      initialPath: path.dirname(file.path),
      showHidden: true,
    );
    if (targetDir == null || targetDir.isEmpty) return;
    final dest = path.join(targetDir, path.basename(file.path));
    try {
      if (File(dest).existsSync()) {
        if (mounted) _showSnackBar('目标已存在同名文件', success: false);
        return;
      }
      await file.rename(dest);
      if (mounted) {
        _showSnackBar('已移动到 $dest');
        _refresh();
      }
    } catch (e) {
      if (mounted) _showSnackBar('移动失败: $e', success: false);
    }
  }

  Future<void> _promptCopyFile(BuildContext context, File file) async {
    final targetDir = await showFolderPicker(
      context: context,
      initialPath: path.dirname(file.path),
      showHidden: true,
    );
    if (targetDir == null || targetDir.isEmpty) return;
    final result = await copyEntityToDirectory(file.path, targetDir);
    if (mounted) {
      if (result.success)
        _showSnackBar('已复制到 ${result.destPath}');
      else
        _showSnackBar('复制失败: ${result.message ?? 'unknown'}', success: false);
    }
  }

  Future<void> _promptOpenWithFile(
    BuildContext context,
    String targetPath,
  ) async {
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
}
