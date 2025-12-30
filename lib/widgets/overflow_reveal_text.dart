import 'dart:math' as math;

import 'package:flutter/material.dart';

class OverflowRevealText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign textAlign;

  const OverflowRevealText({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 2,
    this.textAlign = TextAlign.start,
  });

  @override
  State<OverflowRevealText> createState() => _OverflowRevealTextState();
}

class _OverflowRevealTextState extends State<OverflowRevealText> {
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    super.dispose();
  }

  bool _isOverflowing(double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textAlign: widget.textAlign,
      textDirection: TextDirection.ltr,
      maxLines: widget.maxLines,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  void _showOverlay(BuildContext context) {
    _overlay?.remove();
    _overlay = null;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;

    final overlay = Overlay.of(context);
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;

    _overlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  _overlay?.remove();
                  _overlay = null;
                },
              ),
            ),
            Positioned(
              left: topLeft.dx,
              top: math.max(0, topLeft.dy - 2),
              width: size.width,
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  widget.text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (widget.style ?? Theme.of(context).textTheme.bodyMedium)
                          ?.copyWith(
                    shadows: const [
                      Shadow(
                        color: Color(0xD6000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final overflowing = _isOverflowing(maxWidth);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: overflowing ? () => _showOverlay(context) : null,
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
            softWrap: true,
          ),
        );
      },
    );
  }
}
