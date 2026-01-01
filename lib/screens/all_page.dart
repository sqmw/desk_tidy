import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../utils/desktop_helper.dart';
import '../widgets/entity_detail_bar.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/glass.dart';
import '../widgets/middle_ellipsis_text.dart';

class AllPage extends StatefulWidget {
  final String desktopPath;
  final bool showHidden;

  const AllPage({
    super.key,
    required this.desktopPath,
    this.showHidden = false,
  });

  @override
  State<AllPage> createState() => _AllPageState();
}

class _EntitySelectionInfo {
  final String name;
  final String fullPath;
  final String folderPath;

  const _EntitySelectionInfo({
    required this.name,
    required this.fullPath,
    required this.folderPath,
  });
}

class _AllPageState extends State<AllPage> {
  String? _currentPath; // null means aggregate desktop roots
  bool _loading = true;
  String? _error;
  List<FileSystemEntity> _entries = [];
  bool _entityMenuActive = false;
  _EntitySelectionInfo? _selected;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant AllPage oldWidget) {
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
    try {
      if (_currentPath == null) {
        final entries = _loadAggregateRoots();
        setState(() {
          _entries = entries;
          _loading = false;
        });
      } else {
        final dir = Directory(_currentPath!);
        if (!dir.existsSync()) {
          setState(() {
            _entries = [];
            _error = '路径不存在';
            _loading = false;
          });
          return;
        }
        final entries = dir.listSync().where((entity) {
          final name = path.basename(entity.path);
          final lower = name.toLowerCase();
          if (!widget.showHidden &&
              (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
            return false;
          }
          if (lower == 'desktop.ini' || lower == 'thumbs.db') return false;
          return true;
        }).toList()
          ..sort((a, b) {
            final aIsDir = a is Directory;
            final bIsDir = b is Directory;
            if (aIsDir && !bIsDir) return -1;
            if (!aIsDir && bIsDir) return 1;
            return path.basename(a.path).toLowerCase().compareTo(
                  path.basename(b.path).toLowerCase(),
                );
          });
        setState(() {
          _entries = entries;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _entries = [];
        _loading = false;
      });
    }
  }

  List<FileSystemEntity> _loadAggregateRoots() {
    final directories = desktopLocations(widget.desktopPath);
    final seen = <String>{};
    final entries = <FileSystemEntity>[];

    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync()) {
        if (!seen.add(entity.path)) continue;
        final name = path.basename(entity.path);
        final lower = name.toLowerCase();

        if (!widget.showHidden &&
            (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
          continue;
        }

        if (lower == 'desktop.ini' || lower == 'thumbs.db') {
          continue;
        }

        entries.add(entity);
      }
    }

    entries.sort((a, b) => path
        .basename(a.path)
        .toLowerCase()
        .compareTo(path.basename(b.path).toLowerCase()));
    return entries;
  }

  void _openFolder(String folderPath) {
    _currentPath = folderPath;
    _refresh();
  }

  void _goUp() {
    if (_currentPath == null) return;
    final parent = path.dirname(_currentPath!);
    if (parent == _currentPath) {
      _currentPath = null;
    } else {
      _currentPath = parent;
    }
    _refresh();
  }

  void _goHome() {
    _currentPath = null;
    _refresh();
  }

  Future<void> _showEntityMenu(
    FileSystemEntity entity,
    String displayName,
    Offset position,
  ) async {
    _entityMenuActive = true;
    final isDir = entity is Directory;
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
          value: 'open',
          child: ListTile(
            leading: Icon(Icons.open_in_new),
            title: Text('打开'),
          ),
        ),
        PopupMenuItem(
          value: 'open_with',
          child: ListTile(
            leading: Icon(Icons.app_registration),
            title: Text('使用其他应用打开'),
          ),
        ),
        PopupMenuItem(
          value: 'move',
          child: ListTile(
            leading: Icon(Icons.drive_file_move),
            title: Text('移动到..'),
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('复制到...'),
          ),
        ),
        PopupMenuItem(
          value: 'copy_clipboard',
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('复制到剪贴板(系统)'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete),
            title: Text('删除(回收站)'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'copy_name',
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('复制名称'),
          ),
        ),
        PopupMenuItem(
          value: 'copy_path',
          child: ListTile(
            leading: Icon(Icons.link),
            title: Text('复制路径'),
          ),
        ),
        PopupMenuItem(
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
        await _promptOpenWith(entity.path);
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
        await _copyToClipboard(displayName, label: 'name', quoted: false);
        break;
      case 'copy_path':
        await _copyToClipboard(entity.path, label: 'path', quoted: true);
        break;
      case 'copy_folder':
        await _copyToClipboard(
          path.dirname(entity.path),
          label: 'folder',
          quoted: true,
        );
        break;
      default:
        break;
    }
    _entityMenuActive = false;
  }

  void _selectEntity(FileSystemEntity entity, String displayName) {
    setState(() {
      _selected = _EntitySelectionInfo(
        name: displayName,
        fullPath: entity.path,
        folderPath: path.dirname(entity.path),
      );
    });
  }

  Future<void> _copyToClipboard(
    String raw, {
    required String label,
    required bool quoted,
  }) async {
    final value = quoted ? _quote(raw) : raw;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $label')),
    );
  }

  String _quote(String raw) => '"${raw.replaceAll('"', '\\"')}"';

  Widget _buildSelectionDetail() {
    final selected = _selected;
    if (selected == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: EntityDetailBar(
        name: selected.name,
        path: selected.fullPath,
        folderPath: selected.folderPath,
        onCopyName: () => _copyToClipboard(
          selected.name,
          label: 'name',
          quoted: false,
        ),
        onCopyPath: () => _copyToClipboard(
          selected.fullPath,
          label: 'path',
          quoted: true,
        ),
        onCopyFolder: () => _copyToClipboard(
          selected.folderPath,
          label: 'folder',
          quoted: true,
        ),
      ),
    );
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
    final base = _currentPath ?? widget.desktopPath;
    final target = path.join(base, name);
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
    final initial = _currentPath ?? path.dirname(entity.path);
    final targetDir = await showFolderPicker(
      context: context,
      initialPath: initial,
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final pathLabel = _currentPath ?? '${widget.desktopPath} (合并视图)';

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
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  icon: const Icon(Icons.home),
                  onPressed: _currentPath == null ? null : _goHome,
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _currentPath == null ? null : _goUp,
                ),
                Expanded(
                  child: Text(
                    pathLabel,
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
        _buildSelectionDetail(),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onSecondaryTapDown: (details) =>
                _showPageMenu(details.globalPosition),
            child: _entries.isEmpty
                ? const Center(child: Text('未找到文件或快捷方式'))
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entity = _entries[index];
                      final isDir = entity is Directory;
                      final rawName = path.basename(entity.path);
                      final displayName = rawName.toLowerCase().endsWith('.lnk')
                          ? rawName.substring(0, rawName.length - 4)
                          : rawName;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _selectEntity(entity, displayName);
                            if (isDir) {
                              _openFolder(entity.path);
                            }
                          },
                          onDoubleTap: () async {
                            _selectEntity(entity, displayName);
                            if (isDir) {
                              _openFolder(entity.path);
                            } else {
                              await openWithDefault(entity.path);
                            }
                          },
                          onSecondaryTapDown: (details) {
                            _selectEntity(entity, displayName);
                            _showEntityMenu(
                              entity,
                              displayName,
                              details.globalPosition,
                            );
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
                            leading: _EntityIcon(entity: entity),
                            title: Tooltip(
                              message: displayName,
                              child: Text(
                                displayName,
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

  const _EntityIcon({required this.entity});

  @override
  Widget build(BuildContext context) {
    if (entity is Directory) {
      return const Icon(Icons.folder, size: 32);
    }

    return FutureBuilder<Uint8List?>(
      future: _resolveIconBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty) {
          return Image.memory(
            snapshot.data!,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          );
        }
        final ext = path.extension(entity.path).toLowerCase();
        final icon = ['.exe', '.lnk', '.url', '.appref-ms'].contains(ext)
            ? Icons.apps
            : Icons.insert_drive_file;
        return Icon(icon, size: 32);
      },
    );
  }

  Future<Uint8List?> _resolveIconBytes() async {
    final ext = path.extension(entity.path).toLowerCase();
    final primary = extractIcon(entity.path);
    if (primary != null) {
      return primary;
    }
    if (ext == '.lnk') {
      final target = getShortcutTarget(entity.path);
      if (target != null && target.isNotEmpty) {
        final targetIcon = extractIcon(target);
        if (targetIcon != null) {
          return targetIcon;
        }
      }
    }
    return null;
  }
}
