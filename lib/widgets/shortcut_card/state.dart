part of '../shortcut_card.dart';

class ShortcutCard extends StatefulWidget {
  final ShortcutItem shortcut;
  final double iconSize;
  final ValueListenable<bool>? windowFocusNotifier;
  final VoidCallback? onDeleted;
  final Future<void> Function(ShortcutItem shortcut, Offset position)?
  onCategoryMenuRequested;
  final bool beautifyIcon;
  final IconBeautifyStyle beautifyStyle;
  final VoidCallback? onLaunched;
  final Future<void> Function(ShortcutItem shortcut)? onOpenRequested;
  final bool isHighlighted; // 键盘导航高亮

  const ShortcutCard({
    super.key,
    required this.shortcut,
    this.iconSize = 32,
    this.windowFocusNotifier,
    this.onDeleted,
    this.onCategoryMenuRequested,
    this.beautifyIcon = false,
    this.beautifyStyle = IconBeautifyStyle.cute,
    this.onLaunched,
    this.onOpenRequested,
    this.isHighlighted = false,
  });

  @override
  State<ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<ShortcutCard> {
  OverlayEntry? _labelOverlay;
  bool _selected = false;
  bool _hovered = false;
  bool? _pendingHoverValue;
  bool _hoverUpdateScheduled = false;
  late final FocusNode _focusNode;
  final GlobalKey _labelTextKey = GlobalKey();
  ValueListenable<bool>? _windowFocusNotifier;

  void _setState(VoidCallback fn) => setState(fn);

  double get _textSize => (widget.iconSize * 0.34).clamp(10.0, 18.0);

  void _requestHover(bool value) {
    _pendingHoverValue = value;
    if (_hoverUpdateScheduled) return;
    _hoverUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hoverUpdateScheduled = false;
      if (!mounted) return;
      final next = _pendingHoverValue;
      if (next == null || _hovered == next) return;
      _setState(() => _hovered = next);
    });
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ShortcutCard');
    _updateWindowFocusNotifier(widget.windowFocusNotifier);
  }

  @override
  void didUpdateWidget(covariant ShortcutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windowFocusNotifier != widget.windowFocusNotifier) {
      _updateWindowFocusNotifier(widget.windowFocusNotifier);
    }
  }

  @override
  void dispose() {
    _removeLabelOverlay();
    _windowFocusNotifier?.removeListener(_onWindowFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildBody();
}
