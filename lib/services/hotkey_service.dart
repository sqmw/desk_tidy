/// 全局热键服务（简化版）
///
/// 使用 Timer.periodic 定期检查按键状态，类似热区唤醒的实现方式
library;

import 'dart:async';
import 'package:win32/win32.dart';

/// 热键配置
class HotkeyConfig {
  final int vkCtrl;
  final int vkShift;
  final int vkAlt;
  final int vkKey;
  final String description;

  const HotkeyConfig({
    required this.vkCtrl,
    required this.vkShift,
    required this.vkAlt,
    required this.vkKey,
    this.description = '',
  });

  /// Ctrl + Shift + Space
  static const showWindow = HotkeyConfig(
    vkCtrl: 1,
    vkShift: 1,
    vkAlt: 0,
    vkKey: VK_SPACE,
    description: 'Ctrl + Shift + Space',
  );

  /// Alt + Shift + Space
  static const showWindowAlt = HotkeyConfig(
    vkCtrl: 0,
    vkShift: 1,
    vkAlt: 1,
    vkKey: VK_SPACE,
    description: 'Alt + Shift + Space',
  );

  /// 检查此热键组合是否当前被按下
  bool isPressed() {
    const downMask = 0x8000;

    // 检查 Ctrl
    if (vkCtrl == 1) {
      final ctrlPressed =
          (GetAsyncKeyState(VK_CONTROL) & downMask) != 0 ||
          (GetAsyncKeyState(VK_LCONTROL) & downMask) != 0 ||
          (GetAsyncKeyState(VK_RCONTROL) & downMask) != 0;
      if (!ctrlPressed) return false;
    }

    // 检查 Shift
    if (vkShift == 1) {
      final shiftPressed =
          (GetAsyncKeyState(VK_SHIFT) & downMask) != 0 ||
          (GetAsyncKeyState(VK_LSHIFT) & downMask) != 0 ||
          (GetAsyncKeyState(VK_RSHIFT) & downMask) != 0;
      if (!shiftPressed) return false;
    }

    // 检查 Alt
    if (vkAlt == 1) {
      final altPressed =
          (GetAsyncKeyState(VK_MENU) & downMask) != 0 ||
          (GetAsyncKeyState(VK_LMENU) & downMask) != 0 ||
          (GetAsyncKeyState(VK_RMENU) & downMask) != 0;
      if (!altPressed) return false;
    }

    // 检查主键
    return (GetAsyncKeyState(vkKey) & downMask) != 0;
  }

  @override
  String toString() => description.isNotEmpty ? description : 'Hotkey';
}

/// 热键触发回调
typedef HotkeyCallback = void Function(HotkeyConfig hotkey);

/// 全局热键服务（简化版）
class HotkeyService {
  HotkeyService._();

  static HotkeyService? _instance;
  static HotkeyService get instance => _instance ??= HotkeyService._();

  Timer? _timer;
  final List<HotkeyConfig> _hotkeys = [];
  final Map<HotkeyConfig, bool> _lastState = {};
  HotkeyCallback? _callback;

  /// 注册热键
  void register(HotkeyConfig hotkey, {HotkeyCallback? callback}) {
    if (!_hotkeys.contains(hotkey)) {
      _hotkeys.add(hotkey);
      _lastState[hotkey] = false;
      print('✅ 注册热键: ${hotkey.description}');
    }
    if (callback != null) {
      _callback = callback;
    }
  }

  /// 开始轮询
  void startPolling({Duration interval = const Duration(milliseconds: 100)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _pollHotkeys());
    print('🔄 开始轮询热键...');
  }

  /// 停止轮询
  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// 轮询检查热键状态
  void _pollHotkeys() {
    for (final hotkey in _hotkeys) {
      final isPressed = hotkey.isPressed();
      final wasPressed = _lastState[hotkey] ?? false;

      // 检测按键从未按下到按下的边沿（防止重复触发）
      if (isPressed && !wasPressed) {
        print('🔥 检测到热键: ${hotkey.description}');
        _callback?.call(hotkey);
      }

      _lastState[hotkey] = isPressed;
    }
  }

  /// 释放资源
  void dispose() {
    stopPolling();
    _hotkeys.clear();
    _lastState.clear();
    _callback = null;
    _instance = null;
  }
}
