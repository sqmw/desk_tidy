import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../utils/desktop_helper.dart';
import '../models/icon_beautify_style.dart';
import '../widgets/entity_detail_bar.dart';
import '../widgets/beautified_icon.dart';
import '../widgets/floating_rename_overlay.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/glass.dart';
import '../widgets/middle_ellipsis_text.dart';
import '../widgets/operation_progress_bar.dart';
import '../models/file_item.dart';

/// 实体筛选模式
enum _EntityFilterMode { all, folders, files }

/// 排序模式
enum _SortType { name, date, size, type }

class AllPage extends StatefulWidget {
  final String desktopPath;
  final bool showHidden;
  final bool beautifyIcons;
  final IconBeautifyStyle beautifyStyle;

  const AllPage({
    super.key,
    required this.desktopPath,
    this.showHidden = false,
    this.beautifyIcons = false,
    this.beautifyStyle = IconBeautifyStyle.cute,
  });

  @override
  State<AllPage> createState() => _AllPageState();
}

class _EntitySelectionInfo {
  final String name;
  final String fullPath;
  final String folderPath;
  final FileSystemEntity entity;

  const _EntitySelectionInfo({
    required this.name,
    required this.fullPath,
    required this.folderPath,
    required this.entity,
  });
}

class _AllPageState extends State<AllPage> {
  String? _currentPath; // null means aggregate desktop roots
  bool _loading = true;
  String? _error;
  List<FileItem> _items = [];
  bool _entityMenuActive = false;

  // Search & Sort State
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  _SortType _sortType = _SortType.name;
  bool _sortAscending = true;
  _EntitySelectionInfo? _selected;
  bool _isDetailEditing = false;
  bool _showDetails = true; // New state for toggling details
  _EntityFilterMode _filterMode = _EntityFilterMode.all;
  final Map<String, Future<Uint8List?>> _iconFutures = {};

  /// 根据筛选模式过滤后的条目列表
  /// 根据筛选模式、搜索和排序过滤列表
  List<FileItem> get _filteredItems {
    // 1. 基础筛选
    List<FileItem> list;
    switch (_filterMode) {
      case _EntityFilterMode.folders:
        list = _items
            .where((e) => e.isDirectory && !e.name.startsWith('.'))
            .toList();
        break;
      case _EntityFilterMode.files:
        list = _items.where((e) {
          if (e.isDirectory) return false;
          final lower = e.name.toLowerCase();
          if (lower == 'desktop.ini' || lower == 'thumbs.db') return false;
          if (lower.endsWith('.lnk') || lower.endsWith('.exe')) return false;
          return true;
        }).toList();
        break;
      case _EntityFilterMode.all:
        list = List.of(_items);
        break;
    }

    // 2. 搜索逻辑
    if (_searchQuery.isNotEmpty) {
      final scored = <MapEntry<FileItem, int>>[];
      for (final item in list) {
        final result = item.searchIndex.matchWithScore(_searchQuery);
        if (result.matched) {
          scored.add(MapEntry(item, result.score));
        }
      }
      // 按分数降序排序
      scored.sort((a, b) => b.value.compareTo(a.value));
      return scored.map((e) => e.key).toList();
    }

    // 3. 常规排序
    list.sort((a, b) {
      // 文件夹始终置顶
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int cmp = 0;
      switch (_sortType) {
        case _SortType.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case _SortType.date:
          cmp = a.modified.compareTo(b.modified);
          break;
        case _SortType.size:
          cmp = a.size.compareTo(b.size);
          break;
        case _SortType.type:
          cmp = a.extension.compareTo(b.extension);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return list;
  }

  // Custom double-tap state
  int _lastTapTime = 0;
  String _lastTappedPath = '';
  final FocusNode _focusNode = FocusNode();
  final FloatingRenameOverlay _renameOverlay = FloatingRenameOverlay();

  @override
  void initState() {
    super.initState();
    _refresh();
    // Add global keyboard listener to debug Delete key
    HardwareKeyboard.instance.addHandler(_globalKeyHandler);
  }

  bool _globalKeyHandler(KeyEvent event) {
    if (event is KeyDownEvent) {
      debugPrint(
        '[Global] Key: ${event.logicalKey.keyLabel} (${event.logicalKey.keyId}) physical: ${event.physicalKey.debugName}',
      );
    }
    return false; // Don't consume the event
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_globalKeyHandler);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AllPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showHidden != widget.showHidden) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_renameOverlay.isActive) _renameOverlay.hide();
    setState(() {
      _loading = true;
      _error = null;
    });
    _iconFutures.clear();
    try {
      if (_currentPath == null) {
        final items = _loadAggregateRoots();
        setState(() {
          _items = items;
          _loading = false;
          if (_items.isNotEmpty && _selected == null) {
            final first = _items.first;
            final rawName = first.name;
            final displayName = rawName.toLowerCase().endsWith('.lnk')
                ? rawName.substring(0, rawName.length - 4)
                : rawName;
            _selected = _EntitySelectionInfo(
              name: displayName,
              fullPath: first.entity.path,
              folderPath: path.dirname(first.entity.path),
              entity: first.entity,
            );
          } else if (_items.isEmpty) {
            _selected = null;
          }
        });
      } else {
        final dir = Directory(_currentPath!);
        if (!dir.existsSync()) {
          setState(() {
            _items = [];
            _error = '路径不存在';
            _loading = false;
          });
          return;
        }

        final showHidden = widget.showHidden;
        final rawEntries = dir.listSync().where((entity) {
          final name = path.basename(entity.path);
          final lower = name.toLowerCase();
          if (!showHidden &&
              (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
            return false;
          }
          if (lower == 'desktop.ini' || lower == 'thumbs.db') return false;
          return true;
        });

        final items = rawEntries.map((e) => FileItem.fromEntity(e)).toList();

        setState(() {
          _items = items;
          _loading = false;
          if (_items.isNotEmpty && _selected == null) {
            final first = _items.first;
            final rawName = first.name;
            final displayName = rawName.toLowerCase().endsWith('.lnk')
                ? rawName.substring(0, rawName.length - 4)
                : rawName;
            _selected = _EntitySelectionInfo(
              name: displayName,
              fullPath: first.entity.path,
              folderPath: path.dirname(first.entity.path),
              entity: first.entity,
            );
          } else if (_items.isEmpty) {
            _selected = null;
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _items = [];
        _loading = false;
      });
    }
  }

  Future<Uint8List?> _getIconFuture(String path) {
    final key = path.toLowerCase();
    return _iconFutures.putIfAbsent(
      key,
      () => extractIconAsync(path, size: 96),
    );
  }

  List<FileItem> _loadAggregateRoots() {
    final directories = desktopLocations(widget.desktopPath);
    final seen = <String>{};
    final items = <FileItem>[];

    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync()) {
        if (!seen.add(entity.path)) continue;
        final name = path.basename(entity.path);
        final lower = name.toLowerCase();

        if (!widget.showHidden &&
            (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
          continue;
        }

        if (lower == 'desktop.ini' || lower == 'thumbs.db') {
          continue;
        }

        items.add(FileItem.fromEntity(entity));
      }
    }

    // Default sort by name for initial load (optional, as _filteredItems will sort)
    return items;
  }

  void _openFolder(String folderPath) {
    _currentPath = folderPath;
    _refresh();
  }

  void _goUp() {
    if (_currentPath == null) return;
    final parent = path.dirname(_currentPath!);
    if (parent == _currentPath) {
      _currentPath = null;
    } else {
      _currentPath = parent;
    }
    _refresh();
  }

  void _goHome() {
    _currentPath = null;
    _refresh();
  }

  Future<void> _showEntityMenu(
    FileSystemEntity entity,
    String displayName,
    Offset position,
  ) async {
    _entityMenuActive = true;
    final isDir = entity is Directory;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'open',
          child: ListTile(leading: Icon(Icons.open_in_new), title: Text('打开')),
        ),
        PopupMenuItem(
          value: 'open_with',
          child: ListTile(
            leading: Icon(Icons.app_registration),
            title: Text('使用其他应用打开'),
          ),
        ),
        PopupMenuItem(
          value: 'show_in_explorer',
          child: ListTile(
            leading: Icon(Icons.folder_open),
            title: Text('在文件资源管理器中显示'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'move',
          child: ListTile(
            leading: Icon(Icons.drive_file_move),
            title: Text('移动到..'),
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: ListTile(leading: Icon(Icons.copy), title: Text('复制到...')),
        ),
        PopupMenuItem(
          value: 'copy_clipboard',
          child: ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('复制到剪贴板(系统)'),
            trailing: Text(
              'Ctrl+C',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('重命名'),
            trailing: Text('F2', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('删除(回收站)'),
            trailing: Text('Del', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'copy_name',
          child: ListTile(leading: Icon(Icons.copy), title: Text('复制名称')),
        ),
        PopupMenuItem(
          value: 'copy_path',
          child: ListTile(leading: Icon(Icons.link), title: Text('复制路径')),
        ),
        PopupMenuItem(
          value: 'copy_folder',
          child: ListTile(leading: Icon(Icons.folder), title: Text('复制所在文件夹')),
        ),
      ],
    );

    switch (result) {
      case 'open':
        if (isDir) {
          _openFolder(entity.path);
        } else {
          await openWithDefault(entity.path);
        }
        break;
      case 'open_with':
        await _promptOpenWith(entity.path);
        break;
      case 'show_in_explorer':
        await showInExplorer(entity.path);
        break;
      case 'delete':
        _deleteEntity(entity);
        break;
      case 'move':
        _promptMove(entity);
        break;
      case 'copy':
        _promptCopy(entity);
        break;
      case 'copy_clipboard':
        final ok = copyEntityPathsToClipboard([entity.path]);
        if (mounted) {
          _showSnackBar(ok ? '已复制到剪贴板' : '复制到剪贴板失败');
        }
        break;
      case 'copy_name':
        await _copyToClipboard(displayName, label: 'name', quoted: false);
        break;
      case 'copy_path':
        await _copyToClipboard(entity.path, label: 'path', quoted: true);
        break;
      case 'copy_folder':
        await _copyToClipboard(
          path.dirname(entity.path),
          label: 'folder',
          quoted: true,
        );
        break;
      case 'rename':
        // 使用点击位置作为锚点
        final anchor = Rect.fromCenter(
          center: position,
          width: 200,
          height: 40,
        );
        _promptRename(entity, null, anchor);
        break;
      default:
        break;
    }
    _entityMenuActive = false;
  }

  void _selectEntity(FileSystemEntity entity, String displayName) {
    if (_renameOverlay.isActive) _renameOverlay.hide();
    setState(() {
      _selected = _EntitySelectionInfo(
        name: displayName,
        fullPath: entity.path,
        folderPath: path.dirname(entity.path),
        entity: entity,
      );
    });
  }

  Future<void> _copyToClipboard(
    String raw, {
    required String label,
    required bool quoted,
  }) async {
    final value = quoted ? _quote(raw) : raw;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showSnackBar('已复制 $label');
  }

  String _quote(String raw) => '"${raw.replaceAll('"', '\\"')}"';

  void _promptRename(
    FileSystemEntity entity, [
    BuildContext? anchorContext,
    Rect? overrideAnchorRect,
  ]) {
    final currentName = path.basename(entity.path);

    // 计算锚点位置
    Rect? anchorRect;

    // 1. 优先尝试通过 GlobalObjectKey 获取对应 Item 的 context（确保指向文件本身）
    final key = GlobalObjectKey(entity.path);
    final itemContext = key.currentContext;
    if (itemContext != null) {
      final renderBox = itemContext.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final topLeft = renderBox.localToGlobal(Offset.zero);
        anchorRect = Rect.fromLTWH(
          topLeft.dx,
          topLeft.dy,
          renderBox.size.width,
          renderBox.size.height,
        );
      }
    }

    // 2. 如果找不到 Item (例如未渲染)，尝试使用显式传入的锚点 (例如右键点击位置)
    if (anchorRect == null && overrideAnchorRect != null) {
      anchorRect = overrideAnchorRect;
    }

    // 3. 如果还是找不到，回退到屏幕中心
    if (anchorRect == null) {
      final size = MediaQuery.of(context).size;
      anchorRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 3),
        width: 300,
        height: 40,
      );
    }

    _renameOverlay.show(
      context: context,
      anchorRect: anchorRect!,
      currentName: currentName,
      onRename: (newName) async {
        if (newName == currentName) return;
        final parentDir = path.dirname(entity.path);
        final newPath = path.join(parentDir, newName);
        try {
          await entity.rename(newPath);
          _showSnackBar('已重命名为 $newName');
          _refresh();
        } catch (e) {
          _showSnackBar('重命名失败: $e');
        }
      },
    );
  }

  Future<void> _renameEntity(FileSystemEntity entity, String newName) async {
    if (newName.isEmpty) return;

    final oldPath = entity.path;
    final parent = path.dirname(oldPath);
    final ext = path.extension(oldPath);

    String finalName = newName;
    if (ext.toLowerCase() == '.lnk' &&
        !newName.toLowerCase().endsWith('.lnk')) {
      finalName = '$newName.lnk';
    } else if (ext.isNotEmpty &&
        !newName.toLowerCase().endsWith(ext.toLowerCase())) {
      finalName = '$newName$ext';
    }

    if (path.basename(oldPath) == finalName) return;

    final newPath = path.join(parent, finalName);

    try {
      await entity.rename(newPath);
      _showSnackBar('已重命名为 $newName');
      _refresh();
    } catch (e) {
      _showSnackBar('重命名失败: $e');
    }
  }

  // UI Helpers
  String _getSortLabel(_SortType type) {
    String label;
    switch (type) {
      case _SortType.name:
        label = '名称';
        break;
      case _SortType.date:
        label = '修改时间';
        break;
      case _SortType.size:
        label = '大小';
        break;
      case _SortType.type:
        label = '类型';
        break;
    }
    return '$label ${_sortAscending ? "↑" : "↓"}';
  }

  Widget _buildSortItem(String label, _SortType type) {
    final isSelected = _sortType == type;
    return Row(
      children: [
        Expanded(child: Text(label)),
        if (isSelected)
          Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }

  Widget _buildSelectionDetail() {
    final selected = _selected;
    if (selected == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: EntityDetailBar(
        name: selected.name,
        path: selected.fullPath,
        folderPath: selected.folderPath,
        onCopyName: () =>
            _copyToClipboard(selected.name, label: 'name', quoted: false),
        onCopyPath: () =>
            _copyToClipboard(selected.fullPath, label: 'path', quoted: true),
        onCopyFolder: () => _copyToClipboard(
          selected.folderPath,
          label: 'folder',
          quoted: true,
        ),
        onRename: (newName) => _renameEntity(selected.entity, newName),
        onEditingChanged: (editing) =>
            setState(() => _isDetailEditing = editing),
      ),
    );
  }

  Future<void> _showPageMenu(Offset position) async {
    if (_entityMenuActive) return;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'new_folder',
          child: ListTile(
            leading: Icon(Icons.create_new_folder),
            title: Text('新建文件夹'),
          ),
        ),
        PopupMenuItem(
          value: 'refresh',
          child: ListTile(leading: Icon(Icons.refresh), title: Text('刷新')),
        ),
        PopupMenuItem(
          value: 'paste',
          child: ListTile(
            leading: const Icon(Icons.paste),
            title: const Text('粘贴'),
            trailing: Text(
              'Ctrl+V',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );

    switch (result) {
      case 'new_folder':
        _promptNewFolder();
        break;
      case 'refresh':
        _refresh();
        break;
      case 'paste':
        await _handlePaste();
        break;
      default:
        break;
    }
  }

  Future<void> _handlePaste() async {
    final files = getClipboardFilePaths();
    if (files.isEmpty) {
      _showSnackBar('剪贴板中没有文件');
      return;
    }

    final targetDir =
        _currentPath ??
        widget
            .desktopPath; // Paste to root desktop if _currentPath is null (All view)
    // Wait, _currentPath null means "Aggregate desktop roots".
    // If I paste, where should it go?
    // User says "All's first layer belongs to desktop folder is also a folder".
    // So pasting to widget.desktopPath (primary desktop) is a reasonable default.

    int successCount = 0;
    for (final srcPath in files) {
      // Auto-rename logic? Or just fail if exists?
      // User didn't specify. Standard explorer behavior is to copy.
      // copyEntityToDirectory handles overwrite checks (returns success: false).
      // Let's rely on copyEntityToDirectory's checks.

      final result = await copyEntityToDirectory(srcPath, targetDir);
      if (result.success) {
        successCount++;
      }
    }

    if (successCount > 0) {
      _showSnackBar('已粘贴 $successCount 个项目');
      _refresh();
    } else {
      _showSnackBar('粘贴失败 (可能目标已存在或文件不可读)');
    }
  }

  Future<void> _promptNewFolder() async {
    final controller = TextEditingController(text: '新建文件夹');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建文件夹'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '名称'),
            onSubmitted: (_) => Navigator.of(context).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;

    final base = _currentPath ?? widget.desktopPath;
    final created = await createNewFolder(base, preferredName: name);

    if (created != null) {
      _showSnackBar('已创建 ${path.basename(created)}');
      _refresh();
    } else {
      _showSnackBar('创建失败', success: false);
    }
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    final fileName = path.basename(entity.path);
    final success = moveToRecycleBin(entity.path);
    if (!mounted) return;
    if (success) {
      _showSnackBar('已移动至回收站: $fileName');
      setState(() => _selected = null);
      _refresh();
    } else {
      _showSnackBar('删除失败', success: false);
    }
  }

  Future<void> _promptMove(FileSystemEntity entity) async {
    final initial = _currentPath ?? path.dirname(entity.path);
    final targetDir = await showFolderPicker(
      context: context,
      initialPath: initial,
      showHidden: widget.showHidden,
    );
    if (targetDir == null || targetDir.isEmpty) return;
    final dest = path.join(targetDir, path.basename(entity.path));

    try {
      final dir = Directory(targetDir);
      if (!dir.existsSync()) {
        _showSnackBar('目标路径不存在');

        return;
      }
      if (File(dest).existsSync() || Directory(dest).existsSync()) {
        _showSnackBar('目标已存在同名项');
        return;
      }
      await entity.rename(dest);
      _showSnackBar('已移动到 $dest');
      _refresh();
    } catch (e) {
      _showSnackBar('移动失败: $e');
    }
  }

  Future<void> _promptCopy(FileSystemEntity entity) async {
    final initial = _currentPath ?? path.dirname(entity.path);
    final targetDir = await showFolderPicker(
      context: context,
      initialPath: initial,
      showHidden: widget.showHidden,
    );
    if (targetDir == null || targetDir.isEmpty) return;

    final result = await copyEntityToDirectory(entity.path, targetDir);
    if (!mounted) return;
    if (result.success) {
      _showSnackBar('已复制到 ${result.destPath}');
      _refresh();
    } else {
      _showSnackBar('复制失败: ${result.message ?? 'unknown'}');
    }
  }

  Future<void> _promptOpenWith(String targetPath) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['exe', 'bat', 'cmd', 'com', 'lnk'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final appPath = picked.files.single.path;
    if (appPath == null || appPath.isEmpty) return;
    await openWithApp(appPath, targetPath);
  }

  void _showSnackBar(String message, {bool success = true}) {
    OperationManager.instance.quickTask(message, success: success);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final pathLabel = _currentPath ?? '${widget.desktopPath} (合并视图)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            opacity: 0.14,
            blurSigma: 10,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: const Icon(Icons.home),
                  onPressed: _currentPath == null ? null : _goHome,
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _currentPath == null ? null : _goUp,
                ),
                Expanded(
                  child: Text(
                    pathLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            ),
          ),
        ),

        // Search & Filter Bar (Glass Style)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            opacity: 0.14,
            blurSigma: 10,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.16),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: '搜索...',
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: Theme.of(
                          context,
                        ).iconTheme.color?.withValues(alpha: 0.7),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  height: 24,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),

                // Sort Button
                PopupMenuButton<_SortType>(
                  tooltip: '排序: ${_getSortLabel(_sortType)}',
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.sort,
                      size: 20,
                      color: Theme.of(
                        context,
                      ).iconTheme.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  initialValue: _sortType,
                  onSelected: (type) {
                    if (_sortType == type) {
                      setState(() => _sortAscending = !_sortAscending);
                    } else {
                      setState(() {
                        _sortType = type;
                        _sortAscending = true;
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _SortType.name,
                      child: _buildSortItem('名称', _SortType.name),
                    ),
                    PopupMenuItem(
                      value: _SortType.date,
                      child: _buildSortItem('修改时间', _SortType.date),
                    ),
                    PopupMenuItem(
                      value: _SortType.size,
                      child: _buildSortItem('大小', _SortType.size),
                    ),
                    PopupMenuItem(
                      value: _SortType.type,
                      child: _buildSortItem('类型', _SortType.type),
                    ),
                  ],
                ),
                // Toggle Details Button
                if (_selected != null)
                  IconButton(
                    icon: Icon(
                      _showDetails ? Icons.info : Icons.info_outline,
                      size: 20,
                      color: _showDetails
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).iconTheme.color?.withValues(alpha: 0.7),
                    ),
                    tooltip: _showDetails ? '隐藏详情' : '显示详情',
                    onPressed: () =>
                        setState(() => _showDetails = !_showDetails),
                  ),
              ],
            ),
          ),
        ),

        // Filter Segmented Button (Restored)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_EntityFilterMode>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _EntityFilterMode.all, label: Text('全部')),
                ButtonSegment(
                  value: _EntityFilterMode.folders,
                  label: Text('文件夹'),
                ),
                ButtonSegment(
                  value: _EntityFilterMode.files,
                  label: Text('文件'),
                ),
              ],
              selected: {_filterMode},
              onSelectionChanged: (newSelection) {
                setState(() => _filterMode = newSelection.first);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Split View: List | Details (Responsive)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final showDetailsPanel = _selected != null && _showDetails;

              // Extract the list widget to reuse
              Widget buildList() {
                return _filteredItems.isEmpty
                    ? const Center(child: Text('未找到文件或快捷方式'))
                    : ListView.builder(
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final entity = item.entity;
                          final isDir = item.isDirectory;
                          final displayName =
                              item.name.toLowerCase().endsWith('.lnk')
                              ? item.name.substring(0, item.name.length - 4)
                              : item.name;
                          final isSelected = _selected?.fullPath == entity.path;
                          return Material(
                            key: GlobalObjectKey(entity.path),
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            child: InkWell(
                              onTapDown: (_) {
                                _selectEntity(entity, displayName);
                                if (_focusNode.canRequestFocus) {
                                  _focusNode.requestFocus();
                                }
                              },
                              onTap: () {
                                final now =
                                    DateTime.now().millisecondsSinceEpoch;
                                if (now - _lastTapTime < 300 &&
                                    _lastTappedPath == entity.path) {
                                  // Double tap confirmed
                                  if (isDir) {
                                    _openFolder(entity.path);
                                  } else {
                                    openWithDefault(entity.path);
                                  }
                                  _lastTapTime = 0;
                                } else {
                                  // Single tap
                                  _lastTapTime = now;
                                  _lastTappedPath = entity.path;
                                }
                              },
                              onSecondaryTapDown: (details) {
                                _selectEntity(entity, displayName);
                                _focusNode.requestFocus();
                                _showEntityMenu(
                                  entity,
                                  displayName,
                                  details.globalPosition,
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              hoverColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                leading: _EntityIcon(
                                  entity: entity,
                                  getIconFuture: _getIconFuture,
                                  beautifyIcon: widget.beautifyIcons,
                                  beautifyStyle: widget.beautifyStyle,
                                ),
                                title: Tooltip(
                                  message: displayName,
                                  child: Text(
                                    displayName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                subtitle: Tooltip(
                                  message: entity.path,
                                  child: MiddleEllipsisText(
                                    text: entity.path,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                trailing: null,
                              ),
                            ),
                          );
                        },
                      );
              }

              // Details Widget
              Widget buildDetails() {
                if (!showDetailsPanel) return const SizedBox.shrink();
                return SizedBox(
                  width: isWide
                      ? (constraints.maxWidth * 0.45 > 320
                            ? 320
                            : constraints.maxWidth * 0.45)
                      : double.infinity,
                  child: SingleChildScrollView(child: _buildSelectionDetail()),
                );
              }

              // Focus wrapper for keyboard events
              final focusWrapper = Focus(
                focusNode: _focusNode,
                autofocus: true,
                onKeyEvent: (node, event) {
                  // Key handling logic reused from previous implementation
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;

                  final isCtrl = HardwareKeyboard.instance.isControlPressed;

                  if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC) {
                    final s = _selected;
                    if (s != null) {
                      copyEntityPathsToClipboard([s.fullPath]);
                      _showSnackBar('已复制到剪贴板');
                      return KeyEventResult.handled;
                    }
                  }
                  if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyV) {
                    _handlePaste();
                    return KeyEventResult.handled;
                  }

                  if (_isDetailEditing) return KeyEventResult.ignored;

                  final focus = FocusManager.instance.primaryFocus;
                  final isEditing =
                      focus != null &&
                      focus.context != null &&
                      focus.context!.widget is EditableText;
                  if (isEditing) return KeyEventResult.ignored;

                  if (event.logicalKey == LogicalKeyboardKey.delete ||
                      event.logicalKey == LogicalKeyboardKey.backspace ||
                      event.logicalKey == LogicalKeyboardKey.numpadDecimal) {
                    final s = _selected;
                    if (s != null) {
                      _deleteEntity(File(s.fullPath));
                      return KeyEventResult.handled;
                    }
                  }
                  if (event.logicalKey == LogicalKeyboardKey.f2) {
                    final s = _selected;
                    if (s != null) {
                      final entity = File(s.fullPath).existsSync()
                          ? File(s.fullPath) as FileSystemEntity
                          : Directory(s.fullPath);
                      final key = GlobalObjectKey(s.fullPath);
                      final itemContext = key.currentContext;
                      _promptRename(entity, itemContext);
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onSecondaryTapDown: (details) =>
                      _showPageMenu(details.globalPosition),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: buildList()),
                            buildDetails(),
                          ],
                        )
                      : Column(
                          children: [
                            buildDetails(),
                            Expanded(child: buildList()),
                          ],
                        ),
                ),
              );

              return focusWrapper;
            },
          ),
        ),
      ],
    );
  }
}

class _EntityIcon extends StatelessWidget {
  final FileSystemEntity entity;
  final Future<Uint8List?> Function(String path) getIconFuture;
  final bool beautifyIcon;
  final IconBeautifyStyle beautifyStyle;

  const _EntityIcon({
    required this.entity,
    required this.getIconFuture,
    required this.beautifyIcon,
    required this.beautifyStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (entity is Directory) {
      return BeautifiedIcon(
        bytes: null,
        fallback: Icons.folder,
        size: 32,
        enabled: beautifyIcon,
        style: beautifyStyle,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _resolveIconBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty) {
          return BeautifiedIcon(
            bytes: snapshot.data,
            fallback: Icons.apps,
            size: 32,
            enabled: beautifyIcon,
            style: beautifyStyle,
          );
        }
        final ext = path.extension(entity.path).toLowerCase();
        final icon = ['.exe', '.lnk', '.url', '.appref-ms'].contains(ext)
            ? Icons.apps
            : Icons.insert_drive_file;
        return BeautifiedIcon(
          bytes: null,
          fallback: icon,
          size: 32,
          enabled: beautifyIcon,
          style: beautifyStyle,
        );
      },
    );
  }

  Future<Uint8List?> _resolveIconBytes() async {
    final ext = path.extension(entity.path).toLowerCase();
    final primary = await getIconFuture(entity.path);
    if (primary != null && primary.isNotEmpty) return primary;
    if (ext == '.lnk') {
      final target = getShortcutTarget(entity.path);
      if (target != null && target.isNotEmpty) {
        final targetIcon = await getIconFuture(target);
        if (targetIcon != null && targetIcon.isNotEmpty) return targetIcon;
      }
    }
    return null;
  }
}
