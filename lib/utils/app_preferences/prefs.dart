part of '../app_preferences.dart';

class AppPreferences {
  static const _kTransparency = 'ui.transparency';
  static const _kFrostStrength = 'ui.frostStrength';
  static const _kIconSize = 'ui.iconSize';
  static const _kShowHidden = 'behavior.showHidden';
  static const _kHideDesktopItems = 'behavior.hideDesktopItems';
  static const _kEnableDesktopBoxes = 'behavior.enableDesktopBoxes';
  static const _kAutoRefresh = 'behavior.autoRefresh';
  static const _kAutoLaunch = 'behavior.autoLaunch';
  static const _kIconIsolates = 'perf.iconIsolates';
  static const _kThemeMode = 'ui.themeMode';
  static const _kBackgroundPath = 'ui.backgroundPath';
  static const _kBeautifyAppIcons = 'ui.beautify.appIcons';
  static const _kBeautifyDesktopIcons = 'ui.beautify.desktopIcons';
  static const _kBeautifyStyle = 'ui.beautify.style';
  static const _kWinX = 'window.x';
  static const _kWinY = 'window.y';
  static const _kWinW = 'window.w';
  static const _kWinH = 'window.h';
  static const _kCategories = 'categories.v1';

  // 系统项目显示设置
  static const _kShowRecycleBin = 'systemItems.recycleBin';
  static const _kShowThisPC = 'systemItems.thisPC';
  static const _kShowControlPanel = 'systemItems.controlPanel';
  static const _kShowNetwork = 'systemItems.network';
  static const _kShowUserFiles = 'systemItems.userFiles';

  // 快捷键唤醒窗口布局（使用屏幕比例）
  static const _kHotkeyXRatio = 'window.hotkey.xRatio';
  static const _kHotkeyYRatio = 'window.hotkey.yRatio';
  static const _kHotkeyWRatio = 'window.hotkey.wRatio';
  static const _kHotkeyHRatio = 'window.hotkey.hRatio';

  // 热区唤醒窗口布局（使用屏幕比例）
  static const _kHotCornerXRatio = 'window.hotCorner.xRatio';
  static const _kHotCornerYRatio = 'window.hotCorner.yRatio';
  static const _kHotCornerWRatio = 'window.hotCorner.wRatio';
  static const _kHotCornerHRatio = 'window.hotCorner.hRatio';

  static Future<DeskTidyConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final transparency = prefs.getDouble(_kTransparency) ?? 0.2;
    final frostStrength = prefs.getDouble(_kFrostStrength) ?? 0.82;
    final iconSize = prefs.getDouble(_kIconSize) ?? 32;
    final showHidden = prefs.getBool(_kShowHidden) ?? false;
    final hideDesktopItems = prefs.getBool(_kHideDesktopItems) ?? false;
    final enableDesktopBoxes = prefs.getBool(_kEnableDesktopBoxes) ?? false;
    final autoRefresh = prefs.getBool(_kAutoRefresh) ?? false;
    final autoLaunch = prefs.getBool(_kAutoLaunch) ?? true;
    final iconIsolates = prefs.getBool(_kIconIsolates) ?? true;
    final themeModeIndex =
        prefs.getInt(_kThemeMode) ?? ThemeModeOption.dark.index;
    final themeMode = ThemeModeOption
        .values[themeModeIndex.clamp(0, ThemeModeOption.values.length - 1)];
    final backgroundPath = prefs.getString(_kBackgroundPath);
    final beautifyAppIcons = prefs.getBool(_kBeautifyAppIcons) ?? false;
    final beautifyDesktopIcons = prefs.getBool(_kBeautifyDesktopIcons) ?? false;
    final beautifyStyleIndex =
        prefs.getInt(_kBeautifyStyle) ?? IconBeautifyStyle.cute.index;
    final beautifyStyle =
        IconBeautifyStyle.values[beautifyStyleIndex.clamp(
          0,
          IconBeautifyStyle.values.length - 1,
        )];
    final showRecycleBin = prefs.getBool(_kShowRecycleBin) ?? true;
    final showThisPC = prefs.getBool(_kShowThisPC) ?? true;
    final showControlPanel = prefs.getBool(_kShowControlPanel) ?? false;
    final showNetwork = prefs.getBool(_kShowNetwork) ?? false;
    final showUserFiles = prefs.getBool(_kShowUserFiles) ?? false;

    return DeskTidyConfig(
      transparency: transparency.clamp(0.0, 1.0),
      frostStrength: frostStrength.clamp(0.0, 1.0),
      iconSize: iconSize.clamp(24.0, 96.0),
      showHidden: showHidden,
      hideDesktopItems: hideDesktopItems,
      enableDesktopBoxes: enableDesktopBoxes,
      autoRefresh: autoRefresh,
      autoLaunch: autoLaunch,
      themeModeOption: themeMode,
      backgroundPath: backgroundPath,
      beautifyAppIcons: beautifyAppIcons,
      beautifyDesktopIcons: beautifyDesktopIcons,
      beautifyStyle: beautifyStyle,
      showRecycleBin: showRecycleBin,
      showThisPC: showThisPC,
      showControlPanel: showControlPanel,
      showNetwork: showNetwork,
      showUserFiles: showUserFiles,
      iconIsolatesEnabled: iconIsolates,
    );
  }

  static Future<void> saveTransparency(double transparency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTransparency, transparency.clamp(0.0, 1.0));
  }

  static Future<void> saveFrostStrength(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFrostStrength, v.clamp(0.0, 1.0));
  }

  static Future<void> saveIconSize(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kIconSize, v.clamp(24.0, 96.0));
  }

  static Future<void> saveShowHidden(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowHidden, v);
  }

  static Future<void> saveHideDesktopItems(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHideDesktopItems, v);
  }

  static Future<void> saveEnableDesktopBoxes(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnableDesktopBoxes, v);
  }

  static Future<void> saveAutoRefresh(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoRefresh, v);
  }

  static Future<void> saveAutoLaunch(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoLaunch, v);
  }

  static Future<void> saveIconIsolatesEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIconIsolates, v);
  }

  static Future<void> saveThemeMode(ThemeModeOption v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, v.index);
  }

  static Future<void> saveBeautifyAppIcons(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBeautifyAppIcons, v);
  }

  static Future<void> saveBeautifyDesktopIcons(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBeautifyDesktopIcons, v);
  }

  static Future<void> saveBeautifyStyle(IconBeautifyStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBeautifyStyle, style.index);
  }

  static Future<void> saveShowRecycleBin(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowRecycleBin, v);
  }

  static Future<void> saveShowThisPC(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowThisPC, v);
  }

  static Future<void> saveShowControlPanel(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowControlPanel, v);
  }

  static Future<void> saveShowNetwork(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowNetwork, v);
  }

  static Future<void> saveShowUserFiles(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowUserFiles, v);
  }

  static Future<String?> backupAndSaveBackgroundPath(
    String? originalPath,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (originalPath == null || originalPath.trim().isEmpty) {
      await prefs.remove(_kBackgroundPath);
      return null;
    }

    final copied = await _backupBackgroundFile(originalPath.trim());
    final savedPath = copied ?? originalPath.trim();
    await prefs.setString(_kBackgroundPath, savedPath);
    return savedPath;
  }

  static Future<void> saveWindowBounds({
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWinX, x);
    await prefs.setInt(_kWinY, y);
    await prefs.setInt(_kWinW, width);
    await prefs.setInt(_kWinH, height);
  }

  static Future<WindowBounds?> loadWindowBounds() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getInt(_kWinX);
    final y = prefs.getInt(_kWinY);
    final w = prefs.getInt(_kWinW);
    final h = prefs.getInt(_kWinH);
    if (x == null || y == null || w == null || h == null) return null;
    if (w <= 0 || h <= 0) return null;
    return WindowBounds(x: x, y: y, width: w, height: h);
  }

  /// 保存快捷键唤醒窗口布局（使用屏幕比例）
  static Future<void> saveHotkeyWindowLayout({
    required double xRatio,
    required double yRatio,
    required double wRatio,
    required double hRatio,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kHotkeyXRatio, xRatio.clamp(0.0, 1.0));
    await prefs.setDouble(_kHotkeyYRatio, yRatio.clamp(0.0, 1.0));
    await prefs.setDouble(_kHotkeyWRatio, wRatio.clamp(0.1, 1.0));
    await prefs.setDouble(_kHotkeyHRatio, hRatio.clamp(0.1, 1.0));
  }

  /// 加载快捷键唤醒窗口布局（使用屏幕比例）
  /// 如果未保存过，返回默认居中布局
  static Future<HotkeyWindowLayout> loadHotkeyWindowLayout() async {
    final prefs = await SharedPreferences.getInstance();
    // 默认值：居中显示，宽 65%，高 75%
    const defaultWRatio = 0.65;
    const defaultHRatio = 0.75;
    const defaultXRatio = (1.0 - defaultWRatio) / 2; // 0.175
    const defaultYRatio = (1.0 - defaultHRatio) / 2; // 0.125

    return HotkeyWindowLayout(
      xRatio: prefs.getDouble(_kHotkeyXRatio) ?? defaultXRatio,
      yRatio: prefs.getDouble(_kHotkeyYRatio) ?? defaultYRatio,
      wRatio: prefs.getDouble(_kHotkeyWRatio) ?? defaultWRatio,
      hRatio: prefs.getDouble(_kHotkeyHRatio) ?? defaultHRatio,
    );
  }

  /// 保存热区唤醒窗口布局（使用屏幕比例）
  static Future<void> saveHotCornerWindowLayout({
    required double xRatio,
    required double yRatio,
    required double wRatio,
    required double hRatio,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kHotCornerXRatio, xRatio.clamp(0.0, 1.0));
    await prefs.setDouble(_kHotCornerYRatio, yRatio.clamp(0.0, 1.0));
    await prefs.setDouble(_kHotCornerWRatio, wRatio.clamp(0.1, 1.0));
    await prefs.setDouble(_kHotCornerHRatio, hRatio.clamp(0.1, 1.0));
  }

  /// 加载热区唤醒窗口布局（使用屏幕比例）
  /// 默认：左上角，宽 25%，高 85%（竖屏形态）
  static Future<HotkeyWindowLayout> loadHotCornerWindowLayout() async {
    final prefs = await SharedPreferences.getInstance();
    // 默认值：左上角，宽 18%，高 85%（竖屏窄高形态）
    const defaultXRatio = 0.0;
    const defaultYRatio = 0.0;
    const defaultWRatio = 0.18;
    const defaultHRatio = 0.85;

    return HotkeyWindowLayout(
      xRatio: prefs.getDouble(_kHotCornerXRatio) ?? defaultXRatio,
      yRatio: prefs.getDouble(_kHotCornerYRatio) ?? defaultYRatio,
      wRatio: prefs.getDouble(_kHotCornerWRatio) ?? defaultWRatio,
      hRatio: prefs.getDouble(_kHotCornerHRatio) ?? defaultHRatio,
    );
  }

  static Future<String?> _backupBackgroundFile(String originalPath) async {
    try {
      final src = File(originalPath);
      if (!src.existsSync()) return null;

      final support = await getApplicationSupportDirectory();
      final dir = Directory(
        '${support.path}${Platform.pathSeparator}desk_tidy',
      );
      await dir.create(recursive: true);

      final ext = _extension(originalPath);
      final dest = File('${dir.path}${Platform.pathSeparator}background$ext');
      await src.copy(dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  static String _extension(String path) {
    final idx = path.lastIndexOf('.');
    if (idx < 0) return '';
    final ext = path.substring(idx);
    return ext.length > 8 ? '' : ext;
  }

  static Future<List<StoredCategory>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCategories);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => StoredCategory.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCategories(List<StoredCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(categories.map((e) => e.toJson()).toList());
    await prefs.setString(_kCategories, payload);
  }
}
