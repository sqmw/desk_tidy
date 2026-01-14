import 'package:flutter/material.dart';

enum IconBeautifyStyle {
  cute,
  cartoon,
  neon,
}

enum IconFilterMode {
  none,
  solidTint,
  lumaTint,
}

class IconBeautifyStyleSpec {
  final String label;
  final List<Color> gradient;
  final Color borderColor;
  final Color innerStrokeColor;
  final double borderWidth;
  final double innerStrokeWidth;
  final double radiusFactor;
  final double paddingFactor;
  final List<BoxShadow> shadows;
  final IconFilterMode iconFilterMode;
  final Color? iconColor;
  final Color? labelColor;
  final Color? labelShadowColor;

  const IconBeautifyStyleSpec({
    required this.label,
    required this.gradient,
    required this.borderColor,
    required this.innerStrokeColor,
    required this.borderWidth,
    required this.innerStrokeWidth,
    required this.radiusFactor,
    required this.paddingFactor,
    required this.shadows,
    required this.iconFilterMode,
    required this.iconColor,
    required this.labelColor,
    required this.labelShadowColor,
  });
}

IconBeautifyStyleSpec iconBeautifyStyleSpec(
  IconBeautifyStyle style,
  Brightness brightness,
) {
  switch (style) {
    case IconBeautifyStyle.cute:
      return IconBeautifyStyleSpec(
        label: '可爱',
        gradient: const [
          Color(0xFFFFD7E9),
          Color(0xFFFFF1C9),
        ],
        borderColor: const Color(0xFFFFB7D6),
        innerStrokeColor: const Color(0xFFFFFFFF),
        borderWidth: 1.2,
        innerStrokeWidth: 0.8,
        radiusFactor: 0.34,
        paddingFactor: 0.18,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        iconFilterMode: IconFilterMode.lumaTint,
        iconColor: const Color(0xFFFF6FAE),
        labelColor: const Color(0xFFE55597),
        labelShadowColor: Colors.black.withValues(alpha: 0.45),
      );
    case IconBeautifyStyle.cartoon:
      return IconBeautifyStyleSpec(
        label: '卡通',
        gradient: const [
          Color(0xFFFFE0B8),
          Color(0xFFFFF4DB),
        ],
        borderColor: const Color(0xFFB5835A),
        innerStrokeColor: const Color(0xFFFFF8EA),
        borderWidth: 1.6,
        innerStrokeWidth: 1.0,
        radiusFactor: 0.22,
        paddingFactor: 0.16,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        iconFilterMode: IconFilterMode.lumaTint,
        iconColor: brightness == Brightness.dark
            ? const Color(0xFFFFC28A)
            : const Color(0xFFFFB46B),
        labelColor: brightness == Brightness.dark
            ? const Color(0xFFE69A57)
            : const Color(0xFFD58644),
        labelShadowColor: Colors.black.withValues(alpha: 0.50),
      );
    case IconBeautifyStyle.neon:
      return IconBeautifyStyleSpec(
        label: '霓虹',
        gradient: const [
          Color(0xFF0C1326),
          Color(0xFF101B36),
        ],
        borderColor: const Color(0xFF5FF3FF),
        innerStrokeColor: const Color(0xFF1D2B4F),
        borderWidth: 1.4,
        innerStrokeWidth: 0.8,
        radiusFactor: 0.26,
        paddingFactor: 0.15,
        shadows: [
          BoxShadow(
            color: const Color(0xFF38D6FF).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        iconFilterMode: IconFilterMode.lumaTint,
        iconColor: const Color(0xFF5DEBFF),
        labelColor: const Color(0xFF6FF3FF),
        labelShadowColor: const Color(0xFF0A101F).withValues(alpha: 0.65),
      );
  }
}

String iconBeautifyStyleLabel(IconBeautifyStyle style) {
  switch (style) {
    case IconBeautifyStyle.cute:
      return '可爱';
    case IconBeautifyStyle.cartoon:
      return '卡通';
    case IconBeautifyStyle.neon:
      return '霓虹';
  }
}
