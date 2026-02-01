part of '../folder_page.dart';

extension _FolderPageNavigation on _FolderPageState {
  void _openFolder(String folderPath) {
    _currentPath = folderPath;
    _selectedPath = null;
    _refresh();
  }

  void _goUp() {
    final parent = path.dirname(_currentPath);
    if (parent == _currentPath) return;
    _currentPath = parent;
    _selectedPath = null;
    _refresh();
  }
}
