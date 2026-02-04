part of '../app_preferences.dart';

class DeskTidyConfig {
  final double transparency;
  final double frostStrength;
  final double iconSize;
  final bool showHidden;
  final bool hideDesktopItems;
  final bool enableDesktopBoxes;
  final bool autoRefresh;
  final bool autoLaunch;
  final ThemeModeOption themeModeOption;
  final String? backgroundPath;
  final bool beautifyAppIcons;
  final bool beautifyDesktopIcons;
  final IconBeautifyStyle beautifyStyle;
  final bool showRecycleBin;
  final bool showThisPC;
  final bool showControlPanel;
  final bool showNetwork;
  final bool showUserFiles;
  final bool iconIsolatesEnabled;

  const DeskTidyConfig({
    required this.transparency,
    required this.frostStrength,
    required this.iconSize,
    required this.showHidden,
    required this.hideDesktopItems,
    required this.enableDesktopBoxes,
    required this.autoRefresh,
    required this.autoLaunch,
    required this.themeModeOption,
    required this.backgroundPath,
    required this.beautifyAppIcons,
    required this.beautifyDesktopIcons,
    required this.beautifyStyle,
    required this.showRecycleBin,
    required this.showThisPC,
    required this.showControlPanel,
    required this.showNetwork,
    required this.showUserFiles,
    required this.iconIsolatesEnabled,
  });
}

class WindowBounds {
  final int x;
  final int y;
  final int width;
  final int height;

  const WindowBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// 快捷键唤醒窗口布局（使用屏幕比例存储，适配不同分辨率）
class HotkeyWindowLayout {
  final double xRatio;
  final double yRatio;
  final double wRatio;
  final double hRatio;

  const HotkeyWindowLayout({
    required this.xRatio,
    required this.yRatio,
    required this.wRatio,
    required this.hRatio,
  });

  /// 根据屏幕尺寸计算实际窗口边界
  WindowBounds toBounds(int screenWidth, int screenHeight) {
    return WindowBounds(
      x: (screenWidth * xRatio).round(),
      y: (screenHeight * yRatio).round(),
      width: (screenWidth * wRatio).round(),
      height: (screenHeight * hRatio).round(),
    );
  }

  /// 从实际像素边界转换为屏幕比例
  factory HotkeyWindowLayout.fromBounds(
    WindowBounds bounds,
    int screenWidth,
    int screenHeight,
  ) {
    return HotkeyWindowLayout(
      xRatio: bounds.x / screenWidth,
      yRatio: bounds.y / screenHeight,
      wRatio: bounds.width / screenWidth,
      hRatio: bounds.height / screenHeight,
    );
  }
}

class StoredCategory {
  final String id;
  final String name;
  final List<String> shortcutPaths;

  const StoredCategory({
    required this.id,
    required this.name,
    required this.shortcutPaths,
  });

  factory StoredCategory.fromJson(Map<String, dynamic> json) {
    final paths = (json['paths'] as List?)?.whereType<String>().toList() ?? [];
    return StoredCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shortcutPaths: paths,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'paths': shortcutPaths};
  }
}
