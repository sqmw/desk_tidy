import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/shortcut_item.dart';

class SelectableShortcutTile extends StatelessWidget {
  final ShortcutItem shortcut;
  final double iconSize;
  final double scale;
  final bool selected;
  final VoidCallback onTap;

  const SelectableShortcutTile({
    super.key,
    required this.shortcut,
    required this.iconSize,
    required this.scale,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = math.max(8.0, iconSize * 0.28);
    final iconContainerSize = math.max(28.0, iconSize * 1.65);
    final visualIconSize = math.max(12.0, iconContainerSize * 0.92);
    final radius = BorderRadius.circular(math.max(10.0, iconSize * 0.18));
    final baseBg = theme.colorScheme.surface.withValues(alpha: 0.12);
    final selectedBg =
        theme.colorScheme.primary.withValues(alpha: 0.14 + 0.04 * scale);
    final borderColor =
        theme.colorScheme.primary.withValues(alpha: selected ? 0.28 : 0.16);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: selected ? selectedBg : baseBg,
              border: Border.all(color: borderColor, width: selected ? 1.3 : 1),
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
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(iconContainerSize * 0.22),
                      child: _buildIcon(visualIconSize),
                    ),
                  ),
                  SizedBox(height: padding * 0.6),
                  Flexible(
                    child: Text(
                      shortcut.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: _textSize,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 6 * scale,
            top: 6 * scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surface.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(2.4 * scale),
              child: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18 * scale,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(double visualIconSize) {
    final bytes = shortcut.iconData;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        width: visualIconSize,
        height: visualIconSize,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );
    }
    return Icon(
      Icons.apps,
      size: visualIconSize,
      color: Colors.grey,
    );
  }

  double get _textSize {
    final size = iconSize * 0.35;
    return math.max(10, math.min(18, size));
  }
}
