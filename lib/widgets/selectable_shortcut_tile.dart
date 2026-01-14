import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/shortcut_item.dart';
import '../models/icon_beautify_style.dart';
import '../widgets/beautified_icon.dart';

class SelectableShortcutTile extends StatelessWidget {
  final ShortcutItem shortcut;
  final double iconSize;
  final double scale;
  final bool selected;
  final VoidCallback onTap;
  final bool beautifyIcon;
  final IconBeautifyStyle beautifyStyle;

  const SelectableShortcutTile({
    super.key,
    required this.shortcut,
    required this.iconSize,
    required this.scale,
    required this.selected,
    required this.onTap,
    this.beautifyIcon = false,
    this.beautifyStyle = IconBeautifyStyle.cute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = math.max(8.0, iconSize * 0.28);
    final spec =
        iconBeautifyStyleSpec(beautifyStyle, theme.brightness);
    final labelColor = beautifyIcon && spec.labelColor != null
        ? spec.labelColor!
        : theme.textTheme.bodyMedium?.color ??
            theme.colorScheme.onSurface.withValues(alpha: 0.86);
    final iconContainerSize = math.max(28.0, iconSize * 1.65);
    final visualIconSize = math.max(12.0, iconContainerSize * 0.92);
    final radius = BorderRadius.circular(math.max(10.0, iconSize * 0.18));
    final baseBg = theme.colorScheme.surface.withValues(alpha: 0.12);
    final selectedBg = theme.colorScheme.primary.withValues(
      alpha: 0.14 + 0.04 * scale,
    );
    final borderColor = theme.colorScheme.primary.withValues(
      alpha: selected ? 0.28 : 0.16,
    );

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
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
                    child: beautifyIcon
                        ? _buildIcon(visualIconSize)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(
                              iconContainerSize * 0.22,
                            ),
                            child: _buildIcon(visualIconSize),
                          ),
                  ),
                  SizedBox(height: padding * 0.6),
                  Flexible(
                    child: Tooltip(
                      message: shortcut.name,
                      waitDuration: const Duration(milliseconds: 350),
                      child: Text(
                        shortcut.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: _textSize,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 6 * scale,
            top: 6 * scale,
            child: Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20 * scale,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(double visualIconSize) {
    final bytes = shortcut.iconData;
    return BeautifiedIcon(
      bytes: bytes,
      fallback: Icons.apps,
      size: visualIconSize,
      enabled: beautifyIcon,
      style: beautifyStyle,
      fit: BoxFit.cover,
    );
  }

  double get _textSize {
    final size = iconSize * 0.35;
    return math.max(10, math.min(18, size));
  }
}
