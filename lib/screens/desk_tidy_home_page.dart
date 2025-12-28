import 'dart:math' as math;
import 'dart:ui';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../models/shortcut_item.dart';
import '../setting/settings_page.dart';
import '../theme_notifier.dart';
import '../utils/desktop_helper.dart';
import '../widgets/shortcut_card.dart';
import 'all_page.dart';
import 'file_page.dart';
import 'folder_page.dart';

ThemeModeOption _themeModeOption = ThemeModeOption.system;
bool _showHidden = false;
bool _autoRefresh = false;
double _iconSize = 32;
int _crossAxisCount = 6;
double _opacity = 1.0;

class DeskTidyHomePage extends StatefulWidget {
  const DeskTidyHomePage({super.key});

  @override
  State<DeskTidyHomePage> createState() => _DeskTidyHomePageState();
}

class _DeskTidyHomePageState extends State<DeskTidyHomePage>
    with WindowListener {
  List<ShortcutItem> _shortcuts = [];
  String _desktopPath = '';
  bool _isLoading = true;
  bool _isMaximized = false;
  double _opacity = 1.0;
  String? _backgroundImagePath;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    windowManager.ensureInitialized();
    windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    windowManager.setOpacity(_opacity);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted) {
        setState(() => _isMaximized = value);
      }
    });

    _loadShortcuts();
  }

  Future<void> _loadShortcuts() async {
    setState(() => _isLoading = true);

    try {
      final dpr =
          WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final desktopPath = await getDesktopPath();
      _desktopPath = desktopPath;
      final shortcutsPaths = await scanDesktopShortcuts(
        desktopPath,
        showHidden: _showHidden,
      );

      final iconContainerSize = math.max(28.0, _iconSize * 1.65);
      final visualIconSize = math.max(12.0, iconContainerSize * 0.92);
      final requestIconSize =
          (visualIconSize * dpr).round().clamp(64, 256);

      final shortcutItems = <ShortcutItem>[];
      for (final shortcutPath in shortcutsPaths) {
        final name = shortcutPath.split('\\').last.replaceAll('.lnk', '');

        String targetPath = shortcutPath;
        if (shortcutPath.toLowerCase().endsWith('.lnk')) {
          final target = getShortcutTarget(shortcutPath);
          if (target != null) {
            targetPath = target;
          }
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
    windowManager.close();
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
    final icon =
        _showHidden ? Icons.visibility_off : Icons.visibility;

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

  void _changeOpacity(double opacity) {
    setState(() => _opacity = opacity);
    windowManager.setOpacity(opacity);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowRestore() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundPath = _backgroundImagePath;
    final backgroundExists =
        backgroundPath != null && backgroundPath.isNotEmpty && File(backgroundPath).existsSync();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundExists)
            Positioned.fill(
              child: Image.file(
                File(backgroundPath!),
                fit: BoxFit.cover,
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
                      child: NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _onNavigationRailItemSelected,
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.apps),
                          label: Text('应用'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.all_inbox),
                          label: Text('全部'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.folder),
                          label: Text('文件夹'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.insert_drive_file),
                          label: Text('文件'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings),
                          label: Text('设置'),
                        ),
                  ]),
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                      child: Container(
                        color: backgroundExists ? Colors.black.withOpacity(0) : null,
                        child: _buildContent(),
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
    return MouseRegion(
      onEnter: (_) => null,
      child: GestureDetector(
        onPanUpdate: (_) => windowManager.startDragging(),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            children: [
              const Spacer(),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _minimizeWindow,
                  ),
                  IconButton(
                    icon: Icon(
                      _isMaximized ? Icons.filter_none : Icons.crop_square,
                    ),
                    onPressed: _toggleMaximize,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _closeWindow,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildApplicationContent();
      case 1:
        return AllPage(
          desktopPath: _desktopPath,
          showHidden: _showHidden,
        );
      case 2:
        return FolderPage(
          desktopPath: _desktopPath,
          showHidden: _showHidden,
        );
      case 3:
        return FilePage(
          desktopPath: _desktopPath,
          showHidden: _showHidden,
        );
      case 4:
        return SettingsPage(
          opacity: _opacity,
          iconSize: _iconSize,
          crossAxisCount: _crossAxisCount,
          showHidden: _showHidden,
          autoRefresh: _autoRefresh,
          themeModeOption: _themeModeOption,
          backgroundPath: _backgroundImagePath,
          onOpacityChanged: (v) {
            setState(() => _opacity = v);
            windowManager.setOpacity(v);
          },
          onIconSizeChanged: (v) => setState(() => _iconSize = v),
          onCrossAxisCountChanged: (v) => setState(() => _crossAxisCount = v),
          onShowHiddenChanged: (v) => setState(() => _showHidden = v),
          onAutoRefreshChanged: (v) => setState(() => _autoRefresh = v),
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
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
                label: const Text('刷新'),
              ),
            ],
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
                        const crossAxisSpacing = 12.0;
                        const mainAxisSpacing = 16.0;
                        final usableWidth = constraints.maxWidth -
                            crossAxisSpacing * (_crossAxisCount - 1);
                        final cellWidth = usableWidth / _crossAxisCount;
                        final estimatedTextHeight = _estimateTextHeight();
                        final padding = math.max(8.0, _iconSize * 0.28);
                        final iconContainerSize =
                            math.max(28.0, _iconSize * 1.65);
                        final cardHeight = padding * 0.6 * 2 +
                            iconContainerSize +
                            padding * 0.6 +
                            estimatedTextHeight;
                        final aspectRatio =
                            cardHeight <= 0 ? 1 : cellWidth / cardHeight;

                        return GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _crossAxisCount,
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
