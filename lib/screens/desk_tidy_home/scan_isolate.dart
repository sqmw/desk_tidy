part of '../desk_tidy_home_page.dart';

class _LayoutMetrics {
  final double cardHeight;
  final double mainAxisSpacing;
  final double horizontalPadding;

  const _LayoutMetrics({
    required this.cardHeight,
    required this.mainAxisSpacing,
    required this.horizontalPadding,
  });
}

class _ScanRequest {
  final List<String> desktopPaths;
  final List<String> desktopShortcutPaths;
  final List<String> startMenuPaths;
  final bool showHidden;

  _ScanRequest({
    required this.desktopPaths,
    required this.desktopShortcutPaths,
    required this.startMenuPaths,
    required this.showHidden,
  });
}

// Top-level function for compute
Future<List<Map<String, String>>> _scanPathsInIsolate(_ScanRequest req) async {
  // Initialize COM for this Isolate
  final hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr)) {
    // Proceed best effort
  }

  final results = <Map<String, String>>[];

  bool isJunk(String name) {
    final lower = name.toLowerCase();

    bool isAsciiAlphaNum(int c) =>
        (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122);

    bool containsWord(String text, String word) {
      var start = 0;
      while (true) {
        final idx = text.indexOf(word, start);
        if (idx < 0) return false;
        final beforeOk = idx == 0 || !isAsciiAlphaNum(text.codeUnitAt(idx - 1));
        final afterIdx = idx + word.length;
        final afterOk =
            afterIdx >= text.length ||
            !isAsciiAlphaNum(text.codeUnitAt(afterIdx));
        if (beforeOk && afterOk) return true;
        start = idx + 1;
      }
    }

    const asciiWords = <String>[
      'uninstall',
      'uninst',
      'setup',
      'config',
      'update',
      'readme',
      'help',
      'visit',
      'website',
      'homepage',
    ];

    const cjkKeywords = <String>['卸载', '安装', '设置', '帮助', '说明', '关于'];

    for (final word in asciiWords) {
      if (containsWord(lower, word)) return true;
    }
    for (final k in cjkKeywords) {
      if (lower.contains(k)) return true;
    }
    return false;
  }

  // NOTE:
  // - Keep this list small; Start Menu scanning can be huge on some machines.
  // - `.url` is intentionally excluded (we always skip it below).
  const allowedExtensions = {'.exe', '.lnk', '.appref-ms'};

  void addResult({
    required String source,
    required String shortcutPath,
    required String targetPath,
  }) {
    results.add(<String, String>{
      'src': source,
      'path': shortcutPath,
      'target': targetPath,
    });
  }

  Future<void> scanDir(
    Directory dir, {
    required String source,
    required bool recursive,
    required bool resolveLnkTargets,
  }) async {
    try {
      if (!dir.existsSync()) return;
      await for (final entity in dir.list(
        recursive: recursive,
        followLinks: false,
      )) {
        try {
          final name = path.basename(entity.path);
          if (!req.showHidden && (name.startsWith('.'))) continue;

          final lowerName = name.toLowerCase();
          if (lowerName == 'desktop.ini' || lowerName == 'thumbs.db') continue;
          if (lowerName.endsWith('.url')) continue; // Always skip .url files
          if (isJunk(name)) continue;

          if (entity is File) {
            final ext = path.extension(lowerName);
            if (allowedExtensions.contains(ext)) {
              var targetPath = entity.path;
              if (ext == '.lnk' && resolveLnkTargets) {
                final resolved = getShortcutTarget(entity.path);
                if (resolved != null && resolved.trim().isNotEmpty) {
                  if (resolved.toLowerCase().endsWith('.url')) {
                    continue;
                  }
                  // Don't treat folder shortcuts as "apps".
                  if (Directory(resolved).existsSync()) {
                    continue;
                  }
                  targetPath = resolved;
                }
              }

              addResult(
                source: source,
                shortcutPath: entity.path,
                targetPath: targetPath,
              );
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  // Scan explicit desktop shortcut paths (already known file paths)
  for (final filePath in req.desktopShortcutPaths) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.url')) continue;
    final ext = path.extension(lower);
    if (!allowedExtensions.contains(ext)) continue;
    if (!File(filePath).existsSync()) continue;

    var targetPath = filePath;
    if (ext == '.lnk') {
      final resolved = getShortcutTarget(filePath);
      if (resolved != null && resolved.trim().isNotEmpty) {
        if (Directory(resolved).existsSync()) {
          continue;
        }
        targetPath = resolved;
      }
    }

    addResult(
      source: 'desktop',
      shortcutPath: filePath,
      targetPath: targetPath,
    );
  }

  // Scan Desktop roots (non-recursive for responsiveness; matches prior behavior)
  for (final dirPath in req.desktopPaths) {
    if (dirPath.isEmpty) continue;
    await scanDir(
      Directory(dirPath),
      source: 'desktop',
      recursive: false,
      resolveLnkTargets: true,
    );
  }

  // Scan Start Menu (recursive). Resolve .lnk targets here so we can de-dup by
  // target path without blocking the UI isolate.
  for (final dirPath in req.startMenuPaths) {
    if (dirPath.isEmpty) continue;
    await scanDir(
      Directory(dirPath),
      source: 'start_menu',
      recursive: true,
      resolveLnkTargets: true,
    );
  }

  // Uninitialize COM
  CoUninitialize();

  return results;
}
