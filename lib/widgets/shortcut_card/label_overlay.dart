part of '../shortcut_card.dart';

extension _ShortcutCardLabelOverlay on _ShortcutCardState {
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
}
