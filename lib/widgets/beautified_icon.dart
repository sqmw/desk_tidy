import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/icon_beautify_style.dart';

class BeautifiedIcon extends StatelessWidget {
  final Uint8List? bytes;
  final IconData fallback;
  final double size;
  final bool enabled;
  final IconBeautifyStyle style;
  final BoxFit fit;
  final Color? fallbackColor;

  const BeautifiedIcon({
    super.key,
    required this.bytes,
    required this.fallback,
    required this.size,
    required this.enabled,
    required this.style,
    this.fit = BoxFit.contain,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedSize = math.max(1.0, size);
    final theme = Theme.of(context);
    final spec = iconBeautifyStyleSpec(style, theme.brightness);
    final hasImage = bytes != null && bytes!.isNotEmpty;

    if (!enabled) {
      return SizedBox(
        width: resolvedSize,
        height: resolvedSize,
        child: _buildIcon(
          context,
          size: resolvedSize,
          color: fallbackColor,
        ),
      );
    }

    final iconSize = math.max(1.0, resolvedSize);
    final resolvedFallbackColor =
        !hasImage ? (spec.iconColor ?? fallbackColor) : fallbackColor;
    Widget icon = _buildIcon(
      context,
      size: iconSize,
      color: resolvedFallbackColor,
    );
    icon = _applyIconFilter(icon, spec, hasImage);

    return SizedBox(
      width: resolvedSize,
      height: resolvedSize,
      child: icon,
    );
  }

  Widget _applyIconFilter(
    Widget icon,
    IconBeautifyStyleSpec spec,
    bool hasImage,
  ) {
    if (!hasImage) return icon;
    final color = spec.iconColor;
    if (spec.iconFilterMode == IconFilterMode.none || color == null) {
      return icon;
    }
    switch (spec.iconFilterMode) {
      case IconFilterMode.none:
        return icon;
      case IconFilterMode.solidTint:
        return ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          child: icon,
        );
      case IconFilterMode.lumaTint:
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(_lumaColorMatrix(color)),
          child: icon,
        );
    }
  }

  Widget _buildIcon(
    BuildContext context, {
    required double size,
    Color? color,
  }) {
    final data = bytes;
    if (data != null && data.isNotEmpty) {
      return Image.memory(
        data,
        width: size,
        height: size,
        fit: fit,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );
    }
    return Icon(
      fallback,
      size: size,
      color: color ?? Theme.of(context).colorScheme.onSurface.withValues(
            alpha: 0.72,
          ),
    );
  }

  List<double> _lumaColorMatrix(Color color) {
    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;
    return [
      lumR * r, lumG * r, lumB * r, 0, 0,
      lumR * g, lumG * g, lumB * g, 0, 0,
      lumR * b, lumG * b, lumB * b, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}
