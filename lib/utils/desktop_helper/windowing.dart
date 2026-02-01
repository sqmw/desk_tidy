part of '../desktop_helper.dart';

math.Point<int> getPrimaryScreenSize() {
  final w = GetSystemMetrics(SM_CXSCREEN);
  final h = GetSystemMetrics(SM_CYSCREEN);
  return math.Point<int>(w, h);
}

math.Rectangle<int>? getWindowRectForHandle(int hwnd) {
  if (hwnd == 0) return null;
  final rect = calloc<RECT>();
  try {
    final ok = GetWindowRect(hwnd, rect) != 0;
    if (!ok) return null;
    final left = rect.ref.left;
    final top = rect.ref.top;
    final right = rect.ref.right;
    final bottom = rect.ref.bottom;
    return math.Rectangle<int>(left, top, right - left, bottom - top);
  } finally {
    calloc.free(rect);
  }
}

bool isCursorOverWindowHandle(int hwnd) {
  if (hwnd == 0) return false;
  final cursor = getCursorScreenPosition();
  if (cursor == null) return false;

  final point = calloc<POINT>();
  try {
    point.ref
      ..x = cursor.x
      ..y = cursor.y;
    final hit = WindowFromPoint(point.ref);
    if (hit == 0) return false;
    if (hit == hwnd) return true;

    const gaRoot = 2;
    const gaRootOwner = 3;
    final root = GetAncestor(hit, gaRoot);
    if (root == hwnd) return true;
    final rootOwner = GetAncestor(hit, gaRootOwner);
    if (rootOwner == hwnd) return true;
    return IsChild(hwnd, hit) != 0;
  } catch (_) {
    return false;
  } finally {
    calloc.free(point);
  }
}

bool isCtrlPressed() {
  // High-order bit means key is currently down.
  const downMask = 0x8000;
  return (GetAsyncKeyState(VK_CONTROL) & downMask) != 0 ||
      (GetAsyncKeyState(VK_LCONTROL) & downMask) != 0 ||
      (GetAsyncKeyState(VK_RCONTROL) & downMask) != 0;
}

int _enumTargetPid = 0;
int _enumFoundHwnd = 0;

int _enumFindFlutterWindowProc(int hwnd, int lParam) {
  final pid = calloc<Uint32>();
  try {
    GetWindowThreadProcessId(hwnd, pid);
    if (pid.value != _enumTargetPid) return 1;

    final classNamePtr = wsalloc(256);
    try {
      final len = GetClassName(hwnd, classNamePtr, 256);
      if (len == 0) return 1;
      final className = classNamePtr.toDartString(length: len);
      if (className != 'DESK_TIDY_WIN32_WINDOW') return 1;
    } finally {
      free(classNamePtr);
    }

    _enumFoundHwnd = hwnd;
    return 0;
  } finally {
    calloc.free(pid);
  }
}

/// Best-effort: find this app's main Flutter HWND (physical pixels).
int? findMainFlutterWindowHandle() {
  _enumTargetPid = GetCurrentProcessId();
  _enumFoundHwnd = 0;
  final cb = Pointer.fromFunction<WNDENUMPROC>(_enumFindFlutterWindowProc, 0);
  EnumWindows(cb, 0);
  return _enumFoundHwnd == 0 ? null : _enumFoundHwnd;
}

/// 强制将窗口设置为前台并获取键盘焦点。
/// 使用 AttachThreadInput 技巧绕过 Windows 对后台窗口的焦点限制。
/// 返回 true 如果成功获取焦点。
bool forceSetForegroundWindow(int hwnd) {
  if (hwnd == 0) return false;

  final foregroundHwnd = GetForegroundWindow();
  if (foregroundHwnd == hwnd) return true; // 已经是前台窗口

  final currentThreadId = GetCurrentThreadId();
  final pidPtr = calloc<Uint32>();
  int foregroundThreadId;
  try {
    foregroundThreadId = GetWindowThreadProcessId(foregroundHwnd, pidPtr);
  } finally {
    calloc.free(pidPtr);
  }

  bool attached = false;
  if (foregroundThreadId != 0 && foregroundThreadId != currentThreadId) {
    attached =
        AttachThreadInput(currentThreadId, foregroundThreadId, TRUE) != 0;
  }

  try {
    // 尝试多种方法确保获得焦点
    SetForegroundWindow(hwnd);
    BringWindowToTop(hwnd);
    SetFocus(hwnd);
  } finally {
    if (attached) {
      AttachThreadInput(currentThreadId, foregroundThreadId, FALSE);
    }
  }

  return GetForegroundWindow() == hwnd;
}
