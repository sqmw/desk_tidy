import 'package:flutter/material.dart';

import '../models/app_category.dart';

enum CategoryTabMenuAction { rename, delete, edit }

class CategoryStrip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final visible = categories.where((c) => c.paths.isNotEmpty).toList();
    final spacing = 8.0 * scale;
    return SizedBox(
      height: 44 * scale,
      child: Row(
        children: [
          _buildChip(
            context,
            name: '全部',
            count: totalCount,
            selected: activeCategoryId == null,
            onPressed: onAllSelected,
          ),
          if (visible.isNotEmpty) SizedBox(width: spacing),
          if (visible.isNotEmpty)
            Expanded(
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                padding: EdgeInsets.zero,
                onReorder: onReorder,
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final cat = visible[index];
                  final selected = activeCategoryId == cat.id;
                  final chip = _buildChip(
                    context,
                    name: cat.name,
                    count: cat.paths.length,
                    selected: selected,
                    onPressed: () => onCategorySelected(cat.id),
                  );
                  return Padding(
                    key: ValueKey(cat.id),
                    padding: EdgeInsets.only(right: spacing),
                    child: GestureDetector(
                      onSecondaryTapDown: _hasMenu
                          ? (details) async {
                              if (!selected) onCategorySelected(cat.id);
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
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  bool get _hasMenu =>
      onRenameRequested != null ||
      onDeleteRequested != null ||
      onEditRequested != null;

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
        onRenameRequested?.call(category);
        break;
      case CategoryTabMenuAction.delete:
        onDeleteRequested?.call(category);
        break;
      case CategoryTabMenuAction.edit:
        onEditRequested?.call(category);
        break;
      case null:
        break;
    }
  }

  double _chipLabelWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desired = width * 0.22;
    final min = 90.0 * scale;
    final max = 150.0 * scale;
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
    final baseColor = theme.colorScheme.surface.withValues(alpha: 0.10);
    final selectedColor = theme.colorScheme.primary.withValues(
      alpha: 0.12 + 0.05 * scale,
    );
    final borderColor = theme.colorScheme.onSurface.withValues(
      alpha: selected ? 0.12 : 0.08,
    );
    final textColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.86);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: textColor,
      fontWeight: FontWeight.w600,
    );
    return RawChip(
      showCheckmark: false,
      label: SizedBox(
        width: labelWidth,
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
      labelStyle: labelStyle,
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 6 * scale,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: StadiumBorder(side: BorderSide(color: borderColor, width: 1)),
      side: BorderSide.none,
      backgroundColor: baseColor,
      selectedColor: selectedColor,
      selected: selected,
      onPressed: onPressed,
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
        SizedBox(width: 4 * scale),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(countText, style: style, maxLines: 1, softWrap: false),
        ),
      ],
    );
  }
}
