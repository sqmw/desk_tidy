part of '../shortcut_card.dart';

extension _ShortcutCardSelectionOverlay on _ShortcutCardState {
  void _removeLabelOverlay() {
    _labelOverlay?.remove();
    _labelOverlay = null;
  }

  void _clearSelection() {
    if (!_selected || !mounted) return;
    _setState(() => _selected = false);
    _removeLabelOverlay();
  }

  void _updateWindowFocusNotifier(ValueListenable<bool>? notifier) {
    if (_windowFocusNotifier == notifier) return;
    _windowFocusNotifier?.removeListener(_onWindowFocusChanged);
    _windowFocusNotifier = notifier;
    _windowFocusNotifier?.addListener(_onWindowFocusChanged);
  }

  void _onWindowFocusChanged() {
    if (_windowFocusNotifier?.value ?? true) return;
    _clearSelection();
  }

  void _toggleSelection() {
    _setState(() => _selected = !_selected);
    if (_selected) _showLabelOverlay();
    if (!_selected) _removeLabelOverlay();
  }
}
