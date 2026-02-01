part of '../../desk_tidy_home_page.dart';

extension _DeskTidyHomeSystemHandlers on _DeskTidyHomePageState {
  Future<void> _handleHideDesktopItemsChanged(bool hide) async {
    _setState(() => _hideDesktopItems = hide);
    AppPreferences.saveHideDesktopItems(hide);
    final ok = await setDesktopIconsVisible(!hide);
    if (!mounted) return;
    if (!ok) {
      _setState(() => _hideDesktopItems = !hide);
      OperationManager.instance.quickTask('切换失败，请重试', success: false);
      return;
    }
    OperationManager.instance.quickTask(hide ? '已隐藏系统桌面图标' : '已显示系统桌面图标');
    await _syncDesktopIconVisibility();
  }

  void _handleThemeChange(ThemeModeOption? option) {
    if (option == null) return;
    _setState(() => _themeModeOption = option);

    switch (option) {
      case ThemeModeOption.light:
        appThemeNotifier.value = ThemeMode.light;
        break;
      case ThemeModeOption.dark:
        appThemeNotifier.value = ThemeMode.dark;
        break;
      case ThemeModeOption.system:
        appThemeNotifier.value = ThemeMode.system;
        break;
    }
  }
}
