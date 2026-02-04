import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../utils/desktop_helper.dart';
import 'glass.dart';
import 'video_preview_widget.dart';

class EntityDetailBar extends StatefulWidget {
  final String name;
  final String path;
  final String folderPath;
  final VoidCallback? onCopyName;
  final VoidCallback? onCopyPath;
  final VoidCallback? onCopyFolder;
  final ValueChanged<String>? onRename;
  final ValueChanged<bool>? onEditingChanged;

  const EntityDetailBar({
    super.key,
    required this.name,
    required this.path,
    required this.folderPath,
    this.onCopyName,
    this.onCopyPath,
    this.onCopyFolder,
    this.onRename,
    this.onEditingChanged,
  });

  @override
  State<EntityDetailBar> createState() => _EntityDetailBarState();
}

class _EntityDetailBarState extends State<EntityDetailBar> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // Debug Log
        debugPrint(
          '[EntityDetailBar] Key: ${event.logicalKey.keyLabel} (${event.logicalKey.keyId})',
        );

        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _cancelEditing();
          return KeyEventResult.handled;
        }

        // [Fix] Enter 键保存 (Shift+Enter 允许换行，但文件名不能有换行符，直接忽略)
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          _saveEditing();
          return KeyEventResult.handled;
        }

        // [Fix] 手动处理 Delete 键 (包括小键盘 Delete)
        if (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.numpadDecimal) {
          final text = _controller.text;
          final selection = _controller.selection;
          // 如果有选区，删除选区
          if (!selection.isCollapsed) {
            final newText = text.replaceRange(
              selection.start,
              selection.end,
              '',
            );
            _controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: selection.start),
            );
            return KeyEventResult.handled;
          }
          // 如果无选区，删除光标后一个字符
          if (selection.baseOffset < text.length) {
            final newText = text.replaceRange(
              selection.baseOffset,
              selection.baseOffset + 1,
              '',
            );
            _controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: selection.baseOffset),
            );
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void didUpdateWidget(EntityDetailBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      _controller.text = widget.name;
      _isEditing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onEditingChanged?.call(false);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (widget.onRename == null) return;
    setState(() => _isEditing = true);
    widget.onEditingChanged?.call(true);
    _focusNode.requestFocus();
    // 选中文件名（不包括扩展名）
    final dotIndex = widget.name.lastIndexOf('.');
    if (dotIndex > 0) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: dotIndex,
      );
    } else {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.name.length,
      );
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _controller.text = widget.name;
    });
    widget.onEditingChanged?.call(false);
  }

  void _saveEditing() {
    final newName = _controller.text.trim();
    if (newName.isEmpty || newName == widget.name) {
      _cancelEditing();
      return;
    }
    widget.onRename?.call(newName);
    setState(() => _isEditing = false);
    widget.onEditingChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium;

    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      opacity: 0.14,
      blurSigma: 10,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Details', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                // 名称区域：可编辑
                _buildNameField(theme),
                const SizedBox(height: 6),
                Text('Path', style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                SelectableText(widget.path, style: textStyle),
                const SizedBox(height: 6),
                SelectableText(
                  widget.folderPath,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _buildPreview(context),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: widget.onCopyName,
              ),
              IconButton(
                icon: const Icon(Icons.link),
                onPressed: widget.onCopyPath,
              ),
              IconButton(
                icon: const Icon(Icons.folder),
                onPressed: widget.onCopyFolder,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    // Check extension
    final ext = path.extension(widget.path).toLowerCase();
    final imageExts = {'.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp'};
    final videoExts = {
      '.mp4',
      '.mkv',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.m4v',
      '.mpg',
      '.mpeg',
      '.3gp',
    };

    if (imageExts.contains(ext)) {
      return InkWell(
        onTap: () => openWithDefault(widget.path),
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 200),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.black12,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(widget.path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      );
    } else if (videoExts.contains(ext)) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 200),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.black12,
        ),
        clipBehavior: Clip.antiAlias,
        child: VideoPreviewWidget(
          path: widget.path,
          onError: (context, error) {
            // Fallback to thumbnail logic if video player fails
            return FutureBuilder<Uint8List?>(
              future: extractIconAsync(widget.path, size: 256),
              builder: (context, snapshot) {
                if (snapshot.hasData &&
                    snapshot.data != null &&
                    snapshot.data!.isNotEmpty) {
                  return InkWell(
                    onTap: () => openWithDefault(widget.path),
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.passthrough,
                      children: [
                        Image.memory(snapshot.data!, fit: BoxFit.contain),
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const Center(child: Icon(Icons.movie));
              },
            );
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildNameField(ThemeData theme) {
    if (_isEditing) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              maxLines: null, // 完全自适应行数
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _saveEditing(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.check, size: 20),
            onPressed: _saveEditing,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _cancelEditing,
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }

    // 非编辑状态：显示名称，点击进入编辑
    return GestureDetector(
      onTap: _startEditing,
      child: MouseRegion(
        cursor: widget.onRename != null
            ? SystemMouseCursors.text
            : SystemMouseCursors.basic,
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (widget.onRename != null)
              Icon(
                Icons.edit,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }
}
