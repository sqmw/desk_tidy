part of '../file_page.dart';

extension _FilePageDataLoading on _FilePageState {
  void _refresh() {
    final desktopDir = Directory(widget.desktopPath);
    if (!desktopDir.existsSync()) {
      _setState(() => _files = []);
      return;
    }

    final files =
        desktopDir
            .listSync()
            .where((entity) {
              if (entity is! File) return false;
              final name = path.basename(entity.path);
              if (!widget.showHidden &&
                  (name.startsWith('.') || isHiddenOrSystem(entity.path)))
                return false;
              final lower = name.toLowerCase();
              if (lower == 'desktop.ini' || lower == 'thumbs.db') return false;
              return !lower.endsWith('.lnk') && !lower.endsWith('.exe');
            })
            .map((e) => e as File)
            .toList()
          ..sort(
            (a, b) => path
                .basename(a.path)
                .toLowerCase()
                .compareTo(path.basename(b.path).toLowerCase()),
          );

    _setState(() => _files = files);
  }
}
