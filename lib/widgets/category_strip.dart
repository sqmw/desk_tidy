import 'package:flutter/material.dart';

import '../models/app_category.dart';

class CategoryStrip extends StatelessWidget {
  final List<AppCategory> categories;
  final String? activeCategoryId;
  final int totalCount;
  final double scale;
  final VoidCallback onAllSelected;
  final ValueChanged<String> onCategorySelected;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback? onManageRequested;

  const CategoryStrip({
    super.key,
    required this.categories,
    required this.activeCategoryId,
    required this.totalCount,
    required this.scale,
    required this.onAllSelected,
    required this.onCategorySelected,
    required this.onReorder,
    this.onManageRequested,
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
            label: '全部 ($totalCount)',
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
                    label: '${cat.name} (${cat.paths.length})',
                    selected: selected,
                    onPressed: () => onCategorySelected(cat.id),
                  );
                  return Padding(
                    key: ValueKey(cat.id),
                    padding: EdgeInsets.only(right: spacing),
                    child: GestureDetector(
                      onLongPress: selected ? onManageRequested : null,
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

  double _chipLabelWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desired = width * 0.22;
    final min = 90.0 * scale;
    final max = 150.0 * scale;
    return desired.clamp(min, max);
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
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
    return RawChip(
      showCheckmark: false,
      label: SizedBox(
        width: labelWidth,
        child: Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 350),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
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
}
