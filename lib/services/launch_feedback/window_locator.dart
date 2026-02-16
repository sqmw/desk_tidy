import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

int _nextLookupId = 1;
final Map<int, _WindowLookupContext> _lookupContexts = {};
final Pointer<NativeFunction<WNDENUMPROC>> _enumWindowProcPtr =
    Pointer.fromFunction<WNDENUMPROC>(_enumWindowProc, 1);

final class _WindowLookupContext {
  _WindowLookupContext({required this.targetProcessInfo});

  final _ProcessMatchInfo targetProcessInfo;
  final Map<int, String?> processPathCache = {};
  int foundHwnd = 0;
  int matchedWindowCount = 0;
}

class LaunchTargetWindowLocator {
  int findTopLevelWindowByExecutable(String executablePath) {
    return _scanTopLevelWindowsByExecutable(executablePath).foundHwnd;
  }

  int countTopLevelWindowsByExecutable(String executablePath) {
    return _scanTopLevelWindowsByExecutable(executablePath).matchedWindowCount;
  }

  bool isForegroundWindowFromExecutable(String executablePath) {
    final targetInfo = _normalizedProcessInfo(executablePath);
    if (targetInfo.normalizedPath.isEmpty) return false;

    final hwnd = GetForegroundWindow();
    if (hwnd == 0) return false;

    final pidPtr = calloc<Uint32>();
    try {
      GetWindowThreadProcessId(hwnd, pidPtr);
      final pid = pidPtr.value;
      if (pid == 0) return false;

      final processPath = _queryProcessImagePath(pid);
      if (processPath == null || processPath.isEmpty) return false;

      final processInfo = _normalizedProcessInfo(processPath);
      return _matchesTargetProcess(processInfo, targetInfo);
    } finally {
      calloc.free(pidPtr);
    }
  }

  _WindowLookupContext _scanTopLevelWindowsByExecutable(String executablePath) {
    final targetInfo = _normalizedProcessInfo(executablePath);
    final context = _WindowLookupContext(targetProcessInfo: targetInfo);
    if (targetInfo.normalizedPath.isEmpty) return context;

    final lookupId = _nextLookupId++;
    _lookupContexts[lookupId] = context;
    try {
      EnumWindows(_enumWindowProcPtr, lookupId);
      return context;
    } finally {
      _lookupContexts.remove(lookupId);
    }
  }
}

int _enumWindowProc(int hwnd, int lParam) {
  final context = _lookupContexts[lParam];
  if (context == null) return 0;
  if (IsWindowVisible(hwnd) == 0) return 1;
  if (GetWindow(hwnd, GW_OWNER) != 0) return 1;

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

    final processInfo = _normalizedProcessInfo(processPath);
    if (_matchesTargetProcess(processInfo, context.targetProcessInfo)) {
      context.matchedWindowCount++;
      if (context.foundHwnd == 0) {
        context.foundHwnd = hwnd;
      }
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

final class _ProcessMatchInfo {
  const _ProcessMatchInfo({
    required this.normalizedPath,
    required this.exeName,
    required this.exeStem,
    required this.familyKey,
  });

  final String normalizedPath;
  final String exeName;
  final String exeStem;
  final String familyKey;
}

_ProcessMatchInfo _normalizedProcessInfo(String rawPath) {
  final normalizedPath = _normalizeWindowsPath(rawPath);
  final exeName = path.basename(normalizedPath).toLowerCase();
  final exeStem = _exeStemFromPath(normalizedPath);
  return _ProcessMatchInfo(
    normalizedPath: normalizedPath,
    exeName: exeName,
    exeStem: exeStem,
    familyKey: _appFamilyKey(exeStem),
  );
}

bool _matchesTargetProcess(
  _ProcessMatchInfo process,
  _ProcessMatchInfo target,
) {
  if (process.normalizedPath == target.normalizedPath) return true;
  if (process.exeName == target.exeName) return true;
  if (process.exeStem == target.exeStem) return true;
  if (process.familyKey.isNotEmpty && process.familyKey == target.familyKey) {
    return true;
  }
  return false;
}

String _exeStemFromPath(String normalizedPath) {
  if (normalizedPath.isEmpty) return '';
  return path.basenameWithoutExtension(normalizedPath).toLowerCase();
}

String _appFamilyKey(String exeStem) {
  var value = exeStem.trim().toLowerCase();
  if (value.isEmpty) return '';

  value = value.replaceAll(RegExp(r'[^a-z0-9]'), '');
  const removableSuffixes = [
    'launcher',
    'updater',
    'update',
    'helper',
    'service',
    'client',
    'host',
    'stub',
    'bootstrap',
  ];

  var changed = true;
  while (changed && value.isNotEmpty) {
    changed = false;
    for (final suffix in removableSuffixes) {
      if (value.endsWith(suffix) && value.length > suffix.length + 2) {
        value = value.substring(0, value.length - suffix.length);
        changed = true;
      }
    }
  }

  return value;
}
