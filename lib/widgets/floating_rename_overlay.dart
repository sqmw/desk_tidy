import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 浮动重命名 Overlay
/// 在指定位置显示气泡风格的编辑框
class FloatingRenameOverlay {
  OverlayEntry? _overlayEntry;
  bool _isActive = false;

  bool get isActive => _isActive;

  void show({
    required BuildContext context,
    required Rect anchorRect,
    required String currentName,
    required ValueChanged<String> onRename,
    VoidCallback? onCancel,
  }) {
    hide();

    final overlay = Overlay.of(context);
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return _FloatingRenameWidget(
          anchorRect: anchorRect,
          screenSize: screenSize,
          currentName: currentName,
          theme: theme,
          onRename: (newName) {
            hide();
            onRename(newName);
          },
          onCancel: () {
            hide();
            onCancel?.call();
          },
          onTapOutside: () {
            hide();
            onCancel?.call();
          },
        );
      },
    );

    _isActive = true;
    overlay.insert(_overlayEntry!);
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isActive = false;
  }
}

class _FloatingRenameWidget extends StatefulWidget {
  final Rect anchorRect;
  final Size screenSize;
  final String currentName;
  final ThemeData theme;
  final ValueChanged<String> onRename;
  final VoidCallback onCancel;
  final VoidCallback onTapOutside;

  const _FloatingRenameWidget({
    required this.anchorRect,
    required this.screenSize,
    required this.currentName,
    required this.theme,
    required this.onRename,
    required this.onCancel,
    required this.onTapOutside,
  });

  @override
  State<_FloatingRenameWidget> createState() => _FloatingRenameWidgetState();
}

class _FloatingRenameWidgetState extends State<_FloatingRenameWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          _save();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.numpadDecimal) {
          _handleDelete();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    final newName = _controller.text.trim();
    if (newName.isNotEmpty && newName != widget.currentName) {
      widget.onRename(newName);
    } else {
      widget.onCancel();
    }
  }

  void _handleDelete() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isCollapsed) {
      final newText = text.replaceRange(selection.start, selection.end, '');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
    } else if (selection.baseOffset < text.length) {
      final newText = text.replaceRange(
        selection.baseOffset,
        selection.baseOffset + 1,
        '',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.baseOffset),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 布局计算
    final anchorTop = widget.anchorRect.top;
    final anchorLeft = widget.anchorRect.left;
    final arrowHeight = 12.0;

    // 默认宽度：稍微宽一点以容纳长文件名，但在小屏幕下自适应
    final overlayWidth = 340.0;

    // 默认在上方，如果空间不足则在下方
    // 阈值设为 100px，因为 header 可能有高度
    bool showAbove = anchorTop > 100;

    // 对于列表项 (anchorWidth 很大)，我们希望左对齐
    // 对于右键菜单 (anchorWidth 很小)，我们希望居中
    final isCompactAnchor = widget.anchorRect.width < 200;

    double left;
    double targetX; // 箭头指向的目标 X 坐标

    if (isCompactAnchor) {
      // 场景 1: 右键点击或者小尺寸元素 -> 居中对齐
      left = widget.anchorRect.center.dx - overlayWidth / 2;
      targetX = widget.anchorRect.center.dx;
    } else {
      // 场景 2: 列表项 -> 左对齐 (避开前面的图标区域)
      // 假设图标区域宽度约 50-60px
      // 气泡左边缘从 anchorLeft + 40 开始
      left = anchorLeft + 40;
      // 箭头指向更靠右一点，大约是文件名的开始位置
      targetX = anchorLeft + 80;
    }

    // 防止超出屏幕边界
    left = left.clamp(8.0, widget.screenSize.width - overlayWidth - 8);

    // 计算箭头在 Bubble 上的相对位置
    final arrowX = (targetX - left).clamp(16.0, overlayWidth - 16.0);

    // 垂直位置
    // showAbove ? 气泡在上方，bottom = 屏幕高度 - anchorTop + 箭头高度
    // !showAbove ? 气泡在下方，top = anchorBottom + 箭头高度

    // 为了更准确指向文字，箭头尖端需要“伸入” anchor 内部一点点 (约为 padding)
    final verticalOffset = 12.0;

    final top = showAbove
        ? null
        : (widget.anchorRect.bottom - verticalOffset) + arrowHeight;
    final bottom = showAbove
        ? widget.screenSize.height - (anchorTop + verticalOffset) + arrowHeight
        : null;

    // 颜色配置
    final isDark = widget.theme.brightness == Brightness.dark;
    // 使用高对比度颜色：深色模式用深灰背景，浅色模式用纯白
    final bubbleColor = isDark ? const Color(0xFF424242) : Colors.white;
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    final textColor = isDark ? Colors.white : Colors.black87;
    // 输入框背景色: 稍微淡一点，突出层次
    final inputBgColor = isDark ? Colors.black38 : Colors.grey.shade100;

    return Stack(
      children: [
        // 点击外部关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onTapOutside,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 气泡编辑框
        Positioned(
          left: left,
          top: top,
          bottom: bottom,
          width: overlayWidth,
          child: CustomPaint(
            painter: _BubblePainter(
              color: bubbleColor,
              borderColor: borderColor,
              arrowX: arrowX,
              arrowHeight: arrowHeight,
              isUpward: !showAbove,
            ),
            child: Padding(
              // 如果气泡在上方，箭头在底部，padding bottom 大一点
              // 如果气泡在下方，箭头在顶部，padding top 大一点 (实际上 Painter 已经处理了)
              // 这里我们给内容统一留白，Painter 会负责把内容框绘制在箭头之外
              padding: EdgeInsets.fromLTRB(
                12,
                !showAbove ? (12 + arrowHeight) : 12,
                12,
                showAbove ? (12 + arrowHeight) : 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: inputBgColor,
                      borderRadius: BorderRadius.circular(6),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        style: widget.theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Action Buttons
                  IconButton(
                    icon: const Icon(
                      Icons.check_circle,
                      size: 24,
                      color: Colors.green,
                    ),
                    onPressed: _save,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.cancel,
                      size: 24,
                      color: Colors.redAccent,
                    ),
                    onPressed: widget.onCancel,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double arrowX;
  final double arrowHeight;
  final bool isUpward; // 箭头是否指向上方 (气泡在下方)

  _BubblePainter({
    required this.color,
    required this.borderColor,
    required this.arrowX,
    required this.arrowHeight,
    required this.isUpward,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0; // 细边框让轮廓更清晰

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final path = Path();
    final r = 10.0; // 圆角加大

    // 内容矩形的范围（不包含箭头的高度）
    final double contentTop = isUpward ? arrowHeight : 0;
    final double contentBottom = isUpward
        ? size.height
        : size.height - arrowHeight;

    if (isUpward) {
      // 箭头在上，Bubble 在下
      path.moveTo(r, contentTop);
      // Top Edge with Arrow
      path.lineTo(arrowX - 8, contentTop);
      path.lineTo(arrowX, 0); // 箭头尖端
      path.lineTo(arrowX + 8, contentTop);
      path.lineTo(size.width - r, contentTop);
      // Right Edge
      path.quadraticBezierTo(
        size.width,
        contentTop,
        size.width,
        contentTop + r,
      );
      path.lineTo(size.width, contentBottom - r);
      // Bottom Edge
      path.quadraticBezierTo(
        size.width,
        contentBottom,
        size.width - r,
        contentBottom,
      );
      path.lineTo(r, contentBottom);
      // Left Edge
      path.quadraticBezierTo(0, contentBottom, 0, contentBottom - r);
      path.lineTo(0, contentTop + r);
      path.quadraticBezierTo(0, contentTop, r, contentTop);
    } else {
      // 箭头在下，Bubble 在上
      path.moveTo(r, contentTop);
      // Top Edge
      path.lineTo(size.width - r, contentTop);
      // Right Edge
      path.quadraticBezierTo(
        size.width,
        contentTop,
        size.width,
        contentTop + r,
      );
      path.lineTo(size.width, contentBottom - r);
      // Bottom Edge with Arrow
      path.quadraticBezierTo(
        size.width,
        contentBottom,
        size.width - r,
        contentBottom,
      );
      path.lineTo(arrowX + 8, contentBottom);
      path.lineTo(arrowX, size.height); // 箭头尖端
      path.lineTo(arrowX - 8, contentBottom);
      path.lineTo(r, contentBottom);
      // Left Edge
      path.quadraticBezierTo(0, contentBottom, 0, contentBottom - r);
      path.lineTo(0, contentTop + r);
      path.quadraticBezierTo(0, contentTop, r, contentTop);
    }

    path.close();

    // 绘制阴影 (稍微偏移一点)
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // 绘制气泡填充
    canvas.drawPath(path, paint);

    // 绘制边框
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.arrowX != arrowX ||
        oldDelegate.isUpward != isUpward ||
        oldDelegate.color != color;
  }
}
