part of '../../desk_tidy_home_page.dart';

extension _DeskTidyHomeCategoryMenu on _DeskTidyHomePageState {
  Future<void> _showCategoryMenuForShortcut(
    ShortcutItem shortcut,
    Offset position,
  ) async {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'new',
        child: ListTile(leading: Icon(Icons.add), title: Text('新建分类')),
      ),
    ];
    if (_categories.isNotEmpty) {
      items.add(const PopupMenuDivider());
      items.addAll(
        _categories.map((c) {
          final selected = c.paths.contains(shortcut.path);
          return PopupMenuItem(
            value: c.id,
            child: ListTile(
              leading: Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
              ),
              title: Text(c.name),
            ),
          );
        }),
      );
    }

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: items,
    );

    if (result == null) return;

    if (result == 'new') {
      final name = await _promptCategoryName();
      if (name == null) return;
      final created = await _createCategory(name, initialShortcut: shortcut);
      if (!mounted || created == null) return;
      OperationManager.instance.quickTask('已添加到分类：${created.name}');
      return;
    }

    final target = _categories.firstWhere(
      (c) => c.id == result,
      orElse: () => AppCategory.empty,
    );
    if (target.id.isEmpty) return;
    await _toggleShortcutInCategory(target, shortcut);
  }

  void _reorderVisibleCategories(int oldIndex, int newIndex) {
    final visible = _visibleCategories;
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = visible.removeAt(oldIndex);
    visible.insert(newIndex, moved);

    final empties = _categories.where((c) => c.paths.isEmpty).toList();
    _setState(() {
      _categories = [...visible, ...empties];
    });
    unawaited(_saveCategories());
  }
}
