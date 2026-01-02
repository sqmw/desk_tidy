import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:desk_tidy/services/update_service.dart';

enum ThemeModeOption { system, light, dark }

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
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _checkingUpdate = false;
  String? _updateStatus;
  String? _appVersion;

  Future<void> _pickBackground() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
    );
    if (picked != null && picked.files.isNotEmpty) {
      final path = picked.files.single.path;
      if (path != null && path.isNotEmpty) {
        widget.onBackgroundPathChanged(path);
      }
    }
  }

  // 添加检查更新方法
  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = 'v${info.version}');
    } catch (_) {
      // Silence failures.
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateStatus = '正在检查更新...';
    });

    try {
      final updateInfo = await UpdateService.checkForUpdate();

      if (updateInfo == null) {
        setState(() {
          _updateStatus = '无法获取更新信息';
          _checkingUpdate = false;
        });
        return;
      }

      if (updateInfo.hasUpdate) {
        setState(() {
          _updateStatus = '发现新版本 v${updateInfo.latestVersion}!';
          _checkingUpdate = false;
        });

        // 显示更新对话框
        _showUpdateDialog(updateInfo);
      } else {
        setState(() {
          _updateStatus = '当前已是最新版本 v${updateInfo.currentVersion}';
          _checkingUpdate = false;
        });
        // _showInfoDialog('已是最新', '当前已是最新版本 v${updateInfo.currentVersion}');
      }
    } catch (e) {
      setState(() {
        _updateStatus = '检查更新失败: $e';
        _checkingUpdate = false;
      });
    }
  }

  // 显示更新对话框
  void _showUpdateDialog(UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('新版本: v${updateInfo.latestVersion}'),
            const SizedBox(height: 8),
            if (updateInfo.releaseNotes.isNotEmpty) ...[
              const Text('更新内容:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(updateInfo.releaseNotes),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await UpdateService.openDownloadUrl(updateInfo.downloadUrl);
            },
            child: const Text('立即下载'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelOpacity = (0.12 + 0.28 * (1.0 - widget.transparency))
        .clamp(0.12, 0.42)
        .toDouble();
    final dividerOpacity = (0.10 + 0.10 * (1.0 - widget.transparency))
        .clamp(0.10, 0.20)
        .toDouble();

    SettingsThemeData buildTheme(Color base) => SettingsThemeData(
          settingsListBackground: base.withValues(alpha: panelOpacity),
          settingsSectionBackground: base.withValues(alpha: panelOpacity),
          tileHighlightColor: base.withValues(
            alpha: (panelOpacity + 0.10).clamp(0.0, 1.0),
          ),
          dividerColor: theme.dividerColor.withValues(alpha: dividerOpacity),
          titleTextColor: theme.colorScheme.onSurface.withValues(alpha: 0.88),
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

    final status = _updateStatus;

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
                value: widget.transparency,
                min: 0.0,
                max: 1.0,
                divisions: 50,
                onChanged: widget.onTransparencyChanged,
              ),
              trailing: Text('${(widget.transparency * 100).toInt()}%'),
            ),
            SettingsTile(
              title: const Text('磨砂强度'),
              description: Slider(
                value: widget.frostStrength,
                min: 0.0,
                max: 1.0,
                divisions: 50,
                onChanged: widget.onFrostStrengthChanged,
              ),
              trailing: Text('${(widget.frostStrength * 100).toInt()}%'),
            ),
            SettingsTile(
              title: const Text('图标大小'),
              description: Slider(
                value: widget.iconSize,
                min: 24,
                max: 96,
                divisions: 8,
                onChanged: widget.onIconSizeChanged,
              ),
              trailing: Text(widget.iconSize.toInt().toString()),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.image),
              title: const Text('背景图片'),
              description: Text(
                (widget.backgroundPath == null ||
                        widget.backgroundPath!.isEmpty)
                    ? '未设置'
                    : widget.backgroundPath!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: () => widget.onBackgroundPathChanged(null),
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
                groupValue: widget.themeModeOption,
                onChanged: widget.onThemeModeChanged,
              ),
              onPressed: (_) =>
                  widget.onThemeModeChanged(ThemeModeOption.system),
            ),
            SettingsTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('浅色'),
              trailing: Radio<ThemeModeOption>(
                value: ThemeModeOption.light,
                groupValue: widget.themeModeOption,
                onChanged: widget.onThemeModeChanged,
              ),
              onPressed: (_) =>
                  widget.onThemeModeChanged(ThemeModeOption.light),
            ),
            SettingsTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('深色'),
              trailing: Radio<ThemeModeOption>(
                value: ThemeModeOption.dark,
                groupValue: widget.themeModeOption,
                onChanged: widget.onThemeModeChanged,
              ),
              onPressed: (_) => widget.onThemeModeChanged(ThemeModeOption.dark),
            ),
          ],
        ),

        /// 行为设置：隐藏文件 / 自动刷新
        SettingsSection(
          title: const Text(''),
          tiles: [
            SettingsTile.switchTile(
              onToggle: widget.onHideDesktopItemsChanged,
              initialValue: widget.hideDesktopItems,
              leading: const Icon(Icons.visibility_off),
              title: const Text('隐藏桌面图标(Windows)'),
              description: const Text('调用系统“显示桌面图标”，不会修改文件属性。'),
            ),
            SettingsTile.switchTile(
              onToggle: widget.onShowHiddenChanged,
              initialValue: widget.showHidden,
              leading: const Icon(Icons.visibility),
              title: const Text('显示隐藏的文件/文件夹'),
            ),
            SettingsTile.switchTile(
              onToggle: widget.onAutoRefreshChanged,
              initialValue: widget.autoRefresh,
              leading: const Icon(Icons.refresh),
              title: const Text('桌面图标自动更新'),
              description: const Text('周期性扫描桌面并仅在内容变化时悄然刷新'),
            ),
            SettingsTile.switchTile(
              onToggle: widget.onAutoLaunchChanged,
              initialValue: widget.autoLaunch,
              leading: const Icon(Icons.power_settings_new),
              title: const Text('开机自动启动(Windows)'),
            ),
          ],
        ),

        /// 检查更新
        SettingsSection(
          title: const Text(''),
          tiles: [
            SettingsTile(
              leading: Icon(Icons.update, color: theme.colorScheme.primary),
              title: const Text('检查更新'),
              description: status == null
                  ? null
                  : Text(
                      status,
                      style: TextStyle(
                        color: status.contains('最新')
                            ? Colors.green
                            : status.contains('发现')
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_checkingUpdate) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _appVersion ?? 'v?',
                    style: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
              onPressed: (_) => _checkForUpdate(),
            ),
          ],
        ),
      ],
    );
  }
}
