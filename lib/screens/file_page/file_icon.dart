part of '../file_page.dart';

class _FileIcon extends StatelessWidget {
  final String filePath;
  final bool beautifyIcon;
  final IconBeautifyStyle beautifyStyle;
  final double size;
  const _FileIcon({
    required this.filePath,
    required this.beautifyIcon,
    required this.beautifyStyle,
    this.size = 28,
  });

  // FilePage may browse a large number of file paths. Keep this bounded to avoid
  // unbounded memory growth in debug sessions.
  static const int _iconFutureCacheCapacity = 512;
  static final LinkedHashMap<String, Future<Uint8List?>> _iconFutures =
      LinkedHashMap<String, Future<Uint8List?>>();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _resolveIcon(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null && data.isNotEmpty) {
          return BeautifiedIcon(
            bytes: data,
            fallback: Icons.apps,
            size: size,
            enabled: beautifyIcon,
            style: beautifyStyle,
            fit: BoxFit.contain,
          );
        }
        final ext = path.extension(filePath).toLowerCase();
        final icon = ['.exe', '.lnk', '.url', '.appref-ms'].contains(ext)
            ? Icons.apps
            : Icons.insert_drive_file;
        return BeautifiedIcon(
          bytes: null,
          fallback: icon,
          size: size,
          enabled: beautifyIcon,
          style: beautifyStyle,
        );
      },
    );
  }

  Future<Uint8List?> _resolveIcon() async {
    final ext = path.extension(filePath).toLowerCase();
    final primary = await _getIconFuture(filePath);
    if (primary != null && primary.isNotEmpty) return primary;
    if (ext == '.lnk') {
      final target = getShortcutTarget(filePath);
      if (target != null && target.isNotEmpty) {
        final targetIcon = await _getIconFuture(target);
        if (targetIcon != null && targetIcon.isNotEmpty) return targetIcon;
      }
    }
    return null;
  }

  Future<Uint8List?> _getIconFuture(String path) {
    final key = path.toLowerCase();
    final existing = _iconFutures.remove(key);
    if (existing != null) {
      _iconFutures[key] = existing; // refresh LRU order
      return existing;
    }

    final created = extractIconAsync(path, size: 96);
    _iconFutures[key] = created;
    while (_iconFutures.length > _iconFutureCacheCapacity) {
      _iconFutures.remove(_iconFutures.keys.first);
    }
    return created;
  }
}
