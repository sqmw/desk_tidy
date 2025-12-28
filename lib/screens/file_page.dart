import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../utils/desktop_helper.dart';

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
    final files = desktopDir.listSync().where((entity) {
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
    }).map((e) => e as File).toList();

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
            onSecondaryTapDown: (_) {},
            borderRadius: BorderRadius.circular(8),
            hoverColor: Theme.of(context)
                .colorScheme
                .surfaceVariant
                .withOpacity(0.4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: _FileIcon(filePath: file.path),
              title: Text(path.basename(file.path)),
              subtitle: Text(file.path),
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
    if (ext == '.lnk') {
      final target = getShortcutTarget(filePath);
      if (target != null && target.isNotEmpty) {
        final preferred = extractIcon(target);
        if (preferred != null) return preferred;
      }
    }
    return extractIcon(filePath);
  }
}
