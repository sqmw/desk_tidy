part of '../settings_page.dart';

class SettingsPage extends StatefulWidget {
  /// 0.0 = fully opaque, 1.0 = fully transparent.
  final double transparency;

  /// 0.0 = more acrylic (lighter), 1.0 = more mica (steadier).
  final double frostStrength;
  final double iconSize;
  final bool showHidden;
  final bool autoRefresh;
  final bool autoLaunch;
  final bool hideDesktopItems;
  final ThemeModeOption themeModeOption;
  final String? backgroundPath;
  final bool beautifyAppIcons;
  final bool beautifyDesktopIcons;
  final IconBeautifyStyle beautifyStyle;
  final bool enableDesktopBoxes;
  final bool showRecycleBin;
  final bool showThisPC;
  final bool showControlPanel;
  final bool showNetwork;
  final bool showUserFiles;

  final ValueChanged<double> onTransparencyChanged;
  final ValueChanged<double> onFrostStrengthChanged;
  final ValueChanged<double> onIconSizeChanged;
  final ValueChanged<bool> onShowHiddenChanged;
  final ValueChanged<bool> onAutoRefreshChanged;
  final ValueChanged<bool> onAutoLaunchChanged;
  final ValueChanged<bool> onHideDesktopItemsChanged;
  final ValueChanged<ThemeModeOption?> onThemeModeChanged;
  final ValueChanged<String?> onBackgroundPathChanged;
  final ValueChanged<bool> onBeautifyAppIconsChanged;
  final ValueChanged<bool> onBeautifyDesktopIconsChanged;
  final ValueChanged<bool> onBeautifyAllChanged;
  final ValueChanged<IconBeautifyStyle> onBeautifyStyleChanged;
  final ValueChanged<bool> onEnableDesktopBoxesChanged;
  final ValueChanged<bool> onShowRecycleBinChanged;
  final ValueChanged<bool> onShowThisPCChanged;
  final ValueChanged<bool> onShowControlPanelChanged;
  final ValueChanged<bool> onShowNetworkChanged;
  final ValueChanged<bool> onShowUserFilesChanged;

  const SettingsPage({
    super.key,
    required this.transparency,
    required this.frostStrength,
    required this.iconSize,
    required this.showHidden,
    required this.autoRefresh,
    required this.autoLaunch,
    required this.hideDesktopItems,
    required this.themeModeOption,
    required this.backgroundPath,
    required this.beautifyAppIcons,
    required this.beautifyDesktopIcons,
    required this.beautifyStyle,
    required this.enableDesktopBoxes,
    required this.showRecycleBin,
    required this.showThisPC,
    required this.showControlPanel,
    required this.showNetwork,
    required this.showUserFiles,
    required this.onTransparencyChanged,
    required this.onFrostStrengthChanged,
    required this.onIconSizeChanged,
    required this.onShowHiddenChanged,
    required this.onAutoRefreshChanged,
    required this.onAutoLaunchChanged,
    required this.onHideDesktopItemsChanged,
    required this.onThemeModeChanged,
    required this.onBackgroundPathChanged,
    required this.onBeautifyAppIconsChanged,
    required this.onBeautifyDesktopIconsChanged,
    required this.onBeautifyAllChanged,
    required this.onBeautifyStyleChanged,
    required this.onEnableDesktopBoxesChanged,
    required this.onShowRecycleBinChanged,
    required this.onShowThisPCChanged,
    required this.onShowControlPanelChanged,
    required this.onShowNetworkChanged,
    required this.onShowUserFilesChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _checkingUpdate = false;
  String? _updateStatus;
  String? _appVersion;

  void _setState(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  @override
  Widget build(BuildContext context) => _buildBody();
}
