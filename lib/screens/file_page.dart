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

  // Custom double-tap state
  int _lastTapTime = 0;
  String _lastTappedPath = '';

  @override
  Widget build(BuildContext context) {
    final desktopDir = Directory(widget.desktopPath);
    if (!desktopDir.existsSync()) {
      return const Center(child: Text('路径不存在'));
    }

    final files = desktopDir
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
        .toList();

    if (files.isEmpty) {
      return const Center(child: Text('未找到文件'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 100,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final name = path.basename(file.path);
        final isSelected = file.path == _selectedPath;

        return Material(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          child: InkWell(
            onTapDown: (_) => setState(() => _selectedPath = file.path),
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          height: 1.2,
                          fontSize: 11,
                        ),
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
    );
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

Future<void> _showFileMenu(
  BuildContext context,
  File file,
  Offset position,
) async {
  Future<void> copyToClipboard(
    String raw, {
    required String label,
    required bool quoted,
  }) async {
    final value = quoted ? '"${raw.replaceAll('"', '\\"')}"' : raw;
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied $label')));
  }

  final displayName = path.basename(file.path);
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
        child: ListTile(leading: Icon(Icons.open_in_new), title: Text('打开')),
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
        child: ListTile(leading: Icon(Icons.copy), title: Text('复制到...')),
      ),
      PopupMenuItem(
        value: 'copy_clipboard',
        child: ListTile(leading: Icon(Icons.copy), title: Text('复制到剪贴板(系统)')),
      ),
      PopupMenuItem(
        value: 'delete',
        child: ListTile(leading: Icon(Icons.delete), title: Text('删除(回收站)')),
      ),
      PopupMenuDivider(),
      PopupMenuItem(
        value: 'copy_name',
        child: ListTile(leading: Icon(Icons.copy), title: Text('复制名称')),
      ),
      PopupMenuItem(
        value: 'copy_path',
        child: ListTile(leading: Icon(Icons.link), title: Text('复制路径')),
      ),
      PopupMenuItem(
        value: 'copy_folder',
        child: ListTile(leading: Icon(Icons.folder), title: Text('复制所在文件夹')),
      ),
    ],
  );

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
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ok ? '已复制到剪贴板' : '复制到剪贴板失败')));
      }
      break;
    case 'delete':
      final ok = moveToRecycleBin(file.path);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ok ? '已移动到回收站' : '删除失败')));
      }
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
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('目标已存在同名文件')));
      }
      return;
    }
    await file.rename(dest);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已移动到 $dest')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('移动失败: $e')));
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
  if (context.mounted) {
    if (result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已复制到 ${result.destPath}')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('复制失败: ${result.message ?? 'unknown'}')),
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
