part of '../folder_page.dart';

extension _FolderPageDataLoading on _FolderPageState {
  Future<void> _refresh() async {
    _setState(() {
      _loading = true;
      _error = null;
    });
    _iconFutures.clear();
    try {
      final dir = Directory(_currentPath);
      if (!dir.existsSync()) {
        _setState(() {
          _entries = [];
          _error = '路径不存在';
          _loading = false;
        });
        return;
      }
      final allowFiles = !_isRootPath;
      final showHidden = widget.showHidden;
      final entries =
          dir.listSync().where((entity) {
            if (!allowFiles && entity is! Directory) return false;
            final name = path.basename(entity.path);
            if (!showHidden &&
                (name.startsWith('.') || isHiddenOrSystem(entity.path)))
              return false;
            final lower = name.toLowerCase();
            if (lower == 'desktop.ini' || lower == 'thumbs.db') return false;
            return allowFiles ? true : entity is Directory;
          }).toList()..sort((a, b) {
            final aIsDir = a is Directory;
            final bIsDir = b is Directory;
            if (aIsDir && !bIsDir) return -1;
            if (!aIsDir && bIsDir) return 1;
            return path
                .basename(a.path)
                .toLowerCase()
                .compareTo(path.basename(b.path).toLowerCase());
          });
      _setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _setState(() {
        _error = '加载失败: $e';
        _entries = [];
        _loading = false;
      });
    }
  }

  Future<Uint8List?> _getIconFuture(String path) {
    final key = path.toLowerCase();
    return _iconFutures.putIfAbsent(
      key,
      () => extractIconAsync(path, size: 96),
    );
  }
}
