import 'dart:io';
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
        return ListTile(
          leading: const Icon(Icons.insert_drive_file),
          title: Text(path.basename(file.path)),
          subtitle: Text(file.path),
        );
      },
    );
  }
}
