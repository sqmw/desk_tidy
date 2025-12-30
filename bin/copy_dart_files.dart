// bin/copy_dart_files.dart
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main() async {
  final root = Directory.current.path;
  final libDir = Directory(p.join(root, 'lib'));
  final targetDir = Directory(p.join(root, 'code_lib', 'lib_all'));

  if (!await libDir.exists()) {
    print('错误：lib 目录不存在 → $libDir');
    exit(1);
  }

  await targetDir.create(recursive: true);
  print('目标目录：${targetDir.path}');
  print('开始扫描并复制所有 .dart 文件（平铺）...\n');

  int count = 0;
  final stopwatch = Stopwatch()..start();

  // 先收集所有 dart 文件路径（内存占用可接受）
  final dartFiles = <File>[];

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && p.extension(entity.path).toLowerCase() == '.dart') {
      dartFiles.add(entity);
    }
  }

  print('找到 ${dartFiles.length} 个 .dart 文件，开始复制...');

  // 批量并发复制（通常比逐个 await 快）
  await Future.wait(
    dartFiles.map((file) async {
      final name = p.basename(file.path);
      final destPath = p.join(targetDir.path, name);
      await file.copy(destPath);
      count++;
      // 可选：显示进度
      // if (count % 50 == 0) print('$count...');
    }),
    eagerError: true, // 任意一个出错就立即停止
  );

  stopwatch.stop();

  print('\n完成！');
  print('总共复制 $count 个文件');
  print(
      '耗时：${stopwatch.elapsedMilliseconds} ms (${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)} 秒)');
  print('目标目录：${targetDir.path}');
  print('（同名文件已被直接覆盖）');
}
