import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class FilePage extends StatelessWidget {
  final String desktopPath;

  const FilePage({Key? key, required this.desktopPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final desktopDir = Directory(desktopPath);
    final files = desktopDir
        .listSync()
        .where((entity) =>
    entity is File &&
        !entity.path.toLowerCase().endsWith('.lnk') &&
        !entity.path.toLowerCase().endsWith('.exe'))
        .map((e) => e as File)
        .toList();

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
