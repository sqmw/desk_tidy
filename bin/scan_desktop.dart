import 'dart:io';
import 'package:path/path.dart' as path;

Future<void> main() async {
  final desktopPath = _resolveDesktopPath();
  if (desktopPath == null) {
    stderr.writeln('无法找到桌面路径，请确认环境变量是否设置。');
    exit(1);
  }

  stdout.writeln('桌面路径: $desktopPath');

  final desktopDir = Directory(desktopPath);
  if (!await desktopDir.exists()) {
    stderr.writeln('桌面目录不存在: $desktopPath');
    exit(2);
  }

  final entries = await desktopDir.list(followLinks: false).toList();
  if (entries.isEmpty) {
    stdout.writeln('桌面为空。');
    return;
  }

  print(entries);

  final filtered = entries.where((entity) {
    final basen = path.basename(entity.path).toLowerCase();
    if (basen == 'desktop.ini' || basen == 'thumbs.db') return false;
    if (basen.startsWith('.')) return false;
    return true;
  }).toList()
    ..sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));

  stdout.writeln('共计 ${filtered.length} 条文件/快捷方式');

  for (final entity in filtered) {
    final name = path.basename(entity.path);
    final metadata = await entity.stat();
    final type = metadata.type == FileSystemEntityType.directory
        ? '目录'
        : '文件';
    final size = metadata.size;
    final modified = metadata.modified.toIso8601String();
    stdout.writeln('$name | $type | $size bytes | 修改: $modified');
  }
}

String? _resolveDesktopPath() {
  final env = Platform.environment;
  final userProfile = env['USERPROFILE'] ?? env['HOME'];
  if (userProfile != null && userProfile.isNotEmpty) {
    final candidate = path.join(userProfile, 'Desktop');
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
  }
  return env['DESKTOP'] ?? (Platform.isWindows ? r'C:\Users\Public\Desktop' : null);
}
