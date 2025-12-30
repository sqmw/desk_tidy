import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../models/shortcut_item.dart';
import '../setting/settings_page.dart';
import '../theme_notifier.dart';
import '../utils/desktop_helper.dart';
import '../utils/tray_helper.dart';
import '../widgets/glass.dart';
import '../widgets/shortcut_card.dart';
import 'all_page.dart';
import 'file_page.dart';
import 'folder_page.dart';

ThemeModeOption _themeModeOption = ThemeModeOption.dark;
bool _showHidden = false;
bool _autoRefresh = false;
double _iconSize = 32;

class DeskTidyHomePage extends StatefulWidget {
  const DeskTidyHomePage({super.key});

  @override
  State<DeskTidyHomePage> createState() => _DeskTidyHomePageState();
}

class _DeskTidyHomePageState extends State<DeskTidyHomePage> {
  final TrayHelper _trayHelper = TrayHelper();
  bool _trayReady = false;
  List<ShortcutItem> _shortcuts = [];
  String _desktopPath = '';
  bool _isLoading = true;
  bool _isMaximized = false;
  // Controls how much of the desktop shows through (via the background layer).
  // 1.0 = fully opaque, 0.0 = fully transparent.
  double _backgroundOpacity = 0.8;
  double _frostStrength = 0.82;
  String? _backgroundImagePath;
  bool _hideDesktopItems = false;

  int _selectedIndex = 0;

  double get _chromeOpacity =>
      (0.12 + 0.28 * _backgroundOpacity).clamp(0.12, 0.42);

  double get _contentPanelOpacity =>
      lerpDouble(0.20, 0.60, _frostStrength)!.clamp(0.0, 1.0);

  double get _contentPanelBlur =>
      lerpDouble(28, 16, _frostStrength)!.clamp(0.0, 40.0);

  double get _toolbarPanelOpacity =>
      lerpDouble(0.26, 0.70, _frostStrength)!.clamp(0.0, 1.0);

  double get _toolbarPanelBlur =>
      lerpDouble(26, 14, _frostStrength)!.clamp(0.0, 40.0);

  double get _indicatorOpacity =>
      (0.10 + 0.12 * _backgroundOpacity).clamp(0.10, 0.22);

  double _uiScale(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    // Desktop windows vary a lot; keep controls compact by default.
    return (height / 980).clamp(0.72, 1.0);
  }

  @override
  void initState() {
    super.initState();

    _hideDesktopItems = hasDesktopHiddenStore();

    windowManager.isMaximized().then((value) {
      if (mounted) {
        setState(() => _isMaximized = value);
      }
    });

    _loadShortcuts();
    // Tray mode is currently disabled until it's verified stable on target
    // machines; leaving this here for re-enable later.
    // _initTray();
  }

  Future<void> _initTray() async {
    try {
      await _trayHelper.init(
        onExitRequested: () async {
          await windowManager.setPreventClose(false);
          await windowManager.close();
        },
      );
      _trayReady = true;
      await windowManager.setSkipTaskbar(true);
      await windowManager.setPreventClose(true);
    } catch (_) {
      // Tray init failed; keep the app discoverable via taskbar.
      _trayReady = false;
      await windowManager.setSkipTaskbar(false);
      await windowManager.setPreventClose(false);
    }
  }

  Future<void> _loadShortcuts() async {
    setState(() => _isLoading = true);

    try {
      final desktopPath = await getDesktopPath();
      _desktopPath = desktopPath;
      final shortcutsPaths = await scanDesktopShortcuts(
        desktopPath,
        showHidden: _showHidden || _hideDesktopItems,
      );

      const requestIconSize = 256;

      final shortcutItems = <ShortcutItem>[];
      for (final shortcutPath in shortcutsPaths) {
        final name = shortcutPath.split('\\').last.replaceAll('.lnk', '');

        String targetPath = shortcutPath;
        bool isFolderShortcut = false;
        if (shortcutPath.toLowerCase().endsWith('.lnk')) {
          final target = getShortcutTarget(shortcutPath);
          if (target != null) {
            targetPath = target;
            isFolderShortcut = Directory(targetPath).existsSync();
          }
        }

        // Don't treat folder shortcuts as "apps".
        if (isFolderShortcut) {
          continue;
        }

        final iconData = extractIcon(shortcutPath, size: requestIconSize) ??
            extractIcon(targetPath, size: requestIconSize);

        shortcutItems.add(
          ShortcutItem(
            name: name,
            path: shortcutPath,
            iconPath: '',
            description: '桌面快捷方式',
            targetPath: targetPath,
            iconData: iconData,
          ),
        );
      }

      setState(() {
        _shortcuts = shortcutItems;
        _isLoading = false;
      });
    } catch (e) {
      print('加载快捷方式失败: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleMaximize() {
    if (_isMaximized) {
      windowManager.restore();
    } else {
      windowManager.maximize();
    }
    setState(() => _isMaximized = !_isMaximized);
  }

  void _minimizeWindow() {
    windowManager.minimize();
  }

  void _closeWindow() {
    if (_trayReady) {
      windowManager.hide();
    } else {
      windowManager.close();
    }
  }

  void _onNavigationRailItemSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onNavigationRailPointer(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons == kSecondaryMouseButton &&
        _selectedIndex != 1) {
      _showHiddenMenu(event.position);
    }
  }

  Future<void> _showHiddenMenu(Offset globalPosition) async {
    const menuItemValue = 0;
    final label = _showHidden ? '隐藏隐藏文件/文件夹' : '显示隐藏文件/文件夹';
    final icon = _showHidden ? Icons.visibility_off : Icons.visibility;

    final result = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: menuItemValue,
          child: ListTile(
            leading: Icon(icon),
            title: Text(label),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );

    if (result == menuItemValue) {
      setState(() => _showHidden = !_showHidden);
      _loadShortcuts();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = _uiScale(context);
    final railMinWidth = 48.0 * scale;
    final railPadH = 2.0 * scale;
    final railPadV = 4.0 * scale;
    final backgroundPath = _backgroundImagePath;
    final backgroundExists = backgroundPath != null &&
        backgroundPath.isNotEmpty &&
        File(backgroundPath).existsSync();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: _backgroundOpacity,
              child: backgroundExists
                  ? Image.file(
                      File(backgroundPath!),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
            ),
          ),
          Column(
            children: [
              _buildTitleBar(),
              Expanded(
                child: Row(
                  children: [
                    Listener(
                      onPointerDown: _onNavigationRailPointer,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: railPadH,
                          vertical: railPadV,
                        ),
                        child: GlassContainer(
                          borderRadius: BorderRadius.circular(18),
                          opacity: _chromeOpacity,
                          blurSigma: 20,
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.16),
                          ),
                          child: NavigationRail(
                            backgroundColor: Colors.transparent,
                            minWidth: railMinWidth,
                            useIndicator: true,
                            indicatorColor: theme.colorScheme.primary
                                .withOpacity(_indicatorOpacity),
                            selectedIconTheme: IconThemeData(
                              color: theme.colorScheme.primary,
                            ),
                            unselectedIconTheme: IconThemeData(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.72),
                            ),
                            selectedLabelTextStyle: theme.textTheme.labelMedium
                                ?.copyWith(color: theme.colorScheme.primary),
                            unselectedLabelTextStyle:
                                theme.textTheme.labelMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.72),
                            ),
                            selectedIndex: _selectedIndex,
                            onDestinationSelected:
                                _onNavigationRailItemSelected,
                            labelType: NavigationRailLabelType.none,
                            destinations: [
                              NavigationRailDestination(
                                icon: Tooltip(
                                  message: '应用',
                                  child: Icon(Icons.apps),
                                ),
                                label: const Text('应用'),
                              ),
                              NavigationRailDestination(
                                icon: Tooltip(
                                  message: '全部',
                                  child: Icon(Icons.all_inbox),
                                ),
                                label: const Text('全部'),
                              ),
                              NavigationRailDestination(
                                icon: Tooltip(
                                  message: '文件夹',
                                  child: Icon(Icons.folder),
                                ),
                                label: const Text('文件夹'),
                              ),
                              NavigationRailDestination(
                                icon: Tooltip(
                                  message: '文件',
                                  child: Icon(Icons.insert_drive_file),
                                ),
                                label: const Text('文件'),
                              ),
                              NavigationRailDestination(
                                icon: Tooltip(
                                  message: '设置',
                                  child: Icon(Icons.settings),
                                ),
                                label: const Text('设置'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    VerticalDivider(
                      thickness: 1,
                      width: 1,
                      color: theme.dividerColor.withOpacity(0.12),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          10 * scale,
                          6 * scale,
                          10 * scale,
                          10 * scale,
                        ),
                        child: GlassContainer(
                          borderRadius: BorderRadius.circular(18),
                          opacity: _contentPanelOpacity,
                          blurSigma: _contentPanelBlur,
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.16),
                          ),
                          child: _buildContent(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    final theme = Theme.of(context);
    final scale = _uiScale(context);
    final titleBarHeight = 34.0 * scale;
    final titleButtonSize = 32.0 * scale;
    return MouseRegion(
      onEnter: (_) => null,
      child: GestureDetector(
        onPanUpdate: (_) => windowManager.startDragging(),
        child: GlassContainer(
          opacity: _chromeOpacity,
          blurSigma: 20,
          borderRadius: BorderRadius.zero,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withOpacity(0.16),
              width: 0.8,
            ),
          ),
          child: SizedBox(
            height: titleBarHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10 * scale),
              child: Row(
                children: [
                  const Spacer(),
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: titleButtonSize,
                          height: titleButtonSize,
                        ),
                        icon: const Icon(Icons.remove),
                        onPressed: _minimizeWindow,
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: titleButtonSize,
                          height: titleButtonSize,
                        ),
                        icon: Icon(
                          _isMaximized ? Icons.filter_none : Icons.crop_square,
                        ),
                        onPressed: _toggleMaximize,
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: titleButtonSize,
                          height: titleButtonSize,
                        ),
                        icon: const Icon(Icons.close),
                        onPressed: _closeWindow,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final effectiveShowHidden = _showHidden || _hideDesktopItems;
    switch (_selectedIndex) {
      case 0:
        return _buildApplicationContent();
      case 1:
        return AllPage(
          desktopPath: _desktopPath,
          showHidden: effectiveShowHidden,
        );
      case 2:
        return FolderPage(
          desktopPath: _desktopPath,
          showHidden: effectiveShowHidden,
        );
      case 3:
        return FilePage(
          desktopPath: _desktopPath,
          showHidden: effectiveShowHidden,
        );
      case 4:
        return SettingsPage(
          transparency: (1.0 - _backgroundOpacity).clamp(0.0, 1.0),
          frostStrength: _frostStrength,
          iconSize: _iconSize,
          showHidden: _showHidden,
          autoRefresh: _autoRefresh,
          hideDesktopItems: _hideDesktopItems,
          themeModeOption: _themeModeOption,
          backgroundPath: _backgroundImagePath,
          onTransparencyChanged: (v) {
            setState(() => _backgroundOpacity = (1.0 - v).clamp(0.0, 1.0));
          },
          onFrostStrengthChanged: (v) => setState(() => _frostStrength = v),
          onIconSizeChanged: (v) => setState(() => _iconSize = v),
          onShowHiddenChanged: (v) {
            setState(() => _showHidden = v);
            _loadShortcuts();
          },
          onAutoRefreshChanged: (v) => setState(() => _autoRefresh = v),
          onHideDesktopItemsChanged: _handleHideDesktopItemsChanged,
          onThemeModeChanged: _handleThemeChange,
          onBackgroundPathChanged: (path) {
            setState(() {
              final trimmed = path?.trim() ?? '';
              _backgroundImagePath = trimmed.isEmpty ? null : trimmed;
            });
          },
        );
      default:
        return _buildApplicationContent();
    }
  }

  Future<void> _handleHideDesktopItemsChanged(bool hide) async {
    if (_desktopPath.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('桌面路径尚未准备好')),
      );
      return;
    }

    setState(() => _hideDesktopItems = hide);
    final result = await setDesktopItemsHidden(_desktopPath, hidden: hide);
    if (!mounted) return;

    final msg =
        hide ? '已隐藏桌面项目: ${result.updated} 个' : '已恢复桌面项目: ${result.updated} 个';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed == 0 ? msg : '$msg (失败 ${result.failed} 个)',
        ),
      ),
    );
    await _loadShortcuts();
  }

  void _handleThemeChange(ThemeModeOption? option) {
    if (option == null) return;
    setState(() => _themeModeOption = option);

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

  Widget _buildApplicationContent() {
    final scale = _uiScale(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            10 * scale,
            10 * scale,
            10 * scale,
            6 * scale,
          ),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(16),
            opacity: _toolbarPanelOpacity,
            blurSigma: _toolbarPanelBlur,
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.16),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 10 * scale,
              vertical: 6 * scale,
            ),
            child: Row(
              children: [
                Text(
                  '应用列表 (${_shortcuts.length})',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loadShortcuts,
                  icon: const Icon(Icons.refresh),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(
                              0.10 + 0.10 * _backgroundOpacity,
                            ),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    shape: const StadiumBorder(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12 * scale,
                      vertical: 8 * scale,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  label: const Text('刷新'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _shortcuts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            '未找到桌面快捷方式',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '桌面路径: $_desktopPath',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisSpacing = 12.0 * scale;
                        final mainAxisSpacing = 12.0 * scale;
                        final estimatedTextHeight = _estimateTextHeight();
                        final padding = math.max(8.0, _iconSize * 0.28);
                        final iconContainerSize =
                            math.max(28.0, _iconSize * 1.65);
                        final tileMaxExtent = math.max(
                          120.0,
                          iconContainerSize + padding * 2,
                        );
                        final cardHeight = padding * 0.6 * 2 +
                            iconContainerSize +
                            padding * 0.6 +
                            estimatedTextHeight;
                        final aspectRatio =
                            cardHeight <= 0 ? 1 : tileMaxExtent / cardHeight;

                        return GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            14 * scale,
                            0,
                            14 * scale,
                            14 * scale,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: tileMaxExtent,
                            crossAxisSpacing: crossAxisSpacing,
                            mainAxisSpacing: mainAxisSpacing,
                            childAspectRatio: aspectRatio.toDouble(),
                          ),
                          itemCount: _shortcuts.length,
                          itemBuilder: (context, index) {
                            return ShortcutCard(
                              shortcut: _shortcuts[index],
                              iconSize: _iconSize,
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  double _estimateTextHeight() {
    final size = (_iconSize * 0.34).clamp(10, 18);
    // allow up to 2 lines with some spacing
    return size * 2.9 + 6;
  }
}
