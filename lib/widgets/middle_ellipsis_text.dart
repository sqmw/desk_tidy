import 'dart:math' as math;

import 'package:flutter/material.dart';

class MiddleEllipsisText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLength;
  final int minTailLength;
  final TextAlign textAlign;
  final bool softWrap;

  const MiddleEllipsisText({
    super.key,
    required this.text,
    this.style,
    this.maxLength = 80,
    this.minTailLength = 20,
    this.textAlign = TextAlign.start,
    this.softWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? DefaultTextStyle.of(context).style;
    return Text(
      _applyEllipsis(text),
      style: textStyle,
      textAlign: textAlign,
      maxLines: 1,
      softWrap: softWrap,
      overflow: TextOverflow.clip,
    );
  }

  String _applyEllipsis(String value) {
    if (value.length <= maxLength) return value;
    if (maxLength <= 1) return value.substring(value.length - 1);

    const ellipsis = '…';
    final available = maxLength - ellipsis.length;
    if (available <= 0) return value.substring(value.length - maxLength);

    final tailLen = math.min(minTailLength, available - 1).clamp(1, available);
    final headLen = (available - tailLen).clamp(1, available);

    final head = value.substring(0, headLen);
    final tail = value.substring(value.length - tailLen);
    return '$head$ellipsis$tail';
  }
}

