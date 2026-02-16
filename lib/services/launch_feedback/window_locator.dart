import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

int _nextLookupId = 1;
final Map<int, _WindowLookupContext> _lookupContexts = {};
final Pointer<NativeFunction<WNDENUMPROC>> _enumWindowProcPtr =
    Pointer.fromFunction<WNDENUMPROC>(_enumWindowProc, 1);

final class _WindowLookupContext {
  _WindowLookupContext({
    required this.targetExePath,
    required this.targetExeName,
  });

  final String targetExePath;
  final String targetExeName;
  final Map<int, String?> processPathCache = {};
  int foundHwnd = 0;
}

class LaunchTargetWindowLocator {
  int findTopLevelWindowByExecutable(String executablePath) {
    final normalizedPath = _normalizeWindowsPath(executablePath);
    if (normalizedPath.isEmpty) return 0;

    final lookupId = _nextLookupId++;
    final context = _WindowLookupContext(
      targetExePath: normalizedPath,
      targetExeName: path.basename(normalizedPath).toLowerCase(),
    );
    _lookupContexts[lookupId] = context;
    try {
      EnumWindows(_enumWindowProcPtr, lookupId);
      return context.foundHwnd;
    } finally {
      _lookupContexts.remove(lookupId);
    }
  }
}

int _enumWindowProc(int hwnd, int lParam) {
  final context = _lookupContexts[lParam];
  if (context == null) return 0;
  if (context.foundHwnd != 0) return 0;
  if (IsWindowVisible(hwnd) == 0) return 1;
  if (GetWindow(hwnd, GW_OWNER) != 0) return 1;
  if (GetWindowTextLength(hwnd) <= 0) return 1;

  final pidPtr = calloc<Uint32>();
  try {
    GetWindowThreadProcessId(hwnd, pidPtr);
    final pid = pidPtr.value;
    if (pid == 0) return 1;

    final hasCache = context.processPathCache.containsKey(pid);
    final processPath = hasCache
        ? context.processPathCache[pid]
        : _queryProcessImagePath(pid);
    if (!hasCache) {
      context.processPathCache[pid] = processPath;
    }
    if (processPath == null || processPath.isEmpty) return 1;

    final normalizedProcessPath = _normalizeWindowsPath(processPath);
    final processExeName = path.basename(normalizedProcessPath).toLowerCase();
    if (normalizedProcessPath == context.targetExePath ||
        processExeName == context.targetExeName) {
      context.foundHwnd = hwnd;
      return 0;
    }
    return 1;
  } finally {
    calloc.free(pidPtr);
  }
}

String? _queryProcessImagePath(int pid) {
  final processHandle = OpenProcess(
    PROCESS_QUERY_LIMITED_INFORMATION,
    FALSE,
    pid,
  );
  if (processHandle == 0) return null;

  final bufferLen = 32768;
  final imagePathPtr = wsalloc(bufferLen);
  final sizePtr = calloc<Uint32>()..value = bufferLen;
  try {
    final ok = QueryFullProcessImageName(
      processHandle,
      0,
      imagePathPtr,
      sizePtr,
    );
    if (ok == 0 || sizePtr.value == 0) return null;
    return imagePathPtr.toDartString(length: sizePtr.value);
  } finally {
    free(imagePathPtr);
    calloc.free(sizePtr);
    CloseHandle(processHandle);
  }
}

String _normalizeWindowsPath(String rawPath) {
  final trimmed = rawPath.trim();
  if (trimmed.isEmpty) return '';
  return path.normalize(trimmed.replaceAll('/', r'\')).toLowerCase();
}
