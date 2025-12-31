import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../utils/desktop_helper.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/middle_ellipsis_text.dart';

class FilePage extends StatelessWidget {
  final String desktopPath;
  final bool showHidden;

  const FilePage({
    Key? key,
    required this.desktopPath,
    this.showHidden = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final desktopDir = Directory(desktopPath);
    final files = desktopDir
        .listSync()
        .where((entity) {
          if (entity is! File) return false;
          final name = path.basename(entity.path);
          final lower = name.toLowerCase();

          if (!showHidden &&
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

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            onDoubleTap: () async {
              await openWithDefault(file.path);
            },
            onSecondaryTapDown: (details) {
              _showFileMenu(context, file, details.globalPosition);
            },
            borderRadius: BorderRadius.circular(8),
            hoverColor:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: _FileIcon(filePath: file.path),
              title: Tooltip(
                message: path.basename(file.path),
                child: Text(
                  path.basename(file.path),
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              subtitle: Tooltip(
                message: file.path,
                child: MiddleEllipsisText(
                  text: file.path,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
  const _FileIcon({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _resolveIcon(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null && data.isNotEmpty) {
          return Image.memory(
            data,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
          );
        }
        final ext = path.extension(filePath).toLowerCase();
        final icon = ['.exe', '.lnk', '.url', '.appref-ms'].contains(ext)
            ? Icons.apps
            : Icons.insert_drive_file;
        return Icon(icon, size: 28);
      },
    );
  }

  Future<Uint8List?> _resolveIcon() async {
    final ext = path.extension(filePath).toLowerCase();
    final primary = extractIcon(filePath);
    if (primary != null) {
      return primary;
    }
    if (ext == '.lnk') {
      final target = getShortcutTarget(filePath);
      if (target != null && target.isNotEmpty) {
        final targetIcon = extractIcon(target);
        if (targetIcon != null) return targetIcon;
      }
    }
    return null;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $label')),
    );
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
        value: 'move',
        child: ListTile(
          leading: Icon(Icons.drive_file_move),
          title: Text('移动到...'),
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
      await openWithDefault(file.path);
      break;
    case 'open_with':
      await _promptOpenWith(file.path);
      break;
    case 'move':
      await _promptMoveFile(context, file);
      break;
    case 'delete':
      final ok = moveToRecycleBin(file.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '已移动到回收站' : '删除失败')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目标已存在同名文件')),
        );
      }
      return;
    }
    await file.rename(dest);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移动到 $dest')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移动失败: $e')),
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
