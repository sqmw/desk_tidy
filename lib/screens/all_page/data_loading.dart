part of '../all_page.dart';

extension _AllPageDataLoading on _AllPageState {
  Future<void> _refresh() async {
    if (_renameOverlay.isActive) _renameOverlay.hide();
    _setState(() {
      _loading = true;
      _error = null;
    });
    _iconFutures.clear();
    try {
      if (_currentPath == null) {
        final items = _loadAggregateRoots();
        _setState(() {
          _items = items;
          _loading = false;
        });
      } else {
        final dir = Directory(_currentPath!);
        if (!dir.existsSync()) {
          _setState(() {
            _items = [];
            _error = '路径不存在';
            _loading = false;
          });
          return;
        }

        final showHidden = widget.showHidden;
        final rawEntries = dir.listSync().where((entity) {
          final name = path.basename(entity.path);
          final lower = name.toLowerCase();
          if (!showHidden &&
              (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
            return false;
          }
          if (lower == 'desktop.ini' || lower == 'thumbs.db') return false;
          return true;
        });

        final items = rawEntries.map((e) => FileItem.fromEntity(e)).toList();

        _setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      _setState(() {
        _error = '加载失败: $e';
        _items = [];
        _loading = false;
      });
    }
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
    while (_iconFutures.length > _AllPageState._iconFutureCacheCapacity) {
      _iconFutures.remove(_iconFutures.keys.first);
    }
    return created;
  }

  List<FileItem> _loadAggregateRoots() {
    final directories = desktopLocations(widget.desktopPath);
    final seen = <String>{};
    final items = <FileItem>[];

    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync()) {
        if (!seen.add(entity.path)) continue;
        final name = path.basename(entity.path);
        if (!widget.showHidden &&
            (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
          continue;
        }
        final lower = name.toLowerCase();
        if (lower == 'desktop.ini' || lower == 'thumbs.db') continue;

        items.add(FileItem.fromEntity(entity));
      }
    }
    return items;
  }
}
