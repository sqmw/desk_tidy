import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart'; // 导入 window_manager
import '../main.dart';
import '../models/shortcut_item.dart';
import '../setting/settings_page.dart';
import '../utils/desktop_helper.dart';
import '../widgets/shortcut_card.dart';
import 'file_page.dart';
import 'folder_page.dart'; // 确保导入该包

ThemeModeOption _themeModeOption = ThemeModeOption.system;
bool _showHidden = false;
bool _autoRefresh = false;
double _iconSize = 48; // 默认图标大小
int _crossAxisCount = 6; // 默认每行数量
double _opacity = 1.0;

class DeskTidyHomePage extends StatefulWidget {
  const DeskTidyHomePage({super.key});

  @override
  State<DeskTidyHomePage> createState() => _DeskTidyHomePageState();
}

class _DeskTidyHomePageState extends State<DeskTidyHomePage> {
  List<ShortcutItem> _shortcuts = [];
  String _desktopPath = '';
  bool _isLoading = true;
  bool _isMaximized = false; // 标记窗口是否最大化
  double _opacity = 1.0; // 默认不透明

  int _selectedIndex = 0; // 默认选中 "应用"

  @override
  void initState() {
    super.initState();
    windowManager.ensureInitialized();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // 进入沉浸模式
    _loadShortcuts();
  }

  Future<void> _loadShortcuts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final desktopPath = await getDesktopPath(); // 获取桌面路径
      _desktopPath = desktopPath;
      final shortcutsPaths = await scanDesktopShortcuts(
        desktopPath,
        showHidden: _showHidden, // 把设置页的变量传进来
      );
      setState(() {
        _shortcuts = shortcutsPaths
            .map(
              (path) => ShortcutItem(
                name: path
                    .split('\\')
                    .last
                    .replaceAll('.lnk', ''), // 从路径提取快捷方式名称
                path: path,
                iconPath: '', // 可以根据需要设置图标路径
                description: '桌面快捷方式',
              ),
            )
            .toList();
        _isLoading = false;
      });

      // 打印加载的快捷方式数量
      print('加载的快捷方式数量: ${_shortcuts.length}');
    } catch (e) {
      print('加载快捷方式失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleMaximize() {
    if (_isMaximized) {
      windowManager.restore(); // 恢复窗口
    } else {
      windowManager.maximize(); // 最大化窗口
    }
    setState(() {
      _isMaximized = !_isMaximized;
    });
  }

  void _minimizeWindow() {
    windowManager.minimize(); // 最小化窗口
  }

  void _closeWindow() {
    windowManager.close(); // 关闭窗口
  }

  void _onNavigationRailItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _changeOpacity(double opacity) {
    setState(() {
      _opacity = opacity;
    });
    windowManager.setOpacity(opacity); // 设置窗口透明度
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 自定义标题栏
          MouseRegion(
            onEnter: (_) => print("Mouse Entered"),
            child: GestureDetector(
              onPanUpdate: (details) {
                // 拖动窗口
                windowManager.startDragging();
              },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  // 使用跟整体背景一致的颜色
                  color: Theme.of(context).scaffoldBackgroundColor,

                  // 加一点下边框分隔线，不是整块阴影
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 0.8,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // 左侧标题
                    Text(
                      '桌面整理工具',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    Row(
                      children: [
                        // 最小化
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () async {
                            await windowManager.minimize();
                          },
                        ),
                        // 最大化/还原
                        IconButton(
                          icon: const Icon(Icons.crop_square),
                          onPressed: () async {
                            bool isMax = await windowManager.isMaximized();
                            if (isMax) {
                              await windowManager.unmaximize();
                            } else {
                              await windowManager.maximize();
                            }
                          },
                        ),
                        // 关闭
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            windowManager.close();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // 左侧导航面板
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onNavigationRailItemSelected,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.apps),
                      label: Text('应用'),
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
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // 中间主要内容区域
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 根据 selectedIndex 显示不同的内容
  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildApplicationContent();
      case 1:
        return FolderPage(desktopPath: _desktopPath);
      case 2:
        return FilePage(desktopPath: _desktopPath);
      case 3:
        return SettingsPage(
          opacity: _opacity,
          iconSize: _iconSize,
          crossAxisCount: _crossAxisCount,
          showHidden: _showHidden,
          autoRefresh: _autoRefresh,
          themeModeOption: _themeModeOption,
          onOpacityChanged: (v) {
            setState(() => _opacity = v);
            windowManager.setOpacity(v);
          },
          onIconSizeChanged: (v) => setState(() => _iconSize = v),
          onCrossAxisCountChanged: (v) => setState(() => _crossAxisCount = v),
          onShowHiddenChanged: (v) => setState(() => _showHidden = v),
          onAutoRefreshChanged: (v) => setState(() => _autoRefresh = v),
          onThemeModeChanged: (v) => setState(() => _themeModeOption = v!),
        );
      default:
        return _buildApplicationContent();
    }
  }

  // 应用列表显示
  Widget _buildApplicationContent() {
    return Column(
      children: [
        // 顶部工具栏
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
                onPressed: () {
                  // 刷新列表
                  _loadShortcuts();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
            ],
          ),
        ),
        // 应用图标网格视图
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
                      Text(
                        '未找到桌面快捷方式',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '桌面路径: $_desktopPath',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = (constraints.maxWidth / 120).floor();
                    crossAxisCount = crossAxisCount < 4
                        ? 4
                        : crossAxisCount; // 最少显示 4 列

                    return GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 140, // ❗ 每个格子的最大宽度
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1, // 如果你想让长宽一样
                      ),
                      itemCount: _shortcuts.length,
                      itemBuilder: (context, index) {
                        return ShortcutCard(shortcut: _shortcuts[index]);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
