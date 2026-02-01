part of '../../desk_tidy_home_page.dart';

extension _DeskTidyHomeCategoryPersistence on _DeskTidyHomePageState {
  Future<void> _loadCategories() async {
    final stored = await AppPreferences.loadCategories();
    if (!mounted) return;
    _setState(() {
      _categories = stored
          .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
          .map(
            (c) => AppCategory(
              id: c.id,
              name: c.name,
              paths: {...c.shortcutPaths},
            ),
          )
          .toList();
    });
  }

  Future<void> _saveCategories() async {
    await AppPreferences.saveCategories(
      _categories
          .map(
            (c) => StoredCategory(
              id: c.id,
              name: c.name,
              shortcutPaths: c.paths.toList(),
            ),
          )
          .toList(),
    );
  }
}
