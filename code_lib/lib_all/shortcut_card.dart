import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/shortcut_item.dart';
import '../utils/desktop_helper.dart';

class ShortcutCard extends StatefulWidget {
  final ShortcutItem shortcut;
  final double iconSize;

  const ShortcutCard({
    super.key,
    required this.shortcut,
    this.iconSize = 32,
  });

  @override
  State<ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<ShortcutCard> {
  OverlayEntry? _labelOverlay;
  bool _selected = false;
  bool _hovered = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ShortcutCard');
  }

  @override
  void dispose() {
    _removeLabelOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _removeLabelOverlay() {
    _labelOverlay?.remove();
    _labelOverlay = null;
  }

  void _toggleSelection() {
    setState(() => _selected = !_selected);
    if (_selected) _showLabelOverlay();
    if (!_selected) _removeLabelOverlay();
  }

  void _showLabelOverlay() {
    _removeLabelOverlay();

    final overlay = Overlay.of(context);
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;

    final name = widget.shortcut.name;
    final theme = Theme.of(context);
    final padding = math.max(8.0, widget.iconSize * 0.28);
    // Keep this in sync with the actual label widget width (padding etc),
    // otherwise we may incorrectly think text fits and never show the overlay.
    const labelHorizontalPadding = 6.0 * 2;
    final textMaxWidth =
        math.max(0.0, size.width - padding * 2 - labelHorizontalPadding);

    final testPainter = TextPainter(
      text: TextSpan(
        text: name,
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

    if (!testPainter.didExceedMaxLines) return;

    final overlayBg = theme.brightness == Brightness.dark
        ? const Color(0x7A000000)
        : const Color(0xB3FFFFFF);

    _labelOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  if (!mounted) return;
                  setState(() => _selected = false);
                  _removeLabelOverlay();
                },
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: overlayBg,
                        borderRadius: BorderRadius.circular(10),
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
                            shadows: const [
                              Shadow(
                                color: Color(0xB3000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
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

    final padding = math.max(8.0, iconSize * 0.28);
    final iconContainerSize = math.max(28.0, iconSize * 1.65);
    final visualIconSize = math.max(12.0, iconContainerSize * 0.92);

    final radius = BorderRadius.circular(math.max(10.0, iconSize * 0.18));
    final baseBg = theme.brightness == Brightness.dark
        ? const Color(0x12FFFFFF)
        : const Color(0x0F000000);
    final hoverBg = theme.colorScheme.surfaceVariant.withOpacity(0.22);
    final selectedBg = theme.colorScheme.primary.withOpacity(0.10);
    final borderColor = theme.colorScheme.primary.withOpacity(0.38);
    final labelBg = theme.brightness == Brightness.dark
        ? const Color(0x6A000000)
        : const Color(0xB3FFFFFF);

    return Focus(
      focusNode: _focusNode,
      onFocusChange: (hasFocus) {
        if (!hasFocus && mounted) {
          setState(() => _selected = false);
          _removeLabelOverlay();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onHover: (v) => setState(() => _hovered = v),
          onDoubleTap: () {
            if (shortcut.targetPath.isNotEmpty) {
              openWithDefault(shortcut.targetPath);
            } else {
              openWithDefault(shortcut.path);
            }
          },
          onTap: () {
            _focusNode.requestFocus();
            _toggleSelection();
          },
          borderRadius: radius,
          hoverColor: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: _selected ? selectedBg : (_hovered ? hoverBg : baseBg),
              border: Border.all(
                color: _selected ? borderColor : Colors.transparent,
                width: 1,
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
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(iconContainerSize * 0.22),
                      child: _buildIcon(context, visualIconSize.toDouble()),
                    ),
                  ),
                  SizedBox(height: padding * 0.6),
                  Flexible(
                    child: Tooltip(
                      message: shortcut.name,
                      waitDuration: const Duration(milliseconds: 350),
                      child: Opacity(
                        opacity: _labelOverlay == null ? 1.0 : 0.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: labelBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
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
    if (shortcut.targetPath.isNotEmpty) {
      const requestSize = 256;
      return FutureBuilder<Uint8List?>(
        future: Future.value(
          extractIcon(shortcut.path, size: requestSize) ??
              extractIcon(shortcut.targetPath, size: requestSize),
        ),
        builder: (context, snapshot) {
          final buf = snapshot.data;
          if (buf != null && buf.isNotEmpty) {
            return Image.memory(
              buf,
              width: visualIconSize,
              height: visualIconSize,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            );
          }
          return const Icon(Icons.apps);
        },
      );
    }
    return Icon(
      Icons.apps,
      size: visualIconSize,
      color: Colors.grey,
    );
  }

  double get _textSize {
    final size = widget.iconSize * 0.35;
    return math.max(10, math.min(18, size));
  }
}
