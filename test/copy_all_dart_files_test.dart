import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('把 lib 目录下所有 .dart 文件平铺复制到 code_lib/lib_all', () async {
    // 项目根目录
    final projectRoot = Directory.current;

    // 源目录：lib
    final libDir = Directory(path.join(projectRoot.path, 'lib'));

    // 目标目录：code_lib/lib_all
    final targetDir = Directory(path.join(projectRoot.path, 'code_lib', 'lib_all'));

    // 创建目标目录（如果不存在）
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
      print('已创建目标目录: ${targetDir.path}');
    }

    if (!await libDir.exists()) {
      fail('lib 目录不存在: ${libDir.path}');
    }

    int copiedCount = 0;
    final seenNames = <String>{}; // 可选：记录已见过的文件名，用于提示重名

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is File && path.extension(entity.path).toLowerCase() == '.dart') {
        final fileName = path.basename(entity.path);
        final destinationPath = path.join(targetDir.path, fileName);
        final destinationFile = File(destinationPath);

        // 可选：检查是否重名
        if (await destinationFile.exists()) {
          print('警告：文件已存在，将覆盖 → $fileName');
          // 如果不想覆盖可以在这里 continue 或改名
          // continue;
        }

        // 执行复制
        await entity.copy(destinationPath);
        print('已复制: $fileName');

        copiedCount++;
      }
    }

    print('──────────────────────────────');
    print('复制完成！共处理 $copiedCount 个 .dart 文件');
    print('全部平铺保存至: ${targetDir.path}');
    print('（同名文件已被覆盖）');
  });
}