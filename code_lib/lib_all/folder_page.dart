import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class FolderPage extends StatelessWidget {
  final String desktopPath;

  const FolderPage({Key? key, required this.desktopPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final desktopDir = Directory(desktopPath);
    final folders = desktopDir
        .listSync()
        .whereType<Directory>()
        .toList();

    if (folders.isEmpty) {
      return const Center(child: Text('未找到文件夹'));
    }

    return ListView.builder(
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(path.basename(folder.path)),
          subtitle: Text(folder.path),
        );
      },
    );
  }
}
