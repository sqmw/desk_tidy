import 'dart:async';
import 'dart:ui';

import 'package:window_manager/window_manager.dart';

import '../utils/desktop_helper.dart';
import 'window_dock_logic.dart';

/// 窗口拖动和磁吸管理器
class WindowDockManager {
  final WindowManager windowManager;
  final int Function()?
  _getWindowHandleCallback; // Optional fallback or remove if fully decoupled
  int _windowHandle = 0;

  final StreamController<DockEvent> _eventController =
      StreamController<DockEvent>.broadcast();
  Stream<DockEvent> get events => _eventController.stream;

  WindowDockManager({
    required this.windowManager,
    int Function()? getWindowHandle,
  }) : _getWindowHandleCallback = getWindowHandle;

  void updateWindowHandle(int handle) {
    _windowHandle = handle;
  }

  // 状态：只保留必要的
  bool _isDocked = false; // 窗口是否在吸附区
  bool _isDragging = false; // 是否正在拖动
  bool _isTrayTrigger = false; // 是否从托盘触发打开
  bool _isHotkeyTrigger = false; // 是否从快捷键触发打开
  bool _isInTray = true; // 窗口是否在托盘中

  // 定时器
  Timer? _autoHideTimer;
  Timer? _hideDelayTimer;

  // 配置
  static const Duration _autoHideCheckInterval = Duration(milliseconds: 400);
  static const Duration _hideDelay = Duration(milliseconds: 200);
  static const Duration _trayTriggerHideDelay = Duration(
    milliseconds: 260,
  ); // tray触发后离开的隐藏延迟
  static const Duration _suppressMoveDuration = Duration(milliseconds: 360);

  DateTime _suppressMoveUntil = DateTime.fromMillisecondsSinceEpoch(0);

  // Getters
  bool get isDocked => _isDocked;
  bool get isDragging => _isDragging;

  /// 初始化，启动自动隐藏检测定时器
  void start() {
    _startAutoHideWatcher();
  }

  /// 清理资源
  void dispose() {
    _autoHideTimer?.cancel();
    _hideDelayTimer?.cancel();
    _eventController.close();
  }

  /// 标记窗口开始拖动
  void markWindowMoving() {
    _isDragging = true;
  }

  /// 鼠标松开时检查是否需要吸附
  Future<void> onMouseUp() async {
    _isDragging = false;

    try {
      final pos = await windowManager.getPosition();
      final screen = getPrimaryScreenSize();
      final snapZone = WindowDockLogic.snapZone(
        Size(screen.x.toDouble(), screen.y.toDouble()),
      );
      final shouldSnap = WindowDockLogic.shouldSnapToTopLeft(pos, snapZone);

      if (shouldSnap) {
        _isDocked = true;
        if (pos.dx != 0 || pos.dy != 0) {
          _suppressMoveUntil = DateTime.now().add(_suppressMoveDuration);
          await windowManager.setPosition(Offset.zero, animate: true);
        }
      } else {
        _isDocked = false;
      }
    } catch (_) {
      // 忽略错误
    }
  }

  /// 检查是否应该抑制移动跟踪
  bool shouldSuppressMoveTracking() {
    return DateTime.now().isBefore(_suppressMoveUntil);
  }

  /// 从托盘触发打开窗口
  void onPresentFromTray() {
    _isInTray = false;
    _isTrayTrigger = true;
  }

  /// 从热区触发打开窗口（Ctrl + 鼠标到达触发区域）
  void onPresentFromHotCorner() {
    _isInTray = false;
    _isTrayTrigger = false;
    _isHotkeyTrigger = false;
    _isDocked = true;
  }

  /// 从快捷键触发打开窗口
  void onPresentFromHotkey() {
    _isInTray = false;
    _isTrayTrigger = false;
    _isHotkeyTrigger = true;
    _isDocked = false;
  }

  /// 窗口移动到托盘
  void onDismissToTray() {
    _isInTray = true;
    _isTrayTrigger = false;
    _isHotkeyTrigger = false;
    _hideDelayTimer?.cancel();
  }

  /// 鼠标进入窗口区域
  void onMouseEnter() {
    // 如果是从托盘触发，鼠标进入时立即设置为false（因为已经进入app了）
    if (_isTrayTrigger) {
      _isTrayTrigger = false;
    }
    // 取消任何待执行的隐藏操作
    _hideDelayTimer?.cancel();
  }

  /// 鼠标点击在app内部
  Future<void> onMouseClickInside() async {
    // 取消任何待执行的隐藏操作
    _hideDelayTimer?.cancel();
  }

  /// 鼠标点击在app外部（托盘触发或快捷键触发时）
  Future<void> onMouseClickOutside() async {
    if (_isInTray) return;
    // 托盘触发或快捷键触发时，点击外部直接隐藏
    if (_isTrayTrigger || _isHotkeyTrigger) {
      _requestDismiss(fromHotCorner: false);
    }
  }

  /// 鼠标离开窗口区域
  Future<void> onMouseExit() async {
    // 如果窗口在托盘中，不处理
    if (_isInTray) return;

    // 如果是从托盘触发且还未进入过app（isTrayTrigger仍为true），不处理（由点击外部处理）
    if (_isTrayTrigger) return;

    // 如果正在拖动，不处理
    if (_isDragging) return;

    // 如果窗口不在吸附区，不处理
    if (!_isDocked) return;

    // 检查窗口是否真的在吸附区
    final pos = await windowManager.getPosition();
    final screen = getPrimaryScreenSize();
    final snapZone = WindowDockLogic.snapZone(
      Size(screen.x.toDouble(), screen.y.toDouble()),
    );
    if (!WindowDockLogic.shouldSnapToTopLeft(pos, snapZone)) {
      _isDocked = false;
      return;
    }

    // 检查鼠标是否在窗口内（可能鼠标又回来了）
    if (await _isCursorInsideWindow()) return;

    // 取消之前的隐藏定时器
    _hideDelayTimer?.cancel();

    // 立即开始260ms倒计时隐藏（这是从tray触发进入app后离开的情况）
    _hideDelayTimer = Timer(_trayTriggerHideDelay, () async {
      // 再次确认条件
      if (_isInTray || _isTrayTrigger || _isDragging) return;

      final currentPos = await windowManager.getPosition();
      final currentScreen = getPrimaryScreenSize();
      final currentSnapZone = WindowDockLogic.snapZone(
        Size(currentScreen.x.toDouble(), currentScreen.y.toDouble()),
      );
      if (!WindowDockLogic.shouldSnapToTopLeft(currentPos, currentSnapZone)) {
        _isDocked = false;
        return;
      }

      if (await _isCursorInsideWindow()) return;

      _requestDismiss(fromHotCorner: true);
    });
  }

  /// 启动自动隐藏检测定时器（400ms间隔）
  void _startAutoHideWatcher() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer.periodic(_autoHideCheckInterval, (_) async {
      // 如果窗口在托盘中，不检测
      if (_isInTray) return;

      // 如果是从托盘触发，由点击外部事件处理，这里不检测
      if (_isTrayTrigger) return;

      // 如果正在拖动，不检测
      if (_isDragging) return;

      // 如果窗口不在吸附区，不检测
      if (!_isDocked) return;

      // 检查鼠标是否在窗口内
      final cursorInside = await _isCursorInsideWindow();
      if (cursorInside) {
        // 鼠标在窗口内，取消任何待执行的隐藏
        _hideDelayTimer?.cancel();
        return;
      }

      // 鼠标在窗口外，检查窗口是否真的在吸附区
      final pos = await windowManager.getPosition();
      final screen = getPrimaryScreenSize();
      final snapZone = WindowDockLogic.snapZone(
        Size(screen.x.toDouble(), screen.y.toDouble()),
      );
      if (!WindowDockLogic.shouldSnapToTopLeft(pos, snapZone)) {
        // 窗口不在吸附区，更新状态
        _isDocked = false;
        return;
      }

      // 如果已经有待执行的隐藏操作，不再重复设置
      if (_hideDelayTimer?.isActive ?? false) return;

      // 设置200ms延迟后隐藏，期间不再做判断
      _hideDelayTimer = Timer(_hideDelay, () async {
        // 再次确认窗口仍在吸附区且鼠标仍在窗口外
        if (_isInTray || _isTrayTrigger || _isDragging) return;

        final currentPos = await windowManager.getPosition();
        final currentScreen = getPrimaryScreenSize();
        final currentSnapZone = WindowDockLogic.snapZone(
          Size(currentScreen.x.toDouble(), currentScreen.y.toDouble()),
        );
        if (!WindowDockLogic.shouldSnapToTopLeft(currentPos, currentSnapZone)) {
          _isDocked = false;
          return;
        }

        if (await _isCursorInsideWindow()) return;

        _requestDismiss(fromHotCorner: true);
      });
    });
  }

  void _requestDismiss({required bool fromHotCorner}) {
    _eventController.add(
      DockEventDismissRequested(fromHotCorner: fromHotCorner),
    );
  }

  Future<bool> _isCursorInsideWindow() async {
    try {
      int handle = _windowHandle;
      if (handle == 0 && _getWindowHandleCallback != null) {
        handle = _getWindowHandleCallback();
        _windowHandle = handle;
      }

      if (handle != 0 && isCursorOverWindowHandle(handle)) {
        return true;
      }

      // Fallback: Geometric check
      final cursor = getCursorScreenPosition();
      if (cursor == null) return false;

      // If we have a handle, check rect from OS
      if (handle != 0) {
        final rect = getWindowRectForHandle(handle);
        if (rect != null) {
          // Basic point check
          return cursor.x >= rect.left &&
              cursor.x <= rect.right &&
              cursor.y >= rect.top &&
              cursor.y <= rect.bottom;
        }
      }

      // Fallback to WindowManager's known position (could be stale if moving fast)
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      final x = cursor.x.toDouble();
      final y = cursor.y.toDouble();
      return x >= pos.dx &&
          y >= pos.dy &&
          x <= (pos.dx + size.width) &&
          y <= (pos.dy + size.height);
    } catch (_) {
      return false;
    }
  }
}

abstract class DockEvent {}

class DockEventDismissRequested extends DockEvent {
  final bool fromHotCorner;
  DockEventDismissRequested({required this.fromHotCorner});
}
