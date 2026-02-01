part of '../../desk_tidy_home_page.dart';

extension _DeskTidyHomeCategoryUtils on _DeskTidyHomePageState {
  bool _pathsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // 比较两个快捷方式列表是否相等
  bool _shortcutsEqual(List<ShortcutItem> oldList, List<ShortcutItem> newList) {
    if (oldList.length != newList.length) return false;

    // 使用Set来比较，性能更好
    final oldPathSet = oldList.map((item) => item.path).toSet();
    final newPathSet = newList.map((item) => item.path).toSet();

    return oldPathSet.length == newPathSet.length &&
        oldPathSet.containsAll(newPathSet);
  }
}
