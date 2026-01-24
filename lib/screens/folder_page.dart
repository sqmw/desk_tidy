import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../utils/desktop_helper.dart';
import '../models/icon_beautify_style.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/glass.dart';
import '../widgets/beautified_icon.dart';
import '../widgets/operation_progress_bar.dart';

class FolderPage extends StatefulWidget {
  final String desktopPath;
  final bool showHidden;
  final bool beautifyIcons;
  final IconBeautifyStyle beautifyStyle;

  const FolderPage({
    super.key,
    required this.desktopPath,
    this.showHidden = false,
    this.beautifyIcons = false,
    this.beautifyStyle = IconBeautifyStyle.cute,
  });

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  late String _currentPath;
  bool _loading = true;
  String? _error;
  List<FileSystemEntity> _entries = [];
  bool _entityMenuActive = false;
  String? _selectedPath;
  final Map<String, Future<Uint8List?>> _iconFutures = {};
  int _lastTapTime = 0;
  String _lastTappedPath = '';
  final FocusNode _focusNode = FocusNode();

  bool get _isRootPath {
    final current = path.normalize(_currentPath).toLowerCase();
    final root = path.normalize(widget.desktopPath).toLowerCase();
    return current == root;
  }

  @override
  void initState() {
    super.initState();
    _currentPath = widget.desktopPath;
    _refresh();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FolderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showHidden != widget.showHidden) _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _iconFutures.clear();
    try {
      final dir = Directory(_currentPath);
      if (!dir.existsSync()) {
        setState(() {
          _entries = [];
          _error = '路径不存在';
          _loading = false;
        });
        return;
      }
      final allowFiles = !_isRootPath;
      final showHidden = widget.showHidden;
      final entries =
          dir.listSync().where((entity) {
            if (!allowFiles && entity is! Directory) return false;
            final name = path.basename(entity.path);
            if (!showHidden &&
                (name.startsWith('.') || isHiddenOrSystem(entity.path)))
              return false;
            final lower = name.toLowerCase();
            if (lower == 'desktop.ini' || lower == 'thumbs.db') return false;
            return allowFiles ? true : entity is Directory;
          }).toList()..sort((a, b) {
            final aIsDir = a is Directory;
            final bIsDir = b is Directory;
            if (aIsDir && !bIsDir) return -1;
            if (!aIsDir && bIsDir) return 1;
            return path
                .basename(a.path)
                .toLowerCase()
                .compareTo(path.basename(b.path).toLowerCase());
          });
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败: $e';
        _entries = [];
        _loading = false;
      });
    }
  }

  void _openFolder(String folderPath) {
    _currentPath = folderPath;
    _selectedPath = null;
    _refresh();
  }

  void _goUp() {
    final parent = path.dirname(_currentPath);
    if (parent == _currentPath) return;
    _currentPath = parent;
    _selectedPath = null;
    _refresh();
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

  Future<void> _showEntityMenu(FileSystemEntity entity, Offset position) async {
    _entityMenuActive = true;
    final isDir = entity is Directory;
    final displayName = path.basename(entity.path);
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
          PopupMenuItem(
            value: 'open',
            child: ListTile(
              leading: Icon(isDir ? Icons.folder_open : Icons.open_in_new),
              title: const Text('打开'),
            ),
          ),
          if (!isDir)
            const PopupMenuItem(
              value: 'open_with',
              child: ListTile(
                leading: Icon(Icons.app_registration),
                title: Text('使用其它应用打开'),
              ),
            ),
          const PopupMenuItem(
            value: 'open_in_explorer',
            child: ListTile(
              leading: Icon(Icons.folder),
              title: Text('在资源管理器打开'),
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
          if (isDir)
            _openFolder(entity.path);
          else
            await openWithDefault(entity.path);
          break;
        case 'open_with':
          if (!isDir) await _promptOpenWith(entity.path);
          break;
        case 'open_in_explorer':
          await openInExplorer(entity.path);
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
          {
            final ok = copyEntityPathsToClipboard([entity.path]);
            _showSnackBar(ok ? '已复制到剪贴板' : '复制到剪贴板失败');
          }
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
            label: '所在文件夹',
            quoted: true,
          );
          break;
        case 'rename':
          _promptRename(entity);
          break;
      }
    });
  }

  Future<void> _promptRename(FileSystemEntity entity) async {
    final currentName = path.basename(entity.path);
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
    final parentDir = path.dirname(entity.path);
    final newPath = path.join(parentDir, newName);
    try {
      await entity.rename(newPath);
      _showSnackBar('已重命名为 $newName');
      _refresh();
    } catch (e) {
      _showSnackBar('重命名失败: $e');
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
          _promptNewFolder();
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

  Future<void> _handlePaste() async {
    final files = getClipboardFilePaths();
    if (files.isEmpty) {
      _showSnackBar('剪贴板中没有文件');
      return;
    }
    final targetDir = _currentPath;
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
    final created = await createNewFolder(_currentPath, preferredName: name);
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
      setState(() => _selectedPath = null);
      _refresh();
    } else {
      _showSnackBar('删除失败', success: false);
    }
  }

  Future<void> _promptMove(FileSystemEntity entity) async {
    final targetDir = await showFolderPicker(
      context: context,
      initialPath: path.dirname(entity.path),
      showHidden: true,
    );
    if (targetDir == null || targetDir.isEmpty) return;
    final dest = path.join(targetDir, path.basename(entity.path));
    try {
      if (File(dest).existsSync() || Directory(dest).existsSync()) {
        _showSnackBar('目标已存在同名项', success: false);
        return;
      }
      await entity.rename(dest);
      _showSnackBar('已移动到 $dest');
      _refresh();
    } catch (e) {
      _showSnackBar('移动失败: $e', success: false);
    }
  }

  Future<void> _promptCopy(FileSystemEntity entity) async {
    final targetDir = await showFolderPicker(
      context: context,
      initialPath: path.dirname(entity.path),
      showHidden: true,
    );
    if (targetDir == null || targetDir.isEmpty) return;
    final result = await copyEntityToDirectory(entity.path, targetDir);
    if (mounted) {
      if (result.success)
        _showSnackBar('已复制到 ${result.destPath}');
      else
        _showSnackBar('复制失败: ${result.message ?? 'unknown'}', success: false);
    }
  }

  void _showSnackBar(String message, {bool success = true}) {
    OperationManager.instance.quickTask(message, success: success);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            opacity: 0.1,
            blurSigma: 10,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: _isRootPath ? null : _goUp,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentPath,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _refresh,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final isCtrl =
                  HardwareKeyboard.instance.isLogicalKeyPressed(
                    LogicalKeyboardKey.controlLeft,
                  ) ||
                  HardwareKeyboard.instance.isLogicalKeyPressed(
                    LogicalKeyboardKey.controlRight,
                  );
              if (isCtrl) {
                if (event.logicalKey == LogicalKeyboardKey.keyC) {
                  if (_selectedPath != null) {
                    copyEntityPathsToClipboard([_selectedPath!]);
                    _showSnackBar('已复制到剪贴板');
                    return KeyEventResult.handled;
                  }
                } else if (event.logicalKey == LogicalKeyboardKey.keyV) {
                  _handlePaste();
                  return KeyEventResult.handled;
                }
              }
              final focus = FocusManager.instance.primaryFocus;
              if (focus?.context?.widget is EditableText)
                return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.delete ||
                  event.logicalKey == LogicalKeyboardKey.backspace ||
                  event.logicalKey == LogicalKeyboardKey.numpadDecimal) {
                if (_selectedPath != null) {
                  _deleteEntity(File(_selectedPath!));
                  return KeyEventResult.handled;
                }
              } else if (event.logicalKey == LogicalKeyboardKey.f2) {
                if (_selectedPath != null) {
                  final entity = File(_selectedPath!).existsSync()
                      ? File(_selectedPath!) as FileSystemEntity
                      : Directory(_selectedPath!);
                  _promptRename(entity);
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapDown: (details) =>
                  _showPageMenu(details.globalPosition),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_error != null
                        ? Center(child: Text(_error!))
                        : (_entries.isEmpty
                              ? const Center(child: Text('未找到内容'))
                              : GridView.builder(
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 100,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.8,
                                      ),
                                  itemCount: _entries.length,
                                  itemBuilder: (context, index) {
                                    final entity = _entries[index];
                                    final name = path.basename(entity.path);
                                    final isDir = entity is Directory;
                                    final isSelected =
                                        entity.path == _selectedPath;
                                    return Material(
                                      color: isSelected
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.1)
                                          : Colors.transparent,
                                      child: InkWell(
                                        onTapDown: (_) {
                                          setState(
                                            () => _selectedPath = entity.path,
                                          );
                                          _focusNode.requestFocus();
                                        },
                                        onTap: () {
                                          final now = DateTime.now()
                                              .millisecondsSinceEpoch;
                                          if (now - _lastTapTime < 300 &&
                                              _lastTappedPath == entity.path) {
                                            if (isDir)
                                              _openFolder(entity.path);
                                            else
                                              openWithDefault(entity.path);
                                            _lastTapTime = 0;
                                          } else {
                                            _lastTapTime = now;
                                            _lastTappedPath = entity.path;
                                          }
                                        },
                                        onSecondaryTapDown: (details) {
                                          setState(
                                            () => _selectedPath = entity.path,
                                          );
                                          _focusNode.requestFocus();
                                          _showEntityMenu(
                                            entity,
                                            details.globalPosition,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        hoverColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _EntityIcon(
                                              entity: entity,
                                              beautifyIcon:
                                                  widget.beautifyIcons,
                                              beautifyStyle:
                                                  widget.beautifyStyle,
                                              getIconFuture: _getIconFuture,
                                            ),
                                            const SizedBox(height: 8),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              child: Text(
                                                name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(fontSize: 11),
                                                maxLines: 2,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ))),
            ),
          ),
        ),
      ],
    );
  }

  Future<Uint8List?> _getIconFuture(String path) {
    final key = path.toLowerCase();
    return _iconFutures.putIfAbsent(
      key,
      () => extractIconAsync(path, size: 96),
    );
  }
}

class _EntityIcon extends StatelessWidget {
  final FileSystemEntity entity;
  final bool beautifyIcon;
  final IconBeautifyStyle beautifyStyle;
  final Future<Uint8List?> Function(String path) getIconFuture;
  const _EntityIcon({
    required this.entity,
    required this.beautifyIcon,
    required this.beautifyStyle,
    required this.getIconFuture,
  });

  @override
  Widget build(BuildContext context) {
    if (entity is Directory) {
      return BeautifiedIcon(
        bytes: null,
        fallback: Icons.folder,
        size: 48,
        enabled: beautifyIcon,
        style: beautifyStyle,
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _resolveIcon(),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty) {
          return BeautifiedIcon(
            bytes: snapshot.data,
            fallback: Icons.apps,
            size: 48,
            enabled: beautifyIcon,
            style: beautifyStyle,
          );
        }
        final ext = path.extension(entity.path).toLowerCase();
        final icon = ['.exe', '.lnk', '.url', '.appref-ms'].contains(ext)
            ? Icons.apps
            : Icons.insert_drive_file;
        return BeautifiedIcon(
          bytes: null,
          fallback: icon,
          size: 48,
          enabled: beautifyIcon,
          style: beautifyStyle,
        );
      },
    );
  }

  Future<Uint8List?> _resolveIcon() async {
    final ext = path.extension(entity.path).toLowerCase();
    final primary = await getIconFuture(entity.path);
    if (primary != null && primary.isNotEmpty) return primary;
    if (ext == '.lnk') {
      final target = getShortcutTarget(entity.path);
      if (target != null && target.isNotEmpty) {
        final targetIcon = await getIconFuture(target);
        if (targetIcon != null && targetIcon.isNotEmpty) return targetIcon;
      }
    }
    return null;
  }
}
