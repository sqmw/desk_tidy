import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:settings_ui/settings_ui.dart';

enum ThemeModeOption { system, light, dark }

class SettingsPage extends StatelessWidget {
  final double opacity;
  final double iconSize;
  final int crossAxisCount;
  final bool showHidden;
  final bool autoRefresh;
  final ThemeModeOption themeModeOption;
  final String? backgroundPath;

  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onIconSizeChanged;
  final ValueChanged<int> onCrossAxisCountChanged;
  final ValueChanged<bool> onShowHiddenChanged;
  final ValueChanged<bool> onAutoRefreshChanged;
  final ValueChanged<ThemeModeOption?> onThemeModeChanged;
  final ValueChanged<String?> onBackgroundPathChanged;

  const SettingsPage({
    super.key,
    required this.opacity,
    required this.iconSize,
    required this.crossAxisCount,
    required this.showHidden,
    required this.autoRefresh,
    required this.themeModeOption,
    required this.backgroundPath,
    required this.onOpacityChanged,
    required this.onIconSizeChanged,
    required this.onCrossAxisCountChanged,
    required this.onShowHiddenChanged,
    required this.onAutoRefreshChanged,
    required this.onThemeModeChanged,
    required this.onBackgroundPathChanged,
  });

  @override
  Widget build(BuildContext context) {
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
      sections: [
        /// 外观设置：透明度 + 图标大小 + 每行数量 + 背景
        SettingsSection(
          title: const Text(''), // 隐藏标题
          tiles: <SettingsTile>[
            SettingsTile(
              title: const Text('窗口透明度'),
              description: Slider(
                value: opacity,
                min: 0.2,
                max: 1.0,
                divisions: 8,
                onChanged: onOpacityChanged,
              ),
              trailing: Text('${(opacity * 100).toInt()}%'),
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
            SettingsTile(
              title: const Text('每行显示数量'),
              trailing: DropdownButton<int>(
                value: crossAxisCount,
                items: [4, 5, 6, 7, 8]
                    .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onCrossAxisCountChanged(v);
                },
              ),
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
          ],
        ),
      ],
    );
  }
}
