import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../utils/desktop_helper.dart';
import '../models/icon_beautify_style.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/beautified_icon.dart';
import '../widgets/operation_progress_bar.dart';

class FilePage extends StatefulWidget {
  final String desktopPath;
  final bool showHidden;
  final bool beautifyIcons;
  final IconBeautifyStyle beautifyStyle;

  const FilePage({
    super.key,
    required this.desktopPath,
    this.showHidden = false,
    this.beautifyIcons = false,
    this.beautifyStyle = IconBeautifyStyle.cute,
  });

  @override
  State<FilePage> createState() => _FilePageState();
}

class _FilePageState extends State<FilePage> {
  String? _selectedPath;
  final FocusNode _focusNode = FocusNode();
  List<File> _files = [];

  // Custom double-tap state
  int _lastTapTime = 0;
  String _lastTappedPath = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showHidden != widget.showHidden ||
        oldWidget.desktopPath != widget.desktopPath) {
      _refresh();
    }
  }

  void _refresh() {
    final desktopDir = Directory(widget.desktopPath);
    if (!desktopDir.existsSync()) {
      setState(() => _files = []);
      return;
    }

    final files =
        desktopDir
            .listSync()
            .where((entity) {
              if (entity is! File) return false;
              final name = path.basename(entity.path);
              final lower = name.toLowerCase();

              if (!widget.showHidden &&
                  (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
                return false;
              }

              if (lower == 'desktop.ini' || lower == 'thumbs.db') {
                return false;
              }

              return !lower.endsWith('.lnk') && !lower.endsWith('.exe');
            })
            .map((e) => e as File)
            .toList()
          ..sort(
            (a, b) => path
                .basename(a.path)
                .toLowerCase()
                .compareTo(path.basename(b.path).toLowerCase()),
          );

    setState(() => _files = files);
  }

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
      if (result.success) {
        successCount++;
      }
    }

    if (successCount > 0) {
      _showSnackBar('已粘贴 $successCount 个项目');
      _refresh();
    } else {
      _showSnackBar('粘贴失败 (可能目标已存在或文件不可读)');
    }
  }

  Future<void> _deleteFile(String filePath) async {
    final fileName = path.basename(filePath);
    final success = moveToRecycleBin(filePath);
    if (!mounted) return;
    if (success) {
      _showSnackBar('已移动至回收站: $fileName');
      setState(() => _selectedPath = null);
      _refresh();
    } else {
      _showSnackBar('删除失败', success: false);
    }
  }

  Future<void> _promptRename(String filePath) async {
    final currentName = path.basename(filePath);
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
    final parentDir = path.dirname(filePath);
    final newPath = path.join(parentDir, newName);
    try {
      await File(filePath).rename(newPath);
      _showSnackBar('已重命名为 $newName');
      _refresh();
    } catch (e) {
      _showSnackBar('重命名失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_files.isEmpty) {
      return const Center(child: Text('未找到文件'));
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // Verbose debug log
        debugPrint(
          '[FilePage] Key: ${event.logicalKey.keyLabel} (${event.logicalKey.keyId})',
        );

        final isCtrl = HardwareKeyboard.instance.isControlPressed;

        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC) {
          final s = _selectedPath;
          if (s != null) {
            copyEntityPathsToClipboard([s]);
            _showSnackBar('已复制到剪贴板');
            return KeyEventResult.handled;
          }
        }
        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyV) {
          _handlePaste();
          return KeyEventResult.handled;
        }

        final focus = FocusManager.instance.primaryFocus;
        final isEditing =
            focus != null &&
            focus.context != null &&
            focus.context!.widget is EditableText;
        if (isEditing) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.numpadDecimal) {
          debugPrint('Delete/Backspace pressed, selected: $_selectedPath');
          final s = _selectedPath;
          if (s != null) {
            _deleteFile(s);
            return KeyEventResult.handled;
          }
        }
        if (event.logicalKey == LogicalKeyboardKey.f2) {
          final s = _selectedPath;
          if (s != null) {
            _promptRename(s);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 100,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          final name = path.basename(file.path);
          final isSelected = file.path == _selectedPath;

          return Material(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            child: InkWell(
              onTapDown: (_) {
                setState(() => _selectedPath = file.path);
                _focusNode.requestFocus();
              },
              onTap: () {
                final now = DateTime.now().millisecondsSinceEpoch;
                if (now - _lastTapTime < 300 && _lastTappedPath == file.path) {
                  openWithDefault(file.path);
                  _lastTapTime = 0;
                } else {
                  _lastTapTime = now;
                  _lastTappedPath = file.path;
                }
              },
              onSecondaryTapDown: (details) {
                setState(() => _selectedPath = file.path);
                _focusNode.requestFocus();
                _showFileMenu(context, file, details.globalPosition);
              },
              borderRadius: BorderRadius.circular(12),
              hoverColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FileIcon(
                      filePath: file.path,
                      beautifyIcon: widget.beautifyIcons,
                      beautifyStyle: widget.beautifyStyle,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Tooltip(
                        message: name,
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(height: 1.2, fontSize: 11),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showFileMenu(
    BuildContext context,
    File file,
    Offset position,
  ) async {
    final displayName = path.basename(file.path);
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
          child: ListTile(leading: Icon(Icons.open_in_new), title: Text('打开')),
        ),
        const PopupMenuItem(
          value: 'open_with',
          child: ListTile(
            leading: Icon(Icons.app_registration),
            title: Text('使用其他应用打开'),
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
            trailing: Text('F2', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('删除(回收站)'),
            trailing: Text('Del', style: Theme.of(context).textTheme.bodySmall),
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
          child: ListTile(leading: Icon(Icons.folder), title: Text('复制所在文件夹')),
        ),
      ],
    );

    if (!mounted) return;

    switch (result) {
      case 'open':
        await openWithDefault(file.path);
        break;
      case 'open_with':
        await _promptOpenWith(file.path);
        break;
      case 'move':
        await _promptMoveFile(context, file);
        break;
      case 'copy':
        await _promptCopyFile(context, file);
        break;
      case 'copy_clipboard':
        final ok = copyEntityPathsToClipboard([file.path]);
        if (mounted) {
          OperationManager.instance.quickTask(
            ok ? '已复制到剪贴板' : '复制到剪贴板失败',
            success: ok,
          );
        }
        break;
      case 'rename':
        await _promptRenameFile(context, file);
        break;
      case 'delete':
        _deleteFile(file.path);
        break;
      case 'copy_name':
        await copyToClipboard(displayName, label: 'name', quoted: false);
        break;
      case 'copy_path':
        await copyToClipboard(file.path, label: 'path', quoted: true);
        break;
      case 'copy_folder':
        await copyToClipboard(
          path.dirname(file.path),
          label: 'folder',
          quoted: true,
        );
        break;
      default:
        break;
    }
  }

  Future<void> copyToClipboard(
    String raw, {
    required String label,
    required bool quoted,
  }) async {
    final value = quoted ? '"${raw.replaceAll('"', '\\"')}"' : raw;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    OperationManager.instance.quickTask('已复制 $label');
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
        OperationManager.instance.quickTask('已重命名为 $newName');
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        OperationManager.instance.quickTask('重命名失败: $e', success: false);
      }
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
        if (mounted) {
          OperationManager.instance.quickTask('目标已存在同名文件', success: false);
        }
        return;
      }
      await file.rename(dest);
      if (mounted) {
        OperationManager.instance.quickTask('已移动到 $dest');
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        OperationManager.instance.quickTask('移动失败: $e', success: false);
      }
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
      if (result.success) {
        OperationManager.instance.quickTask('已复制到 ${result.destPath}');
      } else {
        OperationManager.instance.quickTask(
          '复制失败: ${result.message ?? 'unknown'}',
          success: false,
        );
      }
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
}

class _FileIcon extends StatelessWidget {
  final String filePath;
  final bool beautifyIcon;
  final IconBeautifyStyle beautifyStyle;
  final double size;

  const _FileIcon({
    required this.filePath,
    required this.beautifyIcon,
    required this.beautifyStyle,
    this.size = 28,
  });

  static final Map<String, Future<Uint8List?>> _iconFutures = {};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _resolveIcon(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null && data.isNotEmpty) {
          return BeautifiedIcon(
            bytes: data,
            fallback: Icons.apps,
            size: size,
            enabled: beautifyIcon,
            style: beautifyStyle,
            fit: BoxFit.contain, // best guess used
          );
        }
        final ext = path.extension(filePath).toLowerCase();
        final icon = ['.exe', '.lnk', '.url', '.appref-ms'].contains(ext)
            ? Icons.apps
            : Icons.insert_drive_file;
        return BeautifiedIcon(
          bytes: null,
          fallback: icon,
          size: size,
          enabled: beautifyIcon,
          style: beautifyStyle,
        );
      },
    );
  }

  Future<Uint8List?> _resolveIcon() async {
    final ext = path.extension(filePath).toLowerCase();
    final primary = await _getIconFuture(filePath);
    if (primary != null && primary.isNotEmpty) return primary;

    if (ext == '.lnk') {
      final target = getShortcutTarget(filePath);
      if (target != null && target.isNotEmpty) {
        final targetIcon = await _getIconFuture(target);
        if (targetIcon != null && targetIcon.isNotEmpty) return targetIcon;
      }
    }
    return null;
  }

  Future<Uint8List?> _getIconFuture(String path) {
    final key = path.toLowerCase();
    return _iconFutures.putIfAbsent(
      key,
      () => extractIconAsync(path, size: 96),
    );
  }
}
