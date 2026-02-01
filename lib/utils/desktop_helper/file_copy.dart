part of '../desktop_helper.dart';

class CopyResult {
  final bool success;
  final String? message;
  final String? destPath;

  const CopyResult({required this.success, this.message, this.destPath});
}

Future<CopyResult> copyEntityToDirectory(
  String sourcePath,
  String targetDirectory,
) async {
  try {
    if (targetDirectory.trim().isEmpty) {
      return const CopyResult(success: false, message: '目标路径为空');
    }
    final destDir = Directory(targetDirectory);
    if (!destDir.existsSync()) {
      return const CopyResult(success: false, message: '目标不存在');
    }

    final baseName = path.basename(sourcePath);
    var destPath = path.join(destDir.path, baseName);
    final normalizedSource = path.normalize(sourcePath);

    // Generate unique name if destination exists
    if (File(destPath).existsSync() || Directory(destPath).existsSync()) {
      final ext = path.extension(baseName);
      final nameWithoutExt = path.basenameWithoutExtension(baseName);
      int count = 1;
      while (true) {
        final newName = '$nameWithoutExt ($count)$ext';
        destPath = path.join(destDir.path, newName);
        if (!File(destPath).existsSync() && !Directory(destPath).existsSync()) {
          break;
        }
        count++;
        if (count > 1000) {
          return const CopyResult(success: false, message: '无法生成唯一文件名');
        }
      }
    }

    final normalizedDest = path.normalize(destPath);
    if (normalizedSource == normalizedDest) {
      return const CopyResult(success: false, message: '目标与源相同');
    }
    if (path.isWithin(normalizedSource, normalizedDest)) {
      return const CopyResult(success: false, message: '目标在源目录内部');
    }

    final type = FileSystemEntity.typeSync(sourcePath, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await _copyDirectoryRecursive(Directory(sourcePath), Directory(destPath));
    } else if (type == FileSystemEntityType.file) {
      await File(sourcePath).copy(destPath);
    } else {
      return const CopyResult(success: false, message: '源不存在');
    }

    return CopyResult(success: true, destPath: destPath);
  } catch (e) {
    return CopyResult(success: false, message: e.toString());
  }
}

Future<void> _copyDirectoryRecursive(
  Directory source,
  Directory destination,
) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final name = path.basename(entity.path);
    final destPath = path.join(destination.path, name);
    if (entity is Directory) {
      await _copyDirectoryRecursive(entity, Directory(destPath));
    } else if (entity is File) {
      await entity.copy(destPath);
    } else if (entity is Link) {
      final target = await entity.target();
      await Link(destPath).create(target);
    }
  }
}
