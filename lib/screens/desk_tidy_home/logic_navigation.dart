part of '../desk_tidy_home_page.dart';

extension _DeskTidyHomeNavigationLogic on _DeskTidyHomePageState {
  void _onNavigationRailItemSelected(int index) {
    if (_isEditingCategory) {
      _cancelInlineCategoryEdit(save: false);
    }
    _setState(() => _selectedIndex = index);
    if (index == 0) {
      _loadShortcuts(showLoading: false);
    } else {
      _cancelShortcutLoad();
    }
    _setupAutoRefresh();
  }

  void _cancelShortcutLoad() {
    _shortcutLoadToken++;
  }

  void _onNavigationRailPointer(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons == kSecondaryMouseButton &&
        _selectedIndex != 1) {
      final pos = event.position;
      Future.microtask(() {
        if (!mounted) return;
        _showHiddenMenu(pos);
      });
    }
  }

  Future<void> _showHiddenMenu(Offset globalPosition) async {
    const menuItemValue = 0;
    final label = _showHidden ? '隐藏隐藏文件/文件夹' : '显示隐藏文件/文件夹';
    final icon = _showHidden ? Icons.visibility_off : Icons.visibility;

    final result = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: menuItemValue,
          child: ListTile(
            leading: Icon(icon),
            title: Text(label),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );

    if (result == menuItemValue) {
      _setState(() => _showHidden = !_showHidden);
      _loadShortcuts();
    }
  }
}
