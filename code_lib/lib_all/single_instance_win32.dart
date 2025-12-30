import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class SingleInstanceWin32 {
  static const String _mutexName = 'DeskTidy.Singleton.Mutex';

  static Future<bool> ensure({
    required Future<void> Function() onActivateExisting,
  }) async {
    final namePtr = _mutexName.toNativeUtf16();
    final mutex = CreateMutex(nullptr, FALSE, namePtr);
    calloc.free(namePtr);

    final alreadyExists = mutex != 0 && GetLastError() == ERROR_ALREADY_EXISTS;
    if (!alreadyExists) {
      return true;
    }

    // Try to activate an existing instance window (best-effort).
    _activateExistingWindow();
    await onActivateExisting();
    return false;
  }

  static void _activateExistingWindow() {
    final currentPid = GetCurrentProcessId();
    final targetExe = _currentProcessExeName().toLowerCase();

    final foundHwnd = calloc<HWND>();
    final enumProc = Pointer.fromFunction<EnumWindowsProc>(
      (hwnd, lParam) {
        final pidPtr = calloc<Uint32>();
        GetWindowThreadProcessId(hwnd, pidPtr);
        final pid = pidPtr.value;
        calloc.free(pidPtr);

        if (pid == 0 || pid == currentPid) return TRUE;
        if (IsWindowVisible(hwnd) == 0) return TRUE;

        final exeName = _processExeName(pid);
        if (exeName.isEmpty) return TRUE;
        if (exeName.toLowerCase() != targetExe) return TRUE;

        foundHwnd.value = hwnd;
        return FALSE; // stop enumeration
      },
    );

    EnumWindows(enumProc, 0);

    final hwnd = foundHwnd.value;
    calloc.free(foundHwnd);
    if (hwnd == 0) return;

    ShowWindow(hwnd, SW_RESTORE);
    SetForegroundWindow(hwnd);
  }

  static String _currentProcessExeName() {
    final buf = calloc<Utf16>(MAX_PATH);
    final len = GetModuleFileName(0, buf, MAX_PATH);
    final full = len == 0 ? '' : buf.toDartString();
    calloc.free(buf);
    if (full.isEmpty) return '';
    final idx = full.lastIndexOf('\\');
    return idx >= 0 ? full.substring(idx + 1) : full;
  }

  static String _processExeName(int pid) {
    final handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (handle == 0) return '';

    final sizePtr = calloc<Uint32>()..value = MAX_PATH;
    final buf = calloc<Utf16>(MAX_PATH);
    final ok = QueryFullProcessImageName(handle, 0, buf, sizePtr);
    CloseHandle(handle);

    String full = '';
    if (ok != 0) {
      full = buf.toDartString();
    }

    calloc.free(buf);
    calloc.free(sizePtr);

    if (full.isEmpty) return '';
    final idx = full.lastIndexOf('\\');
    return idx >= 0 ? full.substring(idx + 1) : full;
  }
}
