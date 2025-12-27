import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/shortcut_item.dart';
import '../utils/desktop_helper.dart';

class ShortcutCard extends StatefulWidget {
  final ShortcutItem shortcut;
  final double iconSize;

  const ShortcutCard({
    Key? key,
    required this.shortcut,
    this.iconSize = 32,
  }) : super(key: key);

  @override
  State<ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<ShortcutCard> {
  OverlayEntry? _labelOverlay;
  bool _selected = false;
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

    final box = renderObject;
    final topLeft = box.localToGlobal(Offset.zero);
    final size = box.size;

    final name = widget.shortcut.name;
    final theme = Theme.of(context);
    final padding = math.max(8.0, widget.iconSize * 0.28);
    final textMaxWidth = math.max(0.0, size.width - padding * 2);

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
      ellipsis: '…',
    )..layout(maxWidth: textMaxWidth);

    final shouldExpand = testPainter.didExceedMaxLines;
    if (!shouldExpand) return;

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
              top: topLeft.dy + size.height - 42,
              width: size.width,
              child: Material(
                type: MaterialType.transparency,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.max(120.0, size.width),
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

    final padding = math.max(8.0, iconSize * 0.28);
    final iconContainerSize = math.max(28.0, iconSize * 1.65);
    final visualIconSize = math.max(12.0, iconContainerSize * 0.92);
    final iconBg = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withAlpha(140);
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (hasFocus) {
        if (!hasFocus && mounted) {
          setState(() => _selected = false);
          _removeLabelOverlay();
        }
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(math.max(8, iconSize * 0.15)),
        ),
        child: InkWell(
          onTap: () {
            _focusNode.requestFocus();
            _toggleSelection();
          },
          borderRadius: BorderRadius.circular(math.max(8, iconSize * 0.15)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: padding * 0.6,
              horizontal: padding.toDouble(),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(iconContainerSize * 0.22),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withAlpha(89),
                    ),
                  ),
                  child: Center(
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
                      child: Text(
                        shortcut.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              ],
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
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );
    }
    if (shortcut.targetPath.isNotEmpty) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final requestSize =
          (visualIconSize * dpr).round().clamp(32, 256);
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
              fit: BoxFit.contain,
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
