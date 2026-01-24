import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:desk_tidy/services/update_service.dart';

import '../models/icon_beautify_style.dart';
import '../widgets/beautified_icon.dart';

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

  List<Widget> _buildStyleOptions(BuildContext context) {
    const previewSize = 28.0;
    const styles = [
      IconBeautifyStyle.cute,
      IconBeautifyStyle.cartoon,
      IconBeautifyStyle.neon,
    ];

    return styles.map((style) {
      return _StyleOptionChip(
        label: iconBeautifyStyleLabel(style),
        selected: widget.beautifyStyle == style,
        onTap: () => widget.onBeautifyStyleChanged(style),
        preview: BeautifiedIcon(
          bytes: null,
          fallback: Icons.apps,
          size: previewSize,
          enabled: true,
          style: style,
        ),
      );
    }).toList();
  }

  // 显示更新对话框
  void _showUpdateDialog(UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现新版本'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('新版本: v${updateInfo.latestVersion}'),
              const SizedBox(height: 8),
              if (updateInfo.releaseNotes.isNotEmpty) ...[
                const Text(
                  '更新内容:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(updateInfo.releaseNotes),
              ],
            ],
          ),
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
    final beautifyAny = widget.beautifyAppIcons || widget.beautifyDesktopIcons;

    SettingsThemeData buildTheme(Color base) => SettingsThemeData(
      settingsListBackground: base.withValues(alpha: panelOpacity),
      settingsSectionBackground: base.withValues(alpha: panelOpacity),
      tileHighlightColor: base.withValues(
        alpha: (panelOpacity + 0.10).clamp(0.0, 1.0),
      ),
      dividerColor: theme.dividerColor.withValues(alpha: dividerOpacity),
      titleTextColor: theme.colorScheme.onSurface.withValues(alpha: 0.88),
      settingsTileTextColor: theme.colorScheme.onSurface.withValues(
        alpha: 0.88,
      ),
      trailingTextColor: theme.colorScheme.onSurface.withValues(alpha: 0.72),
      leadingIconsColor: theme.colorScheme.onSurface.withValues(alpha: 0.72),
      tileDescriptionTextColor: theme.colorScheme.onSurface.withValues(
        alpha: 0.72,
      ),
      inactiveTitleColor: theme.colorScheme.onSurface.withValues(alpha: 0.38),
      inactiveSubtitleColor: theme.colorScheme.onSurface.withValues(
        alpha: 0.38,
      ),
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

        /// 系统项目：回收站 / 此电脑 / 控制面板 / 网络 / 个人文件夹
        SettingsSection(
          title: const Text(''), // 隐藏标题
          tiles: <SettingsTile>[
            SettingsTile(
              leading: const Icon(Icons.computer),
              title: const Text('显示此电脑'),
              trailing: Checkbox(
                value: widget.showThisPC,
                onChanged: (v) => widget.onShowThisPCChanged(v ?? false),
              ),
              onPressed: (_) => widget.onShowThisPCChanged(!widget.showThisPC),
            ),
            SettingsTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('显示回收站'),
              trailing: Checkbox(
                value: widget.showRecycleBin,
                onChanged: (v) => widget.onShowRecycleBinChanged(v ?? false),
              ),
              onPressed: (_) =>
                  widget.onShowRecycleBinChanged(!widget.showRecycleBin),
            ),
            SettingsTile(
              leading: const Icon(Icons.settings_applications),
              title: const Text('显示控制面板'),
              trailing: Checkbox(
                value: widget.showControlPanel,
                onChanged: (v) => widget.onShowControlPanelChanged(v ?? false),
              ),
              onPressed: (_) =>
                  widget.onShowControlPanelChanged(!widget.showControlPanel),
            ),
            SettingsTile(
              leading: const Icon(Icons.network_check),
              title: const Text('显示网络'),
              trailing: Checkbox(
                value: widget.showNetwork,
                onChanged: (v) => widget.onShowNetworkChanged(v ?? false),
              ),
              onPressed: (_) =>
                  widget.onShowNetworkChanged(!widget.showNetwork),
            ),
            SettingsTile(
              leading: const Icon(Icons.folder_shared),
              title: const Text('显示个人文件夹'),
              trailing: Checkbox(
                value: widget.showUserFiles,
                onChanged: (v) => widget.onShowUserFilesChanged(v ?? false),
              ),
              onPressed: (_) =>
                  widget.onShowUserFilesChanged(!widget.showUserFiles),
            ),
          ],
        ),

        /// 行为设置：快捷键 / 隐藏文件 / 自动刷新
        SettingsSection(
          title: const Text(''),
          tiles: [
            SettingsTile(
              leading: const Icon(Icons.keyboard),
              title: const Text('全局快捷键'),
              description: const Text(
                'Ctrl + Shift + Space 或 Alt + Shift + Space',
              ),
              trailing: const Icon(Icons.info_outline, size: 18),
              onPressed: (_) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('全局快捷键'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('唤醒窗口并聚焦搜索框：'),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.keyboard, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Ctrl + Shift + Space',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.keyboard, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Alt + Shift + Space',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          '窗口显示后：',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 4),
                        Text('• 双击图标打开后自动隐藏'),
                        Text('• 点击窗口外部自动隐藏'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
              },
            ),
            SettingsTile.switchTile(
              onToggle: widget.onHideDesktopItemsChanged,
              initialValue: widget.hideDesktopItems,
              leading: const Icon(Icons.visibility_off),
              title: const Text('隐藏桌面图标(Windows)'),
              description: const Text('调用系统"显示桌面图标"，不会修改文件属性。'),
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
            SettingsTile.switchTile(
              onToggle: widget.onEnableDesktopBoxesChanged,
              initialValue: widget.enableDesktopBoxes,
              leading: const Icon(Icons.inbox),
              title: const Text('启用桌面收纳盒'),
              description: const Text('将桌面的文件和文件夹分类显示在独立的浮动窗口中。'),
            ),
          ],
        ),

        SettingsSection(
          title: const Text(''),
          tiles: [
            SettingsTile.switchTile(
              onToggle: widget.onBeautifyAllChanged,
              initialValue: beautifyAny,
              leading: const Icon(Icons.auto_awesome),
              title: Row(
                children: [
                  const Text('图标主题（图标+文字）'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Beta',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              description: const Text('开启后默认同时替换桌面与应用列表的图标与文字色调'),
            ),
            SettingsTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('主题风格'),
              description: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildStyleOptions(context),
              ),
            ),
            SettingsTile.switchTile(
              onToggle: widget.onBeautifyAppIconsChanged,
              initialValue: widget.beautifyAppIcons,
              leading: const Icon(Icons.apps),
              title: const Text('应用列表'),
            ),
            SettingsTile.switchTile(
              onToggle: widget.onBeautifyDesktopIconsChanged,
              initialValue: widget.beautifyDesktopIcons,
              leading: const Icon(Icons.desktop_windows),
              title: const Text('桌面列表'),
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
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
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

class _StyleOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  const _StyleOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : theme.colorScheme.surface.withValues(alpha: 0.08);
    final border = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.55)
        : theme.dividerColor.withValues(alpha: 0.28);
    final textColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.86);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              preview,
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
