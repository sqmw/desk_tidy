import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../models/shortcut_item.dart';
import '../models/icon_beautify_style.dart';
import '../utils/desktop_helper.dart';
import '../widgets/beautified_icon.dart';
import '../models/system_items.dart';

class ShortcutCard extends StatefulWidget {
  final ShortcutItem shortcut;
  final double iconSize;
  final ValueListenable<bool>? windowFocusNotifier;
  final VoidCallback? onDeleted;
  final Future<void> Function(ShortcutItem shortcut, Offset position)?
  onCategoryMenuRequested;
  final bool beautifyIcon;
  final IconBeautifyStyle beautifyStyle;
  final VoidCallback? onLaunched;
  final bool isHighlighted; // 键盘导航高亮

  const ShortcutCard({
    super.key,
    required this.shortcut,
    this.iconSize = 32,
    this.windowFocusNotifier,
    this.onDeleted,
    this.onCategoryMenuRequested,
    this.beautifyIcon = false,
    this.beautifyStyle = IconBeautifyStyle.cute,
    this.onLaunched,
    this.isHighlighted = false,
  });

  @override
  State<ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<ShortcutCard> {
  OverlayEntry? _labelOverlay;
  bool _selected = false;
  bool _hovered = false;
  late final FocusNode _focusNode;
  final GlobalKey _labelTextKey = GlobalKey();
  ValueListenable<bool>? _windowFocusNotifier;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ShortcutCard');
    _updateWindowFocusNotifier(widget.windowFocusNotifier);
  }

  @override
  void didUpdateWidget(covariant ShortcutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windowFocusNotifier != widget.windowFocusNotifier) {
      _updateWindowFocusNotifier(widget.windowFocusNotifier);
    }
  }

  @override
  void dispose() {
    _removeLabelOverlay();
    _windowFocusNotifier?.removeListener(_onWindowFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _removeLabelOverlay() {
    _labelOverlay?.remove();
    _labelOverlay = null;
  }

  void _clearSelection() {
    if (!_selected || !mounted) return;
    setState(() => _selected = false);
    _removeLabelOverlay();
  }

  void _updateWindowFocusNotifier(ValueListenable<bool>? notifier) {
    if (_windowFocusNotifier == notifier) return;
    _windowFocusNotifier?.removeListener(_onWindowFocusChanged);
    _windowFocusNotifier = notifier;
    _windowFocusNotifier?.addListener(_onWindowFocusChanged);
  }

  void _onWindowFocusChanged() {
    if (_windowFocusNotifier?.value ?? true) return;
    _clearSelection();
  }

  void _toggleSelection() {
    setState(() => _selected = !_selected);
    if (_selected) _showLabelOverlay();
    if (!_selected) _removeLabelOverlay();
  }

  Future<void> _copyToClipboard(
    String raw, {
    required String label,
    required bool quoted,
  }) async {
    final value = quoted ? _quote(raw) : raw;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied $label')));
  }

  String _quote(String raw) => '"${raw.replaceAll('"', '\\"')}"';

  Future<void> _showShortcutMenu(Offset globalPosition) async {
    final shortcut = widget.shortcut;
    final resolvedPath = shortcut.targetPath.isNotEmpty
        ? shortcut.targetPath
        : shortcut.path;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: [
        const PopupMenuItem(
          value: 'open',
          child: ListTile(leading: Icon(Icons.open_in_new), title: Text('打开')),
        ),
        if (!shortcut.isSystemItem) ...[
          const PopupMenuItem(
            value: 'open_with',
            child: ListTile(
              leading: Icon(Icons.app_registration),
              title: Text('使用其他应用打开'),
            ),
          ),
          const PopupMenuItem(
            value: 'show_in_explorer',
            child: ListTile(
              leading: Icon(Icons.folder_open),
              title: Text('在文件资源管理器中显示'),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'categorize',
            child: ListTile(
              leading: Icon(Icons.bookmarks_outlined),
              title: Text('添加到分类'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete),
              title: Text('删除(回收站)'),
            ),
          ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'copy_name',
          child: ListTile(leading: Icon(Icons.copy), title: Text('复制名称')),
        ),
        if (!shortcut.isSystemItem) ...[
          const PopupMenuItem(
            value: 'copy_path',
            child: ListTile(leading: Icon(Icons.link), title: Text('复制路径')),
          ),
          const PopupMenuItem(
            value: 'copy_folder',
            child: ListTile(
              leading: Icon(Icons.folder),
              title: Text('复制所在文件夹'),
            ),
          ),
        ],
      ],
    );

    switch (result) {
      case 'open':
        if (shortcut.isSystemItem) {
          SystemItemInfo.open(shortcut.systemItemType!);
        } else {
          openWithDefault(resolvedPath);
        }
        widget.onLaunched?.call();
        break;
      case 'open_with':
        // Reuse internal method or prompt
        // Note: openWithApp is available in desktop_helper
        final picked = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: ['exe', 'bat', 'cmd', 'com', 'lnk'],
        );
        if (picked != null && picked.files.isNotEmpty) {
          final appPath = picked.files.single.path;
          if (appPath != null) {
            await openWithApp(appPath, resolvedPath);
          }
        }
        break;
      case 'show_in_explorer':
        await showInExplorer(shortcut.path);
        break;
      case 'categorize':
        await widget.onCategoryMenuRequested?.call(shortcut, globalPosition);
        break;
      case 'delete':
        final ok = moveToRecycleBin(shortcut.path);
        if (!mounted) break;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ok ? '已移动到回收站' : '删除失败')));
        if (ok) {
          widget.onDeleted?.call();
        }
        break;
      case 'copy_name':
        await _copyToClipboard(shortcut.name, label: 'name', quoted: false);
        break;
      case 'copy_path':
        await _copyToClipboard(resolvedPath, label: 'path', quoted: true);
        break;
      case 'copy_folder':
        await _copyToClipboard(
          path.dirname(resolvedPath),
          label: 'folder',
          quoted: true,
        );
        break;
      default:
        break;
    }
  }

  bool _isLabelOverflowing() {
    final ctx = _labelTextKey.currentContext;
    final renderObject = ctx?.findRenderObject();
    if (renderObject is! RenderBox) return false;

    final theme = Theme.of(context);
    final box = renderObject;
    final textMaxWidth = math.max(0.0, box.size.width);

    final painter = TextPainter(
      text: TextSpan(
        text: widget.shortcut.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: _textSize,
          height: 1.15,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: textMaxWidth);

    return painter.didExceedMaxLines;
  }

  void _showLabelOverlay() {
    _removeLabelOverlay();

    if (!_isLabelOverflowing()) return;

    final overlay = Overlay.of(context);
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;

    final name = widget.shortcut.name;
    final theme = Theme.of(context);
    final spec = iconBeautifyStyleSpec(widget.beautifyStyle, theme.brightness);
    final labelColor = widget.beautifyIcon && spec.labelColor != null
        ? spec.labelColor!
        : theme.textTheme.bodyMedium?.color ??
              theme.colorScheme.onSurface.withValues(alpha: 0.86);
    final labelShadowColor =
        widget.beautifyIcon && spec.labelShadowColor != null
        ? spec.labelShadowColor!
        : const Color(0xD6000000);

    _labelOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _clearSelection(),
                onPointerSignal: (_) => _clearSelection(),
              ),
            ),
            Positioned(
              left: topLeft.dx,
              top: topLeft.dy + size.height - 44,
              width: size.width,
              child: Material(
                type: MaterialType.transparency,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.max(140.0, size.width),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: _textSize,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                          shadows: [
                            Shadow(
                              color: labelShadowColor,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_labelOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.iconSize;
    final shortcut = widget.shortcut;
    final theme = Theme.of(context);
    final spec = iconBeautifyStyleSpec(widget.beautifyStyle, theme.brightness);
    final labelColor = widget.beautifyIcon && spec.labelColor != null
        ? spec.labelColor!
        : theme.textTheme.bodyMedium?.color ??
              theme.colorScheme.onSurface.withValues(alpha: 0.86);
    final labelShadowColor =
        widget.beautifyIcon && spec.labelShadowColor != null
        ? spec.labelShadowColor!
        : const Color(0xD6000000);

    final padding = math.max(8.0, iconSize * 0.28);
    final iconContainerSize = math.max(28.0, iconSize * 1.65);
    final visualIconSize = math.max(12.0, iconContainerSize * 0.92);

    final radius = BorderRadius.circular(math.max(10.0, iconSize * 0.18));
    final baseBg = theme.brightness == Brightness.dark
        ? const Color(0x10FFFFFF)
        : const Color(0x0A000000);
    final hoverBg = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.14,
    );
    final selectedBg = theme.colorScheme.primary.withValues(alpha: 0.08);
    final borderColor = theme.colorScheme.primary.withValues(alpha: 0.30);

    return Focus(
      focusNode: _focusNode,
      onFocusChange: (hasFocus) {
        if (!hasFocus && mounted) {
          setState(() => _selected = false);
          _removeLabelOverlay();
        }
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (details) {
            _focusNode.requestFocus();
            if (!_selected) _toggleSelection();
            _showShortcutMenu(details.globalPosition);
          },
          onDoubleTap: () {
            if (shortcut.isSystemItem) {
              SystemItemInfo.open(shortcut.systemItemType!);
            } else if (shortcut.targetPath.isNotEmpty) {
              openWithDefault(shortcut.targetPath);
            } else {
              openWithDefault(shortcut.path);
            }
            widget.onLaunched?.call();
          },
          onTap: () {
            _focusNode.requestFocus();
            _toggleSelection();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: (_selected || widget.isHighlighted)
                  ? selectedBg
                  : (_hovered ? hoverBg : baseBg),
              border: Border.all(
                color: (_selected || widget.isHighlighted)
                    ? borderColor
                    : Colors.transparent,
                width: widget.isHighlighted ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: padding * 0.6,
                horizontal: padding.toDouble(),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: iconContainerSize,
                    height: iconContainerSize,
                    child: widget.beautifyIcon
                        ? _buildIcon(context, visualIconSize.toDouble())
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(
                              iconContainerSize * 0.22,
                            ),
                            child: _buildIcon(
                              context,
                              visualIconSize.toDouble(),
                            ),
                          ),
                  ),
                  SizedBox(height: padding * 0.6),
                  Flexible(
                    child: Tooltip(
                      message: shortcut.name,
                      waitDuration: const Duration(milliseconds: 350),
                      child: Opacity(
                        opacity: _labelOverlay == null ? 1.0 : 0.0,
                        child: Text(
                          key: _labelTextKey,
                          shortcut.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: _textSize,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                            shadows: [
                              Shadow(
                                color: labelShadowColor,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, double visualIconSize) {
    final shortcut = widget.shortcut;
    final bytes = shortcut.iconData;
    if (bytes != null && bytes.isNotEmpty) {
      return BeautifiedIcon(
        bytes: bytes,
        fallback: Icons.apps,
        size: visualIconSize,
        enabled: widget.beautifyIcon,
        style: widget.beautifyStyle,
        fit: BoxFit.cover,
      );
    }
    if (shortcut.targetPath.isNotEmpty) {
      const requestSize = 256;
      return FutureBuilder<Uint8List?>(
        future: () async {
          final primary = await extractIconAsync(
            shortcut.path,
            size: requestSize,
          );
          if (primary != null && primary.isNotEmpty) return primary;
          return extractIconAsync(shortcut.targetPath, size: requestSize);
        }(),
        builder: (context, snapshot) {
          final buf = snapshot.data;
          if (buf != null && buf.isNotEmpty) {
            return BeautifiedIcon(
              bytes: buf,
              fallback: Icons.apps,
              size: visualIconSize,
              enabled: widget.beautifyIcon,
              style: widget.beautifyStyle,
              fit: BoxFit.contain,
            );
          }
          return BeautifiedIcon(
            bytes: null,
            fallback: Icons.apps,
            size: visualIconSize,
            enabled: widget.beautifyIcon,
            style: widget.beautifyStyle,
          );
        },
      );
    }
    return BeautifiedIcon(
      bytes: null,
      fallback: Icons.apps,
      size: visualIconSize,
      enabled: widget.beautifyIcon,
      style: widget.beautifyStyle,
    );
  }

  double get _textSize {
    final size = widget.iconSize * 0.35;
    return math.max(10, math.min(18, size));
  }
}
