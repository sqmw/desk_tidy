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
  final List<String> startMenuPaths;
  final bool showHidden;

  _ScanRequest({
    required this.desktopPaths,
    required this.startMenuPaths,
    required this.showHidden,
  });
}

// Top-level function for compute
Future<List<String>> _scanPathsInIsolate(_ScanRequest req) async {
  // Initialize COM for this Isolate
  final hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr)) {
    // Proceed best effort
  }

  final results = <String>[];

  bool isJunk(String name) {
    final lower = name.toLowerCase();
    const keywords = [
      'uninstall',
      'uninst',
      'setup',
      'install',
      'config',
      'update',
      'readme',
      'help',
      'visit',
      'website',
      'homepage',
      '卸载',
      '安装',
      '设置',
      '帮助',
      '说明',
      '关于',
    ];
    for (final k in keywords) if (lower.contains(k)) return true;
    return false;
  }

  const allowedExtensions = {'.exe', '.lnk', '.url', '.appref-ms'};

  Future<void> scanDir(Directory dir, {bool checkUrlTargets = false}) async {
    try {
      if (!dir.existsSync()) return;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        try {
          final name = path.basename(entity.path);
          if (!req.showHidden && (name.startsWith('.'))) continue;

          final lowerName = name.toLowerCase();
          if (lowerName == 'desktop.ini' || lowerName == 'thumbs.db') continue;
          if (lowerName.endsWith('.url')) continue; // Always skip .url FILES
          if (isJunk(name)) continue;

          if (entity is File) {
            final ext = path.extension(lowerName);
            if (allowedExtensions.contains(ext)) {
              // Deep check for .lnk pointing to .url (Only for Start Menu)
              if (checkUrlTargets && lowerName.endsWith('.lnk')) {
                final target = getShortcutTarget(entity.path);
                if (target != null && target.toLowerCase().endsWith('.url')) {
                  continue; // Skip this shortcut
                }
              }
              results.add(entity.path);
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  // Scan Desktop (No deep filter)
  for (final dirPath in req.desktopPaths) {
    if (dirPath.isNotEmpty)
      await scanDir(Directory(dirPath), checkUrlTargets: false);
  }

  // Scan Start Menu (With deep filter)
  for (final dirPath in req.startMenuPaths) {
    if (dirPath.isNotEmpty)
      await scanDir(Directory(dirPath), checkUrlTargets: true);
  }

  // Uninitialize COM
  CoUninitialize();

  return results;
}
