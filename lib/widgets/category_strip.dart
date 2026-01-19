import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/app_category.dart';

enum CategoryTabMenuAction { rename, delete, edit }

class CategoryStrip extends StatefulWidget {
  final List<AppCategory> categories;
  final String? activeCategoryId;
  final int totalCount;
  final double scale;
  final VoidCallback onAllSelected;
  final ValueChanged<String> onCategorySelected;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<AppCategory>? onRenameRequested;
  final ValueChanged<AppCategory>? onDeleteRequested;
  final ValueChanged<AppCategory>? onEditRequested;

  const CategoryStrip({
    super.key,
    required this.categories,
    required this.activeCategoryId,
    required this.totalCount,
    required this.scale,
    required this.onAllSelected,
    required this.onCategorySelected,
    required this.onReorder,
    this.onRenameRequested,
    this.onDeleteRequested,
    this.onEditRequested,
  });

  @override
  State<CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<CategoryStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 处理滚轮事件，将垂直滚动转换为水平滚动
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final delta = event.scrollDelta.dy;
      final newOffset = (_scrollController.offset + delta).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(newOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.categories.where((c) => c.paths.isNotEmpty).toList();
    final spacing = 8.0 * widget.scale;
    return SizedBox(
      height: 44 * widget.scale,
      child: Row(
        children: [
          _buildChip(
            context,
            name: '全部',
            count: widget.totalCount,
            selected: widget.activeCategoryId == null,
            onPressed: widget.onAllSelected,
          ),
          if (visible.isNotEmpty) SizedBox(width: spacing),
          if (visible.isNotEmpty)
            Expanded(
              child: Listener(
                onPointerSignal: _handlePointerSignal,
                child: ReorderableListView.builder(
                  scrollController: _scrollController,
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  padding: EdgeInsets.zero,
                  onReorder: widget.onReorder,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final cat = visible[index];
                    final selected = widget.activeCategoryId == cat.id;
                    final chip = _buildChip(
                      context,
                      name: cat.name,
                      count: cat.paths.length,
                      selected: selected,
                      onPressed: () => widget.onCategorySelected(cat.id),
                    );
                    return Padding(
                      key: ValueKey(cat.id),
                      padding: EdgeInsets.only(right: spacing),
                      child: GestureDetector(
                        onSecondaryTapDown: _hasMenu
                            ? (details) async {
                                if (!selected) {
                                  widget.onCategorySelected(cat.id);
                                }
                                await _showCategoryTabMenu(
                                  context,
                                  category: cat,
                                  position: details.globalPosition,
                                );
                              }
                            : null,
                        child: ReorderableDragStartListener(
                          index: index,
                          child: chip,
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  bool get _hasMenu =>
      widget.onRenameRequested != null ||
      widget.onDeleteRequested != null ||
      widget.onEditRequested != null;

  Future<void> _showCategoryTabMenu(
    BuildContext context, {
    required AppCategory category,
    required Offset position,
  }) async {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final overlaySize = overlayBox?.size ?? const Size(1, 1);
    final menuPosition = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      overlaySize.width - position.dx,
      overlaySize.height - position.dy,
    );

    final action = await showMenu<CategoryTabMenuAction>(
      context: context,
      position: menuPosition,
      items: const [
        PopupMenuItem(
          value: CategoryTabMenuAction.rename,
          child: ListTile(
            leading: Icon(Icons.drive_file_rename_outline),
            title: Text('重命名'),
          ),
        ),
        PopupMenuItem(
          value: CategoryTabMenuAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('删除'),
          ),
        ),
        PopupMenuItem(
          value: CategoryTabMenuAction.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('编辑'),
          ),
        ),
      ],
    );

    switch (action) {
      case CategoryTabMenuAction.rename:
        widget.onRenameRequested?.call(category);
        break;
      case CategoryTabMenuAction.delete:
        widget.onDeleteRequested?.call(category);
        break;
      case CategoryTabMenuAction.edit:
        widget.onEditRequested?.call(category);
        break;
      case null:
        break;
    }
  }

  double _chipLabelWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desired = width * 0.22;
    final min = 90.0 * widget.scale;
    final max = 150.0 * widget.scale;
    return desired.clamp(min, max);
  }

  Widget _buildChip(
    BuildContext context, {
    required String name,
    required int count,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final labelWidth = _chipLabelWidth(context);
    // Unselected: transparent background, subtle border
    // Selected: translucent primary color background, primary border
    final borderColor = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.35)
        : theme.colorScheme.onSurface.withValues(alpha: 0.12);

    final textColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.85);

    // Selected text slightly bolder
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: textColor,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    // Use Material + InkWell for custom chip look with full control over background
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.15)
          : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: borderColor, width: 1)),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        child: Container(
          width: labelWidth,
          padding: EdgeInsets.symmetric(
            horizontal: 12 * widget.scale,
            vertical: 6 * widget.scale,
          ),
          child: Tooltip(
            message: '$name ($count)',
            waitDuration: const Duration(milliseconds: 350),
            child: _buildChipLabel(
              context,
              name: name,
              count: count,
              style: labelStyle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipLabel(
    BuildContext context, {
    required String name,
    required int count,
    required TextStyle? style,
  }) {
    final countText = '($count)';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            name,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(width: 4 * widget.scale),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(countText, style: style, maxLines: 1, softWrap: false),
        ),
      ],
    );
  }
}
