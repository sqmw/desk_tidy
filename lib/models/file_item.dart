import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/app_search_index.dart';

class FileItem {
  final FileSystemEntity entity;
  final String name;
  final String extension;
  final bool isDirectory;
  final DateTime modified;
  final int size;

  AppSearchIndex? _searchIndex;

  FileItem({
    required this.entity,
    required this.name,
    required this.extension,
    required this.isDirectory,
    required this.modified,
    required this.size,
  });

  /// 懒加载搜索索引
  AppSearchIndex get searchIndex {
    _searchIndex ??= AppSearchIndex.fromName(name);
    return _searchIndex!;
  }

  /// 从 FileSystemEntity 创建 FileItem
  /// 注意：会同步调用 stat()，可能会有轻微性能影响
  factory FileItem.fromEntity(FileSystemEntity entity) {
    final stat = entity.statSync();
    final name = path.basename(entity.path);
    final isDir = entity is Directory;

    return FileItem(
      entity: entity,
      name: name,
      extension: isDir ? '' : path.extension(name).toLowerCase(),
      isDirectory: isDir,
      modified: stat.modified,
      size: stat.size,
    );
  }

  String get pathStr => entity.path;
}
