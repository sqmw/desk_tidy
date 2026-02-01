part of '../../desk_tidy_home_page.dart';

extension _DeskTidyHomeCategoryCrud on _DeskTidyHomePageState {
  String _nextCategoryId() =>
      'cat_${DateTime.now().microsecondsSinceEpoch.toString()}';

  void _handleCategorySelected(String? id) {
    if (_isEditingCategory) {
      _cancelInlineCategoryEdit(save: false);
    }
    final shouldClearSearch = _appSearchQuery.trim().isNotEmpty && id != null;
    if (shouldClearSearch) {
      _appSearchController.clear();
    }
    _setState(() {
      if (shouldClearSearch) {
        _appSearchQuery = '';
        _categoryBeforeSearch = null;
      }
      _activeCategoryId = id;
    });
  }

  void _beginInlineCategoryEdit() {
    if (_isEditingCategory) return;
    final id = _activeCategoryId;
    if (id == null) return;
    final category = _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => AppCategory.empty,
    );
    if (category.id.isEmpty) return;
    _setState(() {
      _isEditingCategory = true;
      _editingCategoryId = id;
      _editingSelection = {...category.paths};
      _categoryEditBackup = {
        id: {...category.paths},
      };
    });
  }

  Future<String?> _promptRenameCategoryName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名分类'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '分类名称'),
            onSubmitted: (_) => Navigator.of(context).pop(controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameCategory(AppCategory category) async {
    if (category.id.isEmpty) return;
    if (_isEditingCategory) {
      _cancelInlineCategoryEdit(save: false);
    }

    final name = await _promptRenameCategoryName(category.name);
    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final exists = _categories.any(
      (c) =>
          c.id != category.id && c.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) {
      if (mounted) {
        OperationManager.instance.quickTask('分类已存在', success: false);
      }
      return;
    }

    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx < 0) return;
    _setState(() {
      _categories = [
        ..._categories.take(idx),
        _categories[idx].copyWith(name: trimmed),
        ..._categories.skip(idx + 1),
      ];
    });
    await _saveCategories();
  }

  Future<void> _deleteCategory(AppCategory category) async {
    if (category.id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除分类'),
          content: Text('确定删除“${category.name}”吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    if (_isEditingCategory && _editingCategoryId == category.id) {
      _cancelInlineCategoryEdit(save: false);
    }

    _setState(() {
      _categories = _categories.where((c) => c.id != category.id).toList();
      if (_activeCategoryId == category.id) {
        _activeCategoryId = null;
      }
    });
    await _saveCategories();

    if (!mounted) return;
    OperationManager.instance.quickTask('已删除分类');
  }

  void _toggleInlineSelection(ShortcutItem shortcut) {
    final id = _editingCategoryId;
    if (id == null) return;
    final idx = _categories.indexWhere((c) => c.id == id);
    if (idx < 0) return;

    final next = {..._editingSelection};
    if (next.contains(shortcut.path)) {
      next.remove(shortcut.path);
    } else {
      next.add(shortcut.path);
    }

    final updated = _categories[idx].copyWith(paths: next);
    _setState(() {
      _editingSelection = next;
      _categories = [
        ..._categories.take(idx),
        updated,
        ..._categories.skip(idx + 1),
      ];
    });
  }

  Future<void> _saveInlineCategoryEdit() async {
    _cancelInlineCategoryEdit(save: true);
    await _saveCategories();
  }

  void _cancelInlineCategoryEdit({required bool save}) {
    final id = _editingCategoryId;
    final backup = _categoryEditBackup;
    AppCategory? restoredCategory;
    if (!save && id != null && backup != null && backup.containsKey(id)) {
      final idx = _categories.indexWhere((c) => c.id == id);
      if (idx >= 0) {
        restoredCategory = _categories[idx].copyWith(paths: {...backup[id]!});
      }
    }

    _setState(() {
      if (restoredCategory != null) {
        final idx = _categories.indexWhere((c) => c.id == id);
        _categories = [
          ..._categories.take(idx),
          restoredCategory,
          ..._categories.skip(idx + 1),
        ];
      }
      _isEditingCategory = false;
      _editingCategoryId = null;
      _editingSelection = {};
      _categoryEditBackup = null;
    });
  }

  Future<AppCategory?> _createCategory(
    String name, {
    ShortcutItem? initialShortcut,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final exists = _categories.any(
      (c) => c.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) {
      if (mounted) {
        OperationManager.instance.quickTask('分类已存在', success: false);
      }
      return null;
    }

    final newCategory = AppCategory(
      id: _nextCategoryId(),
      name: trimmed,
      paths: initialShortcut == null ? <String>{} : {initialShortcut.path},
    );

    _setState(() {
      _categories = [..._categories, newCategory];
      if (initialShortcut != null && _activeCategoryId == null) {
        _activeCategoryId = newCategory.id;
      }
    });
    await _saveCategories();
    return newCategory;
  }

  Future<void> _toggleShortcutInCategory(
    AppCategory category,
    ShortcutItem shortcut,
  ) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx < 0) return;
    final updatedPaths = {...category.paths};
    final alreadyIn = updatedPaths.contains(shortcut.path);
    if (alreadyIn) {
      updatedPaths.remove(shortcut.path);
    } else {
      updatedPaths.add(shortcut.path);
    }
    final updated = category.copyWith(paths: updatedPaths);
    _setState(() {
      _categories = [
        ..._categories.take(idx),
        updated,
        ..._categories.skip(idx + 1),
      ];
      if (updated.paths.isEmpty && _activeCategoryId == updated.id) {
        _activeCategoryId = null;
      }
    });
    await _saveCategories();
    if (!mounted) return;
    final text = alreadyIn ? '已从分类移除' : '已添加到分类';
    OperationManager.instance.quickTask('$text：${category.name}');
  }

  Future<String?> _promptCategoryName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建分类'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '分类名称'),
            onSubmitted: (_) => Navigator.of(context).pop(controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}
