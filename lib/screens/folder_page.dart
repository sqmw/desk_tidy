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
import '../widgets/middle_ellipsis_text.dart';
import '../widgets/beautified_icon.dart';

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
  final Map<String, Future<Uint8List?>> _iconFutures = {};

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
  void didUpdateWidget(covariant FolderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showHidden != widget.showHidden) {
      _refresh();
    }
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

      final items = dir.listSync().where((entity) {
        if (!allowFiles && entity is! Directory) return false;
        final name = path.basename(entity.path);
        final lower = name.toLowerCase();
        if (!widget.showHidden &&
            (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
          return false;
        }
        if (lower == 'desktop.ini' || lower == 'thumbs.db') return false;
        return allowFiles ? true : entity is Directory;
      }).toList()
        ..sort((a, b) {
          return path.basename(a.path).toLowerCase().compareTo(
                path.basename(b.path).toLowerCase(),
              );
        });

      setState(() {
        _entries = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _entries = [];
        _loading = false;
      });
    }
  }

  void _openFolder(String folderPath) {
    _currentPath = folderPath;
    _refresh();
  }

  void _goUp() {
    final parent = path.dirname(_currentPath);
    if (parent == _currentPath) return;
    _currentPath = parent;
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
    _showSnackBar('已复制$label');
  }

  Future<void> _showEntityMenu(
    FileSystemEntity entity,
    Offset position,
  ) async {
    _entityMenuActive = true;
    final isDir = entity is Directory;
    final displayName = path.basename(entity.path);
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
        const PopupMenuItem(
          value: 'move',
          child: ListTile(
            leading: Icon(Icons.drive_file_move),
            title: Text('移动到..'),
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('复制到...'),
          ),
        ),
        const PopupMenuItem(
          value: 'copy_clipboard',
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('复制到剪贴板(系统)'),
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete),
            title: Text('删除(回收站)'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'copy_name',
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('复制名称'),
          ),
        ),
        const PopupMenuItem(
          value: 'copy_path',
          child: ListTile(
            leading: Icon(Icons.link),
            title: Text('复制路径'),
          ),
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

    switch (result) {
      case 'open':
        if (isDir) {
          _openFolder(entity.path);
        } else {
          await openWithDefault(entity.path);
        }
        break;
      case 'open_with':
        if (!isDir) {
          await _promptOpenWith(entity.path);
        }
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
        final ok = copyEntityPathsToClipboard([entity.path]);
        if (mounted) {
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
      default:
        break;
    }
    _entityMenuActive = false;
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
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: const [
        PopupMenuItem(
          value: 'new_folder',
          child: ListTile(
            leading: Icon(Icons.create_new_folder),
            title: Text('新建文件夹'),
          ),
        ),
        PopupMenuItem(
          value: 'refresh',
          child: ListTile(
            leading: Icon(Icons.refresh),
            title: Text('刷新'),
          ),
        ),
      ],
    );

    switch (result) {
      case 'new_folder':
        _promptNewFolder();
        break;
      case 'refresh':
        _refresh();
        break;
      default:
        break;
    }
  }

  Future<void> _promptNewFolder() async {
    final controller = TextEditingController(text: '新建文件夹');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建文件夹'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '名称',
            ),
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
        );
      },
    );

    if (confirmed != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;

    final target = path.join(_currentPath, name);
    try {
      if (Directory(target).existsSync() || File(target).existsSync()) {
        _showSnackBar('同名文件或文件夹已存在');
        return;
      }
      await Directory(target).create(recursive: true);
      _showSnackBar('已创建 $target');
      _refresh();
    } catch (e) {
      _showSnackBar('创建失败: $e');
    }
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    final success = moveToRecycleBin(entity.path);
    if (!mounted) return;
    if (success) {
      _showSnackBar('已移动到回收站');
      _refresh();
    } else {
      _showSnackBar('删除失败');
    }
  }

  Future<void> _promptMove(FileSystemEntity entity) async {
    final targetDir = await showFolderPicker(
      context: context,
      initialPath: _currentPath,
      showHidden: widget.showHidden,
    );
    if (targetDir == null || targetDir.isEmpty) return;
    final dest = path.join(targetDir, path.basename(entity.path));

    try {
      final dir = Directory(targetDir);
      if (!dir.existsSync()) {
        _showSnackBar('目标路径不存在');
        return;
      }
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
    final targetDir = await showFolderPicker(
      context: context,
      initialPath: _currentPath,
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<Uint8List?> _getIconFuture(String path) {
    final key = path.toLowerCase();
    return _iconFutures.putIfAbsent(
      key,
      () => extractIconAsync(path, size: 96),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            opacity: 0.14,
            blurSigma: 10,
            border: Border.all(
              color:
                  Theme.of(context).dividerColor.withValues(alpha: 0.16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _currentPath == widget.desktopPath ? null : _goUp,
                ),
                Expanded(
                  child: Text(
                    _currentPath,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onSecondaryTapDown: (details) =>
                _showPageMenu(details.globalPosition),
            child: _entries.isEmpty
                ? const Center(child: Text('未找到内容'))
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entity = _entries[index];
                      final isDir = entity is Directory;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isDir ? () => _openFolder(entity.path) : null,
                          onDoubleTap: () async {
                            if (isDir) {
                              _openFolder(entity.path);
                            } else {
                              await openWithDefault(entity.path);
                            }
                          },
                          onSecondaryTapDown: (details) {
                            _showEntityMenu(entity, details.globalPosition);
                          },
                          borderRadius: BorderRadius.circular(8),
                          hoverColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          child: ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            leading: _EntityIcon(
                              entity: entity,
                              getIconFuture: _getIconFuture,
                              beautifyIcon: widget.beautifyIcons,
                              beautifyStyle: widget.beautifyStyle,
                            ),
                            title: Tooltip(
                              message: path.basename(entity.path),
                              child: Text(
                                path.basename(entity.path),
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            subtitle: Tooltip(
                              message: entity.path,
                              child: MiddleEllipsisText(
                                text: entity.path,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            trailing: null,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _EntityIcon extends StatelessWidget {
  final FileSystemEntity entity;
  final Future<Uint8List?> Function(String path) getIconFuture;
  final bool beautifyIcon;
  final IconBeautifyStyle beautifyStyle;

  const _EntityIcon({
    required this.entity,
    required this.getIconFuture,
    required this.beautifyIcon,
    required this.beautifyStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (entity is Directory) {
      return BeautifiedIcon(
        bytes: null,
        fallback: Icons.folder,
        size: 28,
        enabled: beautifyIcon,
        style: beautifyStyle,
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _resolveIconBytes(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null && data.isNotEmpty) {
          return BeautifiedIcon(
            bytes: data,
            fallback: Icons.apps,
            size: 28,
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
          size: 28,
          enabled: beautifyIcon,
          style: beautifyStyle,
        );
      },
    );
  }

  Future<Uint8List?> _resolveIconBytes() async {
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
