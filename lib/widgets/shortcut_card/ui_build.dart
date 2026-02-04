part of '../shortcut_card.dart';

extension _ShortcutCardUi on _ShortcutCardState {
  Widget _buildBody() {
    final iconSize = widget.iconSize;
    final shortcut = widget.shortcut;
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

    final padding = math.max(8.0, iconSize * 0.28);
    final iconContainerSize = math.max(28.0, iconSize * 1.65);
    final visualIconSize = math.max(12.0, iconContainerSize * 0.92);

    final radius = BorderRadius.circular(math.max(10.0, iconSize * 0.18));
    final baseBg = theme.brightness == Brightness.dark
        ? const Color(0x10FFFFFF)
        : const Color(0x0A000000);
    final hoverBg = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.14,
    );
    final selectedBg = theme.colorScheme.primary.withValues(alpha: 0.08);
    final borderColor = theme.colorScheme.primary.withValues(alpha: 0.30);

    return Focus(
      focusNode: _focusNode,
      onFocusChange: (hasFocus) {
        if (!hasFocus && mounted) {
          _setState(() => _selected = false);
          _removeLabelOverlay();
        }
      },
      child: MouseRegion(
        onEnter: (_) => _requestHover(true),
        onExit: (_) => _requestHover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (details) {
            _focusNode.requestFocus();
            if (!_selected) _toggleSelection();
            final pos = details.globalPosition;
            Future.microtask(() {
              if (!mounted) return;
              _showShortcutMenu(pos);
            });
          },
          onDoubleTap: () {
            if (shortcut.isSystemItem) {
              SystemItemInfo.open(shortcut.systemItemType!);
            } else if (shortcut.targetPath.isNotEmpty) {
              openWithDefault(shortcut.targetPath);
            } else {
              openWithDefault(shortcut.path);
            }
            widget.onLaunched?.call();
          },
          onTap: () {
            _focusNode.requestFocus();
            _toggleSelection();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: (_selected || widget.isHighlighted)
                  ? selectedBg
                  : (_hovered ? hoverBg : baseBg),
              border: Border.all(
                color: (_selected || widget.isHighlighted)
                    ? borderColor
                    : Colors.transparent,
                width: widget.isHighlighted ? 2 : 1,
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
                    child: widget.beautifyIcon
                        ? _buildIcon(context, visualIconSize.toDouble())
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(
                              iconContainerSize * 0.22,
                            ),
                            child: _buildIcon(
                              context,
                              visualIconSize.toDouble(),
                            ),
                          ),
                  ),
                  SizedBox(height: padding * 0.6),
                  Flexible(
                    child: Opacity(
                      opacity: _labelOverlay == null ? 1.0 : 0.0,
                      child: Text(
                        key: _labelTextKey,
                        shortcut.name,
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
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        textAlign: TextAlign.center,
                        maxLines: 2,
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
      return BeautifiedIcon(
        bytes: bytes,
        fallback: Icons.apps,
        size: visualIconSize,
        enabled: widget.beautifyIcon,
        style: widget.beautifyStyle,
        fit: BoxFit.cover,
      );
    }
    if (shortcut.targetPath.isNotEmpty) {
      const requestSize = 256;
      return FutureBuilder<Uint8List?>(
        future: () async {
          final primary = await extractIconAsync(
            shortcut.path,
            size: requestSize,
          );
          if (primary != null && primary.isNotEmpty) return primary;
          return extractIconAsync(shortcut.targetPath, size: requestSize);
        }(),
        builder: (context, snapshot) {
          final buf = snapshot.data;
          if (buf != null && buf.isNotEmpty) {
            return BeautifiedIcon(
              bytes: buf,
              fallback: Icons.apps,
              size: visualIconSize,
              enabled: widget.beautifyIcon,
              style: widget.beautifyStyle,
              fit: BoxFit.contain,
            );
          }
          return BeautifiedIcon(
            bytes: null,
            fallback: Icons.apps,
            size: visualIconSize,
            enabled: widget.beautifyIcon,
            style: widget.beautifyStyle,
          );
        },
      );
    }
    return BeautifiedIcon(
      bytes: null,
      fallback: Icons.apps,
      size: visualIconSize,
      enabled: widget.beautifyIcon,
      style: widget.beautifyStyle,
    );
  }
}
