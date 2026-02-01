part of '../../desk_tidy_home_page.dart';

extension _DeskTidyHomeCategoryUtils on _DeskTidyHomePageState {
  bool _pathsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
