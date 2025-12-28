import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../utils/desktop_helper.dart';

/// Show a simple folder picker dialog starting at [initialPath].
/// Returns the chosen folder path or null if cancelled.
Future<String?> showFolderPicker({
  required BuildContext context,
  required String initialPath,
  bool showHidden = false,
}) async {
  var currentPath = _resolveStart(initialPath);
  var entries = _listDirs(currentPath, showHidden: showHidden);

  return showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          void changePath(String next) {
            final resolved = _resolveStart(next);
            setState(() {
              currentPath = resolved;
              entries = _listDirs(resolved, showHidden: showHidden);
            });
          }

          return AlertDialog(
            title: const Text('选择文件夹'),
            content: SizedBox(
              width: 420,
              height: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          final parent = path.dirname(currentPath);
                          if (parent != currentPath) {
                            changePath(parent);
                          }
                        },
                      ),
                      Expanded(
                        child: Text(
                          currentPath,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => changePath(currentPath),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: entries.isEmpty
                        ? const Center(child: Text('无子文件夹'))
                        : ListView.builder(
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final dir = entries[index];
                              return ListTile(
                                leading: const Icon(Icons.folder),
                                title: Text(path.basename(dir.path)),
                                subtitle: Text(dir.path),
                                onTap: () => changePath(dir.path),
                                onLongPress: () => changePath(dir.path),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(currentPath),
                child: const Text('选择此文件夹'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _resolveStart(String pathStr) {
  final dir = Directory(pathStr);
  if (dir.existsSync()) return dir.path;
  final parent = path.dirname(pathStr);
  return parent == pathStr ? Directory.current.path : _resolveStart(parent);
}

List<Directory> _listDirs(String root, {required bool showHidden}) {
  final dir = Directory(root);
  if (!dir.existsSync()) return [];
  final entries = dir.listSync().whereType<Directory>().where((d) {
    final name = path.basename(d.path);
    if (!showHidden &&
        (name.startsWith('.') || isHiddenOrSystem(d.path))) {
      return false;
    }
    final lower = name.toLowerCase();
    if (lower == 'desktop.ini' || lower == 'thumbs.db') return false;
    return true;
  }).toList();
  entries.sort((a, b) => path.basename(a.path).toLowerCase().compareTo(
        path.basename(b.path).toLowerCase(),
      ));
  return entries;
}
