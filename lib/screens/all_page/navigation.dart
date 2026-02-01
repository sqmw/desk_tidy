part of '../all_page.dart';

extension _AllPageNavigation on _AllPageState {
  void _openFolder(String folderPath) {
    _currentPath = folderPath;
    _refresh();
  }

  void _goUp() {
    if (_currentPath == null) return;
    final parent = path.dirname(_currentPath!);
    if (parent == _currentPath) {
      _currentPath = null;
    } else {
      _currentPath = parent;
    }
    _refresh();
  }

  void _goHome() {
    _currentPath = null;
    _refresh();
  }
}
