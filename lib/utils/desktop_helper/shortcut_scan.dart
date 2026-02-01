part of '../desktop_helper.dart';

const int SLR_NO_UI = 0x0001;
const int SLGP_SHORTPATH = 0x0001;
const int SLGP_UNCPRIORITY = 0x0002;
const int SLGP_RAWPATH = 0x0004;

String? getShortcutTarget(String lnkPath) {
  try {
    final shellLink = ShellLink.createInstance();
    final persistFile = IPersistFile.from(shellLink);

    final lnkPtr = lnkPath.toNativeUtf16();
    final loadHr = persistFile.load(lnkPtr.cast(), STGM_READ);
    calloc.free(lnkPtr);

    if (loadHr != S_OK) {
      shellLink.release();
      return null;
    }

    shellLink.resolve(0, SLR_NO_UI);

    final pathBuffer = calloc.allocate<Utf16>(MAX_PATH);
    final hr = shellLink.getPath(pathBuffer, MAX_PATH, nullptr, SLGP_RAWPATH);

    String? target;
    if (hr == S_OK) {
      target = pathBuffer.toDartString();
    }

    calloc.free(pathBuffer);
    shellLink.release();
    return target;
  } catch (e) {
    print('解析快捷方式失败: $e');
    return null;
  }
}

Future<List<String>> scanDesktopShortcuts(
  String desktopPath, {
  bool showHidden = false,
}) async {
  final locations = _desktopLocations(desktopPath);
  final shortcuts = <String>{};

  for (final dirPath in locations) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      final found = await scanDirectoryShortcuts(
        dirPath,
        showHidden: showHidden,
        recursive: false,
      );
      shortcuts.addAll(found);
    } catch (_) {}
  }

  return shortcuts.toList();
}

Future<List<String>> scanDirectoryShortcuts(
  String dirPath, {
  bool showHidden = false,
  bool recursive = false,
  Set<String>? visited,
}) async {
  final results = <String>[];
  final visitedDirs = visited ?? <String>{};

  // Basic cycle detection for recursion
  if (visitedDirs.contains(dirPath)) return results;
  visitedDirs.add(dirPath);

  const allowedExtensions = {'.exe', '.lnk', '.url', '.appref-ms'};

  try {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return results;

    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      final name = path.basename(entity.path);
      final lowerName = name.toLowerCase();

      // Filter hidden/system if needed
      if (!showHidden &&
          (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
        continue;
      }

      if (lowerName == 'desktop.ini' || lowerName == 'thumbs.db') {
        continue;
      }

      final type = FileSystemEntity.typeSync(entity.path);

      if (type == FileSystemEntityType.file) {
        final ext = path.extension(lowerName);
        // Only add if it's an executable or shortcut
        if (allowedExtensions.contains(ext)) {
          results.add(entity.path);
        }
      } else if (recursive && type == FileSystemEntityType.directory) {
        // Recursive scan
        final subResults = await scanDirectoryShortcuts(
          entity.path,
          showHidden: showHidden,
          recursive: true,
          visited: visitedDirs,
        );
        results.addAll(subResults);
      }
    }
  } catch (e) {
    // Ignore access errors etc.
    // print('Scan failed for $dirPath: $e');
  }

  return results;
}
