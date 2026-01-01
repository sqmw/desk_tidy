import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:settings_ui/settings_ui.dart';

enum ThemeModeOption { system, light, dark }

class SettingsPage extends StatelessWidget {
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

  final ValueChanged<double> onTransparencyChanged;
  final ValueChanged<double> onFrostStrengthChanged;
  final ValueChanged<double> onIconSizeChanged;
  final ValueChanged<bool> onShowHiddenChanged;
  final ValueChanged<bool> onAutoRefreshChanged;
  final ValueChanged<bool> onAutoLaunchChanged;
  final ValueChanged<bool> onHideDesktopItemsChanged;
  final ValueChanged<ThemeModeOption?> onThemeModeChanged;
  final ValueChanged<String?> onBackgroundPathChanged;

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
    required this.onTransparencyChanged,
    required this.onFrostStrengthChanged,
    required this.onIconSizeChanged,
    required this.onShowHiddenChanged,
    required this.onAutoRefreshChanged,
    required this.onAutoLaunchChanged,
    required this.onHideDesktopItemsChanged,
    required this.onThemeModeChanged,
    required this.onBackgroundPathChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelOpacity =
        (0.12 + 0.28 * (1.0 - transparency)).clamp(0.12, 0.42).toDouble();
    final dividerOpacity =
        (0.10 + 0.10 * (1.0 - transparency)).clamp(0.10, 0.20).toDouble();

    SettingsThemeData buildTheme(Color base) => SettingsThemeData(
          settingsListBackground: base.withValues(alpha: panelOpacity),
          settingsSectionBackground: base.withValues(alpha: panelOpacity),
          tileHighlightColor: base.withValues(
            alpha: (panelOpacity + 0.10).clamp(0.0, 1.0),
          ),
          dividerColor: theme.dividerColor.withValues(alpha: dividerOpacity),
          titleTextColor:
              theme.colorScheme.onSurface.withValues(alpha: 0.88),
          settingsTileTextColor:
              theme.colorScheme.onSurface.withValues(alpha: 0.88),
          trailingTextColor:
              theme.colorScheme.onSurface.withValues(alpha: 0.72),
          leadingIconsColor:
              theme.colorScheme.onSurface.withValues(alpha: 0.72),
          tileDescriptionTextColor:
              theme.colorScheme.onSurface.withValues(alpha: 0.72),
          inactiveTitleColor:
              theme.colorScheme.onSurface.withValues(alpha: 0.38),
          inactiveSubtitleColor:
              theme.colorScheme.onSurface.withValues(alpha: 0.38),
        );

    Future<void> _pickBackground() async {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
      );
      if (picked != null && picked.files.isNotEmpty) {
        final path = picked.files.single.path;
        if (path != null && path.isNotEmpty) {
          onBackgroundPathChanged(path);
        }
      }
    }

    return SettingsList(
      lightTheme: buildTheme(Colors.white),
      darkTheme: buildTheme(Colors.black),
      sections: [
        /// 外观设置：透明度 + 图标大小 + 每行数量 + 背景
        SettingsSection(
          title: const Text(''), // 隐藏标题
          tiles: <SettingsTile>[
            SettingsTile(
              title: const Text('窗口透明度'),
              description: Slider(
                value: transparency,
                min: 0.0,
                max: 1.0,
                divisions: 50,
                onChanged: onTransparencyChanged,
              ),
              trailing: Text('${(transparency * 100).toInt()}%'),
            ),
            SettingsTile(
              title: const Text('磨砂强度'),
              description: Slider(
                value: frostStrength,
                min: 0.0,
                max: 1.0,
                divisions: 50,
                onChanged: onFrostStrengthChanged,
              ),
              trailing: Text('${(frostStrength * 100).toInt()}%'),
            ),
            SettingsTile(
              title: const Text('图标大小'),
              description: Slider(
                value: iconSize,
                min: 24,
                max: 96,
                divisions: 8,
                onChanged: onIconSizeChanged,
              ),
              trailing: Text(iconSize.toInt().toString()),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.image),
              title: const Text('背景图片'),
              description: Text(
                (backgroundPath == null || backgroundPath!.isEmpty)
                    ? '未设置'
                    : backgroundPath!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: () => onBackgroundPathChanged(null),
                child: const Text('清除'),
              ),
              onPressed: (_) => _pickBackground(),
            ),
          ],
        ),

        /// 主题模式：跟随系统 / 浅色 / 深色
        SettingsSection(
          title: const Text(''), // 隐藏标题
          tiles: <SettingsTile>[
            SettingsTile(
              leading: const Icon(Icons.phone_iphone),
              title: const Text('跟随系统'),
              trailing: Radio<ThemeModeOption>(
                value: ThemeModeOption.system,
                groupValue: themeModeOption,
                onChanged: onThemeModeChanged,
              ),
              onPressed: (_) => onThemeModeChanged(ThemeModeOption.system),
            ),
            SettingsTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('浅色'),
              trailing: Radio<ThemeModeOption>(
                value: ThemeModeOption.light,
                groupValue: themeModeOption,
                onChanged: onThemeModeChanged,
              ),
              onPressed: (_) => onThemeModeChanged(ThemeModeOption.light),
            ),
            SettingsTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('深色'),
              trailing: Radio<ThemeModeOption>(
                value: ThemeModeOption.dark,
                groupValue: themeModeOption,
                onChanged: onThemeModeChanged,
              ),
              onPressed: (_) => onThemeModeChanged(ThemeModeOption.dark),
            ),
          ],
        ),

        /// 行为设置：隐藏文件 / 自动刷新
        SettingsSection(
          title: const Text(''),
          tiles: [
            SettingsTile.switchTile(
              onToggle: onHideDesktopItemsChanged,
              initialValue: hideDesktopItems,
              leading: const Icon(Icons.visibility_off),
              title: const Text('隐藏桌面图标(Windows)'),
              description: const Text('调用系统“显示桌面图标”，不会修改文件属性。'),
            ),
            SettingsTile.switchTile(
              onToggle: onShowHiddenChanged,
              initialValue: showHidden,
              leading: const Icon(Icons.visibility),
              title: const Text('显示隐藏的文件/文件夹'),
            ),
            SettingsTile.switchTile(
              onToggle: onAutoRefreshChanged,
              initialValue: autoRefresh,
              leading: const Icon(Icons.refresh),
              title: const Text('自动刷新桌面'),
            ),
            SettingsTile.switchTile(
              onToggle: onAutoLaunchChanged,
              initialValue: autoLaunch,
              leading: const Icon(Icons.power_settings_new),
              title: const Text('开机自动启动(Windows)'),
            ),
          ],
        ),
      ],
    );
  }
}
