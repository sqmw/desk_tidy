import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../utils/desktop_helper.dart';

class AllPage extends StatelessWidget {
  final String desktopPath;
  final bool showHidden;

  const AllPage({
    super.key,
    required this.desktopPath,
    this.showHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final directories = desktopLocations(desktopPath);
    final seen = <String>{};
    final entries = <FileSystemEntity>[];

    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync()) {
        if (!seen.add(entity.path)) continue;
        final name = path.basename(entity.path);
        final lower = name.toLowerCase();

        if (!showHidden &&
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

    if (entries.isEmpty) {
      return const Center(child: Text('未找到文件或快捷方式'));
    }

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entity = entries[index];
        final name = path.basename(entity.path);

        return ListTile(
          leading: _EntityIcon(entity: entity),
          title: Text(name),
          subtitle: Text(entity.path),
        );
      },
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
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
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
    if (ext == '.lnk') {
      final target = getShortcutTarget(entity.path);
      if (target != null && target.isNotEmpty) {
        final preferred = extractIcon(target);
        if (preferred != null) {
          return preferred;
        }
      }
    }

    return extractIcon(entity.path);
  }
}
