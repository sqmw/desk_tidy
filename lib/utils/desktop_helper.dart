import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:process_run/shell.dart' as pr;

const int _invalidFileAttributes = 0xFFFFFFFF;
const int _shilJumbo = 0x4;
const int _ildTransparent = 0x00000001;
const int _ildImage = 0x00000020;
const int _diNormal = 0x0003;
const String _iidIImageList = '{46EB5926-582E-4017-9FDF-E8998DAA0950}';

final DynamicLibrary _shell32 = DynamicLibrary.open('shell32.dll');
final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

const int _smtoAbortIfHung = 0x0002;
const int _hwndBroadcast = 0xFFFF;
const int _smtoNormal = 0x0000;
const int _wmSettingChange = 0x001A;
const int _timeoutMs = 1000;
const int _wmThemeChanged = 0x031A;
const int _shcneAssocChanged = 0x08000000;
const int _shcnfIdList = 0x0000;
const int _wmCommand = 0x0111;
const int _cmdToggleDesktopIcons = 0x7402;
const int _dropEffectCopy = 1;
const int _dropEffectMove = 2;
const String _clipboardDropEffectFormat = 'Preferred DropEffect';

// Cache extracted icons by a stable key to avoid repeated FFI work.
const int _iconCacheVersion = 9;
const int _iconCacheCapacity = 64;
final LinkedHashMap<String, Uint8List?> _iconCache =
    LinkedHashMap<String, Uint8List?>();
final Map<String, Future<Uint8List?>> _iconInFlight = {};

class _IconTask {
  final String path;
  final int size;
  final String cacheKey;
  final Completer<Uint8List?> completer;

  _IconTask(this.path, this.size, this.cacheKey, this.completer);
}

final Queue<_IconTask> _iconTaskQueue = Queue<_IconTask>();
int _activeIconIsolates = 0;
// Limit concurrent isolates to avoid creating too many DCs at once.
const int _maxIconIsolates = 3;
final Queue<_IconTask> _mainIconTaskQueue = Queue<_IconTask>();
bool _mainIconDrainScheduled = false;

void _debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

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

int _findDesktopListView() {
  Pointer<Utf16> cn(String s) => s.toNativeUtf16();

  final progmanClass = cn('Progman');
  try {
    final progman = FindWindow(progmanClass, nullptr);

    int defView = 0;
    if (progman != 0) {
      final defViewClass = cn('SHELLDLL_DefView');
      try {
        defView = FindWindowEx(progman, 0, defViewClass, nullptr);
      } finally {
        calloc.free(defViewClass);
      }
    }

    if (defView == 0) {
      final workerWClass = cn('WorkerW');
      final defViewClass = cn('SHELLDLL_DefView');
      try {
        var worker = FindWindowEx(0, 0, workerWClass, nullptr);
        while (worker != 0 && defView == 0) {
          defView = FindWindowEx(worker, 0, defViewClass, nullptr);
          worker = FindWindowEx(0, worker, workerWClass, nullptr);
        }
      } finally {
        calloc.free(workerWClass);
        calloc.free(defViewClass);
      }
    }

    if (defView == 0) return 0;

    final listViewClass = cn('SysListView32');
    final listViewTitle = cn('FolderView');
    try {
      return FindWindowEx(defView, 0, listViewClass, listViewTitle);
    } finally {
      calloc.free(listViewClass);
      calloc.free(listViewTitle);
    }
  } finally {
    calloc.free(progmanClass);
  }
}

typedef _SHGetImageListNative =
    Int32 Function(Int32 iImageList, Pointer<GUID> riid, Pointer<Pointer> ppv);
typedef _SHGetImageListDart =
    int Function(int iImageList, Pointer<GUID> riid, Pointer<Pointer> ppv);

final _SHGetImageListDart _shGetImageList = _shell32
    .lookupFunction<_SHGetImageListNative, _SHGetImageListDart>('#727');

typedef _DrawIconExNative =
    Int32 Function(
      IntPtr hdc,
      Int32 xLeft,
      Int32 yTop,
      IntPtr hIcon,
      Int32 cxWidth,
      Int32 cyWidth,
      Uint32 istepIfAniCur,
      IntPtr hbrFlickerFreeDraw,
      Uint32 diFlags,
    );
typedef _DrawIconExDart =
    int Function(
      int hdc,
      int xLeft,
      int yTop,
      int hIcon,
      int cxWidth,
      int cyWidth,
      int istepIfAniCur,
      int hbrFlickerFreeDraw,
      int diFlags,
    );

final _DrawIconExDart _drawIconEx = _user32
    .lookupFunction<_DrawIconExNative, _DrawIconExDart>('DrawIconEx');

typedef _SHChangeNotifyNative =
    Void Function(Uint32 wEventId, Uint32 uFlags, Pointer pv, Pointer pv2);
typedef _SHChangeNotifyDart =
    void Function(int wEventId, int uFlags, Pointer pv, Pointer pv2);

final _SHChangeNotifyDart _shChangeNotify = _shell32
    .lookupFunction<_SHChangeNotifyNative, _SHChangeNotifyDart>(
      'SHChangeNotify',
    );

typedef _SendMessageTimeoutNative =
    IntPtr Function(
      IntPtr hWnd,
      Uint32 msg,
      IntPtr wParam,
      IntPtr lParam,
      Uint32 fuFlags,
      Uint32 uTimeout,
      Pointer<UintPtr> lpdwResult,
    );
typedef _SendMessageTimeoutDart =
    int Function(
      int hWnd,
      int msg,
      int wParam,
      int lParam,
      int flags,
      int timeout,
      Pointer<UintPtr> result,
    );

final _SendMessageTimeoutDart _sendMessageTimeout = _user32
    .lookupFunction<_SendMessageTimeoutNative, _SendMessageTimeoutDart>(
      'SendMessageTimeoutW',
    );

void _shellNotifyDesktopChanged() {
  _shChangeNotify(_shcneAssocChanged, _shcnfIdList, nullptr, nullptr);
  final result = calloc<UintPtr>();
  try {
    final atom = 'ShellState'.toNativeUtf16();
    _sendMessageTimeout(
      _hwndBroadcast,
      _wmSettingChange,
      0,
      atom.address,
      _smtoAbortIfHung,
      _timeoutMs,
      result,
    );
    calloc.free(atom);
    _sendMessageTimeout(
      _hwndBroadcast,
      _wmThemeChanged,
      0,
      0,
      _smtoNormal,
      _timeoutMs,
      result,
    );
  } catch (_) {
    // ignore
  } finally {
    calloc.free(result);
  }
}

math.Point<int>? getCursorScreenPosition() {
  final pos = calloc<POINT>();
  try {
    final ok = GetCursorPos(pos) != 0;
    if (!ok) return null;
    return math.Point<int>(pos.ref.x, pos.ref.y);
  } finally {
    calloc.free(pos);
  }
}

Future<bool> isDesktopIconsVisible() async {
  final listView = _findDesktopListView();
  if (listView != 0) {
    return IsWindowVisible(listView) != 0;
  }
  try {
    final shell = pr.Shell(runInShell: true, verbose: false);
    final output = await shell.run(
      'reg query HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced /v HideIcons',
    );
    final lines = output.outText.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'\\s+'));
      if (parts.length >= 3 && parts[0].toLowerCase() == 'hideicons') {
        final valueHex = parts.last;
        final value = int.tryParse(valueHex.replaceFirst('0x', ''), radix: 16);
        if (value != null) {
          return value == 0;
        }
      }
    }
  } catch (_) {
    // fall through
  }
  return true;
}

Future<bool> setDesktopIconsVisible(bool visible) async {
  final initialListView = _findDesktopListView();
  if (initialListView != 0) {
    final currentVisible = IsWindowVisible(initialListView) != 0;
    if (currentVisible == visible) return true;

    final progmanClass = 'Progman'.toNativeUtf16();
    final result = calloc<UintPtr>();
    try {
      final progman = FindWindow(progmanClass, nullptr);
      if (progman != 0) {
        _sendMessageTimeout(
          progman,
          _wmCommand,
          _cmdToggleDesktopIcons,
          0,
          _smtoAbortIfHung,
          _timeoutMs,
          result,
        );
      }

      // Fallback: also try the parent of the list view (SHELLDLL_DefView).
      final defView = GetParent(initialListView);
      if (defView != 0) {
        _sendMessageTimeout(
          defView,
          _wmCommand,
          _cmdToggleDesktopIcons,
          0,
          _smtoAbortIfHung,
          _timeoutMs,
          result,
        );
      }
    } finally {
      calloc.free(result);
      calloc.free(progmanClass);
    }

    final deadline = DateTime.now().add(const Duration(milliseconds: 900));
    while (DateTime.now().isBefore(deadline)) {
      final nowListView = _findDesktopListView();
      final nowVisible = nowListView != 0 && IsWindowVisible(nowListView) != 0;
      if (nowVisible == visible) return true;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    // fall back to registry path if the shell window toggle didn't apply.
  }

  final target = visible ? 0 : 1;
  try {
    final shell = pr.Shell(runInShell: true, verbose: false);
    await shell.run(
      'reg add HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced /v HideIcons /t REG_DWORD /d $target /f',
    );
    _shellNotifyDesktopChanged();
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> setAutoLaunchEnabled(
  bool enabled, {
  String appName = 'DeskTidy',
  String? executablePath,
}) async {
  if (!Platform.isWindows) return false;
  final exe = executablePath ?? _getCurrentProcessExecutablePath();
  if (exe.isEmpty) return false;

  try {
    if (enabled) {
      final commandLine = '"$exe"';
      return _setRegistryRunValue(appName: appName, commandLine: commandLine);
    } else {
      return _deleteRegistryRunValue(appName: appName);
    }
  } catch (_) {
    return false;
  }
}

Future<bool> isAutoLaunchEnabled({String appName = 'DeskTidy'}) async {
  if (!Platform.isWindows) return false;
  try {
    return _hasRegistryRunValue(appName: appName);
  } catch (_) {
    return false;
  }
}

String _getCurrentProcessExecutablePath() {
  // Prefer the actual module path (more reliable than Platform.resolvedExecutable
  // in Flutter desktop embedding scenarios).
  var capacity = 260;
  while (capacity <= 32768) {
    final buffer = calloc<WCHAR>(capacity);
    try {
      final length = GetModuleFileName(NULL, buffer.cast<Utf16>(), capacity);
      if (length == 0) return '';
      if (length < capacity - 1) {
        return buffer.cast<Utf16>().toDartString(length: length);
      }
    } finally {
      calloc.free(buffer);
    }
    capacity *= 2;
  }
  return '';
}

const String _registryRunKeyPath =
    r'Software\Microsoft\Windows\CurrentVersion\Run';

bool _setRegistryRunValue({
  required String appName,
  required String commandLine,
}) {
  final subKeyPtr = _registryRunKeyPath.toNativeUtf16();
  final hKeyOut = calloc<HKEY>();
  final openResult = RegOpenKeyEx(
    HKEY_CURRENT_USER,
    subKeyPtr,
    0,
    KEY_SET_VALUE,
    hKeyOut,
  );
  calloc.free(subKeyPtr);
  if (openResult != ERROR_SUCCESS) {
    calloc.free(hKeyOut);
    return false;
  }

  final hKey = hKeyOut.value;
  calloc.free(hKeyOut);

  final valueNamePtr = appName.toNativeUtf16();
  final dataPtr = commandLine.toNativeUtf16();
  final dataBytes = (commandLine.length + 1) * sizeOf<WCHAR>();
  try {
    final setResult = RegSetValueEx(
      hKey,
      valueNamePtr,
      0,
      REG_SZ,
      dataPtr.cast<Uint8>(),
      dataBytes,
    );
    return setResult == ERROR_SUCCESS;
  } finally {
    calloc.free(valueNamePtr);
    calloc.free(dataPtr);
    RegCloseKey(hKey);
  }
}

bool _deleteRegistryRunValue({required String appName}) {
  final subKeyPtr = _registryRunKeyPath.toNativeUtf16();
  final hKeyOut = calloc<HKEY>();
  final openResult = RegOpenKeyEx(
    HKEY_CURRENT_USER,
    subKeyPtr,
    0,
    KEY_SET_VALUE,
    hKeyOut,
  );
  calloc.free(subKeyPtr);
  if (openResult != ERROR_SUCCESS) {
    calloc.free(hKeyOut);
    return false;
  }

  final hKey = hKeyOut.value;
  calloc.free(hKeyOut);

  final valueNamePtr = appName.toNativeUtf16();
  try {
    final deleteResult = RegDeleteValue(hKey, valueNamePtr);
    return deleteResult == ERROR_SUCCESS ||
        deleteResult == ERROR_FILE_NOT_FOUND;
  } finally {
    calloc.free(valueNamePtr);
    RegCloseKey(hKey);
  }
}

bool _hasRegistryRunValue({required String appName}) {
  final subKeyPtr = _registryRunKeyPath.toNativeUtf16();
  final hKeyOut = calloc<HKEY>();
  final openResult = RegOpenKeyEx(
    HKEY_CURRENT_USER,
    subKeyPtr,
    0,
    KEY_QUERY_VALUE,
    hKeyOut,
  );
  calloc.free(subKeyPtr);
  if (openResult != ERROR_SUCCESS) {
    calloc.free(hKeyOut);
    return false;
  }

  final hKey = hKeyOut.value;
  calloc.free(hKeyOut);

  final valueNamePtr = appName.toNativeUtf16();
  final typePtr = calloc<DWORD>();
  final sizePtr = calloc<DWORD>();
  try {
    final querySizeResult = RegQueryValueEx(
      hKey,
      valueNamePtr,
      nullptr,
      typePtr,
      nullptr,
      sizePtr,
    );
    if (querySizeResult == ERROR_FILE_NOT_FOUND) return false;
    if (querySizeResult != ERROR_SUCCESS) return false;
    if (sizePtr.value == 0) return false;

    final data = calloc<Uint8>(sizePtr.value);
    try {
      final queryResult = RegQueryValueEx(
        hKey,
        valueNamePtr,
        nullptr,
        typePtr,
        data,
        sizePtr,
      );
      if (queryResult != ERROR_SUCCESS) return false;
      final type = typePtr.value;
      if (type != REG_SZ && type != REG_EXPAND_SZ) return true;
      final value = data.cast<Utf16>().toDartString();
      return value.trim().isNotEmpty;
    } finally {
      calloc.free(data);
    }
  } finally {
    calloc.free(valueNamePtr);
    calloc.free(typePtr);
    calloc.free(sizePtr);
    RegCloseKey(hKey);
  }
}

class IImageList extends IUnknown {
  IImageList(super.ptr);

  int getIcon(int i, int flags, Pointer<IntPtr> icon) => (ptr.ref.vtable + 10)
      .cast<
        Pointer<
          NativeFunction<Int32 Function(Pointer, Int32, Int32, Pointer<IntPtr>)>
        >
      >()
      .value
      .asFunction<
        int Function(Pointer, int, int, Pointer<IntPtr>)
      >()(ptr.ref.lpVtbl, i, flags, icon);
}

class _IconLocation {
  final String path;
  final int index;

  const _IconLocation(this.path, this.index);
}

class _IconCacheResult {
  final bool found;
  final Uint8List? value;

  const _IconCacheResult({required this.found, this.value});
}

String? _getKnownFolderPath(String folderId) {
  final guidPtr = GUIDFromString(folderId);
  final outPath = calloc<Pointer<Utf16>>();
  final hr = SHGetKnownFolderPath(guidPtr, KF_FLAG_DEFAULT, NULL, outPath);
  calloc.free(guidPtr);
  if (FAILED(hr)) {
    calloc.free(outPath);
    return null;
  }
  final resolved = outPath.value.toDartString();
  CoTaskMemFree(outPath.value.cast());
  calloc.free(outPath);
  return resolved;
}

Future<String> getDesktopPath() async {
  final knownDesktop = _getKnownFolderPath(FOLDERID_Desktop);
  if (knownDesktop != null && knownDesktop.isNotEmpty) {
    return knownDesktop;
  }

  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null && userProfile.isNotEmpty) {
    return path.join(userProfile, 'Desktop');
  }

  return 'C:\\Users\\Public\\Desktop';
}

List<String> _desktopLocations(
  String primaryPath, {
  bool includePublic = true,
}) {
  final destinations = <String>{primaryPath};
  if (includePublic) {
    final publicDesktop = _getKnownFolderPath(FOLDERID_PublicDesktop);
    if (publicDesktop != null && publicDesktop.isNotEmpty) {
      destinations.add(publicDesktop);
    }
  }
  return destinations.toList();
}

List<String> desktopLocations(
  String primaryPath, {
  bool includePublic = true,
}) => _desktopLocations(primaryPath, includePublic: includePublic);

Future<List<String>> getStartMenuLocations() async {
  final locations = <String>{};

  // Current User Start Menu
  final userStartMenu = _getKnownFolderPath(FOLDERID_Programs);
  if (userStartMenu != null && userStartMenu.isNotEmpty) {
    locations.add(userStartMenu);
  }

  // All Users (Common) Start Menu
  final commonStartMenu = _getKnownFolderPath(FOLDERID_CommonPrograms);
  if (commonStartMenu != null && commonStartMenu.isNotEmpty) {
    locations.add(commonStartMenu);
  }

  return locations.toList();
}

Future<List<String>> findSystemTools() async {
  final tools = <String>[];

  // CMD
  final system32 = Platform.environment['SystemRoot'] != null
      ? path.join(Platform.environment['SystemRoot']!, 'System32')
      : r'C:\Windows\System32';

  final cmdPath = path.join(system32, 'cmd.exe');
  if (File(cmdPath).existsSync()) {
    tools.add(cmdPath);
  }

  // PowerShell
  final powershellPath = path.join(
    system32,
    r'WindowsPowerShell\v1.0\powershell.exe',
  );
  if (File(powershellPath).existsSync()) {
    tools.add(powershellPath);
  }

  // Windows Terminal (wt.exe)
  // Check LocalAppData/Microsoft/WindowsApps/wt.exe
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null) {
    final wtPath = path.join(localAppData, r'Microsoft\WindowsApps\wt.exe');
    if (File(wtPath).existsSync()) {
      tools.add(wtPath);
    }
  }

  return tools;
}

bool isHiddenOrSystem(String fullPath) {
  try {
    final ptr = fullPath.toNativeUtf16();
    final attrs = GetFileAttributes(ptr.cast());
    calloc.free(ptr);

    if (attrs == _invalidFileAttributes) return false;
    return (attrs & FILE_ATTRIBUTE_HIDDEN) != 0 ||
        (attrs & FILE_ATTRIBUTE_SYSTEM) != 0;
  } catch (_) {
    return false;
  }
}

/// Move a file or folder to the Recycle Bin (FOF_ALLOWUNDO).
/// Returns true if the shell reports success.
bool moveToRecycleBin(String fullPath) {
  try {
    final op = calloc<SHFILEOPSTRUCT>();
    final from = ('${fullPath}\u0000\u0000').toNativeUtf16();

    op.ref
      ..wFunc = FO_DELETE
      ..pFrom = from
      ..fFlags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_SILENT;

    final hr = SHFileOperation(op);
    calloc.free(from);
    calloc.free(op);
    return hr == 0;
  } catch (_) {
    return false;
  }
}

bool isDirectory(String fullPath) {
  final entity = FileSystemEntity.typeSync(fullPath);
  return entity == FileSystemEntityType.directory;
}

/// Open a file or folder with the system default handler.
Future<bool> openWithDefault(String fullPath) async {
  try {
    final shell = pr.Shell(runInShell: true, verbose: false);
    await shell.run('cmd /c start "" "${fullPath.replaceAll('"', '\\"')}"');
    return true;
  } catch (_) {
    return false;
  }
}

/// Open Windows File Explorer for [fullPath].
///
/// - If [select] is true, attempts to select the file/folder in its parent.
/// - If [select] is false, opens the folder (or selects the file by default).
Future<bool> openInExplorer(String fullPath, {bool? select}) async {
  try {
    if (!Platform.isWindows) return false;
    final shouldSelect = select ?? !isDirectory(fullPath);
    final shell = pr.Shell(runInShell: true, verbose: false);
    final escaped = fullPath.replaceAll('"', '\\"');
    final args = shouldSelect ? '/select,"$escaped"' : '"$escaped"';
    await shell.run('explorer.exe $args');
    return true;
  } catch (_) {
    return false;
  }
}

/// Open target file with a specific application executable.
Future<bool> openWithApp(String appPath, String target) async {
  try {
    final shell = pr.Shell(runInShell: true, verbose: false);
    final quotedApp = '"${appPath.replaceAll('"', '\\"')}"';
    final quotedTarget = '"${target.replaceAll('"', '\\"')}"';
    await shell.run('$quotedApp $quotedTarget');
    return true;
  } catch (_) {
    return false;
  }
}

bool showTrayBalloon({
  required int windowHandle,
  required String title,
  required String message,
  int timeoutMs = 4000,
}) {
  if (!Platform.isWindows || windowHandle == 0) return false;
  final nid = calloc<NOTIFYICONDATA>();
  try {
    nid.ref
      ..cbSize = sizeOf<NOTIFYICONDATA>()
      ..hWnd = windowHandle
      ..uID = 0
      ..uFlags = NIF_INFO
      ..dwInfoFlags = NIIF_INFO
      ..uTimeout = timeoutMs;
    nid.ref.szInfoTitle = title;
    nid.ref.szInfo = message;
    return Shell_NotifyIcon(NIM_MODIFY, nid) != 0;
  } catch (_) {
    return false;
  } finally {
    calloc.free(nid);
  }
}

bool copyEntityPathsToClipboard(List<String> paths, {bool cut = false}) {
  if (!Platform.isWindows) return false;
  final filtered = paths.where((p) => p.trim().isNotEmpty).toList();
  if (filtered.isEmpty) return false;

  final normalized = filtered.map(path.normalize).toList();
  final units = <int>[];
  for (final entry in normalized) {
    units.addAll(entry.codeUnits);
    units.add(0);
  }
  units.add(0);

  final bytes = units.length * sizeOf<Uint16>();
  final totalBytes = sizeOf<DROPFILES>() + bytes;
  final hGlobal = GlobalAlloc(GMEM_MOVEABLE, totalBytes);
  if (hGlobal == nullptr) return false;

  final locked = GlobalLock(hGlobal);
  if (locked == nullptr) {
    GlobalFree(hGlobal);
    return false;
  }

  try {
    final dropFiles = locked.cast<DROPFILES>();
    dropFiles.ref
      ..pFiles = sizeOf<DROPFILES>()
      ..fWide = 1
      ..fNC = 0;
    dropFiles.ref.pt
      ..x = 0
      ..y = 0;

    final dataPtr = (locked.cast<Uint8>() + sizeOf<DROPFILES>()).cast<Uint16>();
    dataPtr.asTypedList(units.length).setAll(0, units);
  } finally {
    GlobalUnlock(hGlobal);
  }

  if (OpenClipboard(NULL) == 0) {
    GlobalFree(hGlobal);
    return false;
  }

  var success = false;
  try {
    if (EmptyClipboard() == 0) {
      GlobalFree(hGlobal);
      return false;
    }
    if (SetClipboardData(CF_HDROP, hGlobal.address) == 0) {
      GlobalFree(hGlobal);
      return false;
    }
    _setClipboardDropEffect(cut ? _dropEffectMove : _dropEffectCopy);
    success = true;
  } finally {
    CloseClipboard();
  }

  return success;
}

void _setClipboardDropEffect(int effect) {
  final formatPtr = _clipboardDropEffectFormat.toNativeUtf16();
  try {
    final format = RegisterClipboardFormat(formatPtr);
    if (format == 0) return;
    final hGlobal = GlobalAlloc(GMEM_MOVEABLE, sizeOf<Uint32>());
    if (hGlobal == nullptr) return;
    final locked = GlobalLock(hGlobal);
    if (locked == nullptr) {
      GlobalFree(hGlobal);
      return;
    }
    try {
      locked.cast<Uint32>().value = effect;
    } finally {
      GlobalUnlock(hGlobal);
    }
    if (SetClipboardData(format, hGlobal.address) == 0) {
      GlobalFree(hGlobal);
    }
  } finally {
    calloc.free(formatPtr);
  }
}

class CopyResult {
  final bool success;
  final String? message;
  final String? destPath;

  const CopyResult({required this.success, this.message, this.destPath});
}

Future<CopyResult> copyEntityToDirectory(
  String sourcePath,
  String targetDirectory,
) async {
  try {
    if (targetDirectory.trim().isEmpty) {
      return const CopyResult(success: false, message: '目标路径为空');
    }
    final destDir = Directory(targetDirectory);
    if (!destDir.existsSync()) {
      return const CopyResult(success: false, message: '目标不存在');
    }

    final baseName = path.basename(sourcePath);
    var destPath = path.join(destDir.path, baseName);
    final normalizedSource = path.normalize(sourcePath);

    // Generate unique name if destination exists
    if (File(destPath).existsSync() || Directory(destPath).existsSync()) {
      final ext = path.extension(baseName);
      final nameWithoutExt = path.basenameWithoutExtension(baseName);
      int count = 1;
      while (true) {
        final newName = '$nameWithoutExt ($count)$ext';
        destPath = path.join(destDir.path, newName);
        if (!File(destPath).existsSync() && !Directory(destPath).existsSync()) {
          break;
        }
        count++;
        if (count > 1000) {
          return const CopyResult(success: false, message: '无法生成唯一文件名');
        }
      }
    }

    final normalizedDest = path.normalize(destPath);
    if (normalizedSource == normalizedDest) {
      return const CopyResult(success: false, message: '目标与源相同');
    }
    if (path.isWithin(normalizedSource, normalizedDest)) {
      return const CopyResult(success: false, message: '目标在源目录内部');
    }

    final type = FileSystemEntity.typeSync(sourcePath, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await _copyDirectoryRecursive(Directory(sourcePath), Directory(destPath));
    } else if (type == FileSystemEntityType.file) {
      await File(sourcePath).copy(destPath);
    } else {
      return const CopyResult(success: false, message: '源不存在');
    }

    return CopyResult(success: true, destPath: destPath);
  } catch (e) {
    return CopyResult(success: false, message: e.toString());
  }
}

Future<void> _copyDirectoryRecursive(
  Directory source,
  Directory destination,
) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final name = path.basename(entity.path);
    final destPath = path.join(destination.path, name);
    if (entity is Directory) {
      await _copyDirectoryRecursive(entity, Directory(destPath));
    } else if (entity is File) {
      await entity.copy(destPath);
    } else if (entity is Link) {
      final target = await entity.target();
      await Link(destPath).create(target);
    }
  }
}

const int SLR_NO_UI = 0x0001;
const int SLGP_SHORTPATH = 0x0001;
const int SLGP_UNCPRIORITY = 0x0002;
const int SLGP_RAWPATH = 0x0004;

String? getShortcutTarget(String lnkPath) {
  try {
    final shellLink = ShellLink.createInstance();
    final persistFile = IPersistFile.from(shellLink);

    final lnkPtr = lnkPath.toNativeUtf16();
    final loadHr = persistFile.load(lnkPtr.cast(), STGM_READ);
    calloc.free(lnkPtr);

    if (loadHr != S_OK) {
      shellLink.release();
      return null;
    }

    shellLink.resolve(0, SLR_NO_UI);

    final pathBuffer = calloc.allocate<Utf16>(MAX_PATH);
    final hr = shellLink.getPath(pathBuffer, MAX_PATH, nullptr, SLGP_RAWPATH);

    String? target;
    if (hr == S_OK) {
      target = pathBuffer.toDartString();
    }

    calloc.free(pathBuffer);
    shellLink.release();
    return target;
  } catch (e) {
    print('解析快捷方式失败: $e');
    return null;
  }
}

Future<List<String>> scanDesktopShortcuts(
  String desktopPath, {
  bool showHidden = false,
}) async {
  final locations = _desktopLocations(desktopPath);
  final shortcuts = <String>{};

  for (final dirPath in locations) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      final found = await scanDirectoryShortcuts(
        dirPath,
        showHidden: showHidden,
        recursive: false,
      );
      shortcuts.addAll(found);
    } catch (_) {}
  }

  return shortcuts.toList();
}

Future<List<String>> scanDirectoryShortcuts(
  String dirPath, {
  bool showHidden = false,
  bool recursive = false,
  Set<String>? visited,
}) async {
  final results = <String>[];
  final visitedDirs = visited ?? <String>{};

  // Basic cycle detection for recursion
  if (visitedDirs.contains(dirPath)) return results;
  visitedDirs.add(dirPath);

  const allowedExtensions = {'.exe', '.lnk', '.url', '.appref-ms'};

  try {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return results;

    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      final name = path.basename(entity.path);
      final lowerName = name.toLowerCase();

      // Filter hidden/system if needed
      if (!showHidden &&
          (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
        continue;
      }

      if (lowerName == 'desktop.ini' || lowerName == 'thumbs.db') {
        continue;
      }

      final type = FileSystemEntity.typeSync(entity.path);

      if (type == FileSystemEntityType.file) {
        final ext = path.extension(lowerName);
        // Only add if it's an executable or shortcut
        if (allowedExtensions.contains(ext)) {
          results.add(entity.path);
        }
      } else if (recursive && type == FileSystemEntityType.directory) {
        // Recursive scan
        final subResults = await scanDirectoryShortcuts(
          entity.path,
          showHidden: showHidden,
          recursive: true,
          visited: visitedDirs,
        );
        results.addAll(subResults);
      }
    }
  } catch (e) {
    // Ignore access errors etc.
    // print('Scan failed for $dirPath: $e');
  }

  return results;
}

Uint8List? extractIcon(String filePath, {int size = 64}) {
  // Try to locate the icon resource via shell, then extract a high-res icon via
  // PrivateExtractIconsW (handles PNG-in-ICO as well). Fallback to SHGetFileInfo
  // HICON if needed.
  final comReady = _ensureComReady();
  try {
    final desiredSize = size.clamp(16, 256);

    final primaryKey = _cacheKeyForFile(filePath, desiredSize);
    final primaryCached = _readIconCache(primaryKey);
    if (primaryCached.found) return primaryCached.value;

    Uint8List? cachedValue;
    _IconLocation? cachedLocation;

    final location = _getIconLocation(filePath);
    if (location != null && location.path.isNotEmpty) {
      final cacheKey = _cacheKeyForLocation(location, desiredSize);
      final existing = _readIconCache(cacheKey);
      if (existing.found) return existing.value;

      final hicon = _extractHiconFromLocation(
        location.path,
        location.index,
        desiredSize,
      );
      if (hicon != 0) {
        final png = _encodeHicon(hicon, size: desiredSize);
        DestroyIcon(hicon);
        if (png != null && png.isNotEmpty) {
          _writeIconCache(cacheKey, png);
          cachedLocation = location;
          cachedValue = png;
        }
      }
    }

    if (cachedValue == null) {
      String? targetPath;
      final ext = path.extension(filePath).toLowerCase();
      const imageExts = {'.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp'};

      if (imageExts.contains(ext)) {
        targetPath = filePath;
      } else if (ext == '.lnk') {
        try {
          final resolved = getShortcutTarget(filePath);
          if (resolved != null &&
              imageExts.contains(path.extension(resolved).toLowerCase())) {
            targetPath = resolved;
          }
        } catch (_) {}
      }

      if (targetPath != null) {
        try {
          final file = File(targetPath);
          if (file.existsSync()) {
            final bytes = file.readAsBytesSync();
            if (bytes.isNotEmpty) {
              final image = img.decodeImage(bytes);
              if (image != null) {
                img.Image resized = image;
                if (image.width > desiredSize || image.height > desiredSize) {
                  if (image.width > image.height) {
                    resized = img.copyResize(image, width: desiredSize);
                  } else {
                    resized = img.copyResize(image, height: desiredSize);
                  }
                }

                final png = Uint8List.fromList(img.encodePng(resized));
                if (png.isNotEmpty) {
                  cachedValue = png;
                  _writeIconCache(primaryKey, png);
                }
              }
            }
          }
        } catch (e) {
          _debugLog('Failed to generate thumbnail for $targetPath: $e');
        }
      }
    }

    if (cachedValue == null) {
      // Check for video files
      final ext = path.extension(filePath).toLowerCase();
      const videoExts = {
        '.mp4',
        '.mkv',
        '.avi',
        '.mov',
        '.wmv',
        '.flv',
        '.webm',
        '.m4v',
        '.mpg',
        '.mpeg',
        '.3gp',
      };

      String? videoPath;
      if (videoExts.contains(ext)) {
        videoPath = filePath;
      } else if (ext == '.lnk') {
        // Check if link points to video
        try {
          final resolved = getShortcutTarget(filePath);
          if (resolved != null &&
              videoExts.contains(path.extension(resolved).toLowerCase())) {
            videoPath = resolved;
          }
        } catch (_) {}
      }

      if (videoPath != null) {
        cachedValue = _extractThumbnailShell(videoPath, desiredSize);
        if (cachedValue != null) {
          _writeIconCache(primaryKey, cachedValue);
        }
      }
    }

    if (cachedValue == null) {
      final jumbo = _extractJumboIconPng(filePath, desiredSize);
      if (jumbo != null && jumbo.isNotEmpty) {
        final idx = _getSystemIconIndex(filePath);
        if (idx >= 0) {
          _writeIconCache(_cacheKeyForSystemIndex(idx, desiredSize), jumbo);
        }
        cachedValue = jumbo;
      }
    }

    // Fallback: obtain HICON from shell, draw it into a 32bpp DIB, then encode.
    if (cachedValue == null) {
      final pathPtr = filePath.toNativeUtf16();
      final shFileInfo = calloc<SHFILEINFO>();
      final isVirtual =
          filePath.startsWith('::') ||
          filePath.startsWith('shell::') ||
          filePath.contains(',');
      final hr = SHGetFileInfo(
        pathPtr.cast(),
        0,
        shFileInfo.cast(),
        sizeOf<SHFILEINFO>(),
        SHGFI_ICON |
            SHGFI_LARGEICON |
            (isVirtual ? 0 : SHGFI_USEFILEATTRIBUTES),
      );
      calloc.free(pathPtr);
      if (hr == 0) {
        calloc.free(shFileInfo);
        return null;
      }

      final iconHandle = shFileInfo.ref.hIcon;
      calloc.free(shFileInfo);
      if (iconHandle == 0) {
        return null;
      }

      cachedValue = _encodeHicon(iconHandle, size: desiredSize);
      DestroyIcon(iconHandle);
    }

    final finalKey = cachedLocation != null
        ? _cacheKeyForLocation(cachedLocation, desiredSize)
        : primaryKey;
    _writeIconCache(finalKey, cachedValue);
    return cachedValue;
  } finally {
    if (comReady) {
      CoUninitialize();
    }
  }
}

Uint8List? _extractJumboIconPng(String filePath, int desiredSize) {
  final iconIndex = _getSystemIconIndex(filePath);
  if (iconIndex < 0) return null;

  final cacheKey = _cacheKeyForSystemIndex(iconIndex, desiredSize);
  final cached = _readIconCache(cacheKey);
  if (cached.found) return cached.value;

  final iid = convertToIID(_iidIImageList);
  final imageListPtr = calloc<COMObject>();
  try {
    final hr = _shGetImageList(_shilJumbo, iid, imageListPtr.cast());
    if (FAILED(hr) || imageListPtr.ref.isNull) return null;

    final imageList = IImageList(imageListPtr);
    final hiconPtr = calloc<IntPtr>();
    try {
      final hr2 = imageList.getIcon(
        iconIndex,
        _ildTransparent | _ildImage,
        hiconPtr,
      );
      if (FAILED(hr2) || hiconPtr.value == 0) return null;
      final png = _encodeHicon(hiconPtr.value, size: desiredSize);
      DestroyIcon(hiconPtr.value);
      if (png != null && png.isNotEmpty) {
        _writeIconCache(cacheKey, png);
      }
      return png;
    } finally {
      calloc.free(hiconPtr);
      imageList.detach();
      imageList.release();
    }
  } catch (_) {
    return null;
  } finally {
    calloc.free(iid);
    calloc.free(imageListPtr);
  }
}

int _getSystemIconIndex(String filePath) {
  final attrs = _fileAttributesForSystemIcon(filePath);
  final pathPtr = filePath.toNativeUtf16();
  final shFileInfo = calloc<SHFILEINFO>();
  final isVirtual =
      filePath.startsWith('::') ||
      filePath.startsWith('shell::') ||
      filePath.contains(',');
  final hr = SHGetFileInfo(
    pathPtr.cast(),
    isVirtual ? 0 : attrs,
    shFileInfo.cast(),
    sizeOf<SHFILEINFO>(),
    SHGFI_SYSICONINDEX | (isVirtual ? 0 : SHGFI_USEFILEATTRIBUTES),
  );
  calloc.free(pathPtr);
  if (hr == 0) {
    calloc.free(shFileInfo);
    return -1;
  }
  final index = shFileInfo.ref.iIcon;
  calloc.free(shFileInfo);
  return index;
}

int _fileAttributesForSystemIcon(String filePath) {
  try {
    final type = FileSystemEntity.typeSync(filePath, followLinks: false);
    if (type == FileSystemEntityType.directory) return FILE_ATTRIBUTE_DIRECTORY;
    return FILE_ATTRIBUTE_NORMAL;
  } catch (_) {
    final ext = path.extension(filePath).toLowerCase();
    if (ext.isEmpty) return FILE_ATTRIBUTE_NORMAL;
    return FILE_ATTRIBUTE_NORMAL;
  }
}

_IconLocation? _getIconLocation(String filePath) {
  // Support manual resource path: "path,index"
  if (filePath.contains(',')) {
    final parts = filePath.split(',');
    if (parts.length == 2) {
      final path = parts[0].trim();
      final indexStr = parts[1].trim();
      final index = int.tryParse(indexStr);
      if (index != null) {
        return _IconLocation(path, index);
      }
    }
  }

  final pathPtr = filePath.toNativeUtf16();
  final shFileInfo = calloc<SHFILEINFO>();
  final result = SHGetFileInfo(
    pathPtr.cast(),
    0,
    shFileInfo.cast(),
    sizeOf<SHFILEINFO>(),
    SHGFI_ICONLOCATION,
  );
  calloc.free(pathPtr);
  if (result == 0) {
    calloc.free(shFileInfo);
    return null;
  }

  final iconPath = shFileInfo.ref.szDisplayName;
  final iconIndex = shFileInfo.ref.iIcon;
  calloc.free(shFileInfo);

  if (iconPath.isEmpty) return null;
  return _IconLocation(iconPath, iconIndex);
}

int _extractHiconFromLocation(String iconPath, int iconIndex, int size) {
  final iconPathPtr = iconPath.toNativeUtf16();
  final hiconPtr = calloc<IntPtr>();
  final iconIdPtr = calloc<Uint32>();

  final extracted = PrivateExtractIcons(
    iconPathPtr.cast(),
    iconIndex,
    size,
    size,
    hiconPtr,
    iconIdPtr,
    1,
    0,
  );

  calloc.free(iconPathPtr);
  calloc.free(iconIdPtr);

  final hicon = hiconPtr.value;
  calloc.free(hiconPtr);

  if (extracted <= 0 || hicon == 0) return 0;
  return hicon;
}

Uint8List? _encodeHicon(int icon, {required int size}) {
  return _hiconToPngBitmap(icon, size: size) ?? _hiconToPng(icon, size: size);
}

Uint8List? _hiconToPng(int icon, {required int size}) {
  final screenDC = GetDC(NULL);
  if (screenDC == 0) return null;
  final memDC = CreateCompatibleDC(screenDC);
  if (memDC == 0) {
    ReleaseDC(NULL, screenDC);
    return null;
  }

  final bmi = calloc<BITMAPINFO>();
  final ppBits = calloc<Pointer<Void>>();
  var dib = 0;
  var oldBmp = 0;
  try {
    bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
    bmi.ref.bmiHeader.biWidth = size;
    bmi.ref.bmiHeader.biHeight = -size; // top-down DIB
    bmi.ref.bmiHeader.biPlanes = 1;
    bmi.ref.bmiHeader.biBitCount = 32;
    bmi.ref.bmiHeader.biCompression = BI_RGB;

    dib = CreateDIBSection(screenDC, bmi, DIB_RGB_COLORS, ppBits, NULL, 0);
    if (dib == 0) return null;

    oldBmp = SelectObject(memDC, dib);
    final pixelCount = size * size * 4;
    final pixelsView = ppBits.value.cast<Uint8>().asTypedList(pixelCount);
    pixelsView.fillRange(0, pixelsView.length, 0);

    _drawIconEx(memDC, 0, 0, icon, size, size, 0, NULL, _diNormal);

    final pixels = Uint8List.fromList(pixelsView);
    final image = img.Image.fromBytes(
      width: size,
      height: size,
      bytes: pixels.buffer,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
      rowStride: size * 4,
    );

    final mask = _readMaskBitsFromIcon(icon, image.width, image.height);
    final alphaMeaningful = _alphaHasMeaning(image);
    if (mask != null) {
      _applyMaskToAlpha(image, mask, alphaMeaningful: alphaMeaningful);
    } else if (!alphaMeaningful) {
      _forceOpaque(image);
    }
    _unpremultiplyAlphaIfNeeded(image);

    final output = (image.width == size && image.height == size)
        ? image
        : img.copyResize(
            image,
            width: size,
            height: size,
            interpolation: img.Interpolation.cubic,
          );

    return Uint8List.fromList(img.encodePng(output));
  } finally {
    if (oldBmp != 0) {
      SelectObject(memDC, oldBmp);
    }
    if (dib != 0) {
      DeleteObject(dib);
    }
    DeleteDC(memDC);
    ReleaseDC(NULL, screenDC);
    calloc.free(ppBits);
    calloc.free(bmi);
  }
}

Uint8List? _hiconToPngBitmap(int icon, {required int size}) {
  final iconInfo = calloc<ICONINFO>();
  var hbmMask = 0;
  var hbmColor = 0;
  try {
    final ok = GetIconInfo(icon, iconInfo);
    if (ok == 0) return null;
    hbmMask = iconInfo.ref.hbmMask;
    hbmColor = iconInfo.ref.hbmColor;
    if (hbmColor == 0) return _hiconToPng(icon, size: size);

    return _bitmapToPng(hbmColor, size: size, hbmMask: hbmMask);
  } finally {
    if (hbmMask != 0) DeleteObject(hbmMask);
    if (hbmColor != 0) DeleteObject(hbmColor);
    calloc.free(iconInfo);
  }
}

Uint8List? _bitmapToPng(int hbitmap, {required int size, int hbmMask = 0}) {
  final bitmap = calloc<BITMAP>();
  try {
    final res = GetObject(hbitmap, sizeOf<BITMAP>(), bitmap.cast());
    if (res == 0) return null;
    final width = bitmap.ref.bmWidth;
    final height = bitmap.ref.bmHeight.abs();
    if (width <= 0 || height <= 0) return null;

    final stride = width * 4;
    final buffer = calloc<Uint8>(stride * height);
    final bmi = calloc<BITMAPINFO>();
    final dc = GetDC(NULL);
    try {
      if (dc == 0) return null;
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = width;
      bmi.ref.bmiHeader.biHeight = -height;
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 32;
      bmi.ref.bmiHeader.biCompression = BI_RGB;
      final lines = GetDIBits(
        dc,
        hbitmap,
        0,
        height,
        buffer.cast(),
        bmi,
        DIB_RGB_COLORS,
      );
      if (lines == 0) return null;

      final pixels = Uint8List.fromList(buffer.asTypedList(stride * height));
      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: pixels.buffer,
        numChannels: 4,
        order: img.ChannelOrder.bgra,
        rowStride: stride,
      );

      final mask = hbmMask != 0
          ? _readMaskBits(hbmMask, width, height, hasColor: true)
          : null;
      final alphaMeaningful = _alphaHasMeaning(image);
      if (mask != null) {
        _applyMaskToAlpha(image, mask, alphaMeaningful: alphaMeaningful);
      } else if (!alphaMeaningful) {
        _forceOpaque(image);
      }
      _unpremultiplyAlphaIfNeeded(image);

      img.Image output = image;
      if (image.width > size || image.height > size) {
        if (image.width >= image.height) {
          output = img.copyResize(
            image,
            width: size,
            interpolation: img.Interpolation.cubic,
          );
        } else {
          output = img.copyResize(
            image,
            height: size,
            interpolation: img.Interpolation.cubic,
          );
        }
      }

      return Uint8List.fromList(img.encodePng(output));
    } finally {
      if (dc != 0) ReleaseDC(NULL, dc);
      calloc.free(bmi);
      calloc.free(buffer);
    }
  } finally {
    calloc.free(bitmap);
  }
}

// SIIGBF flags
const int _siigbfResizeToFit = 0x00;
const int _siigbfBiggerSizeOk = 0x01;
const int _siigbfMemoryOnly = 0x02;
const int _siigbfIconOnly = 0x04;
const int _siigbfThumbnailOnly = 0x08;
const int _siigbfInCacheOnly = 0x10;

Uint8List? _extractThumbnailShell(String pathStr, int size) {
  final pathPtr = pathStr.toNativeUtf16();
  final riid = convertToIID(IID_IShellItemImageFactory);
  final ppv = calloc<Pointer>();

  try {
    final hr = SHCreateItemFromParsingName(pathPtr, nullptr, riid, ppv);
    if (FAILED(hr)) return null;

    final factory = IShellItemImageFactory(ppv.cast());
    final phbm = calloc<IntPtr>();

    // Windows expects SIZE struct by value?
    // In win32 package, GetImage definition:
    // int GetImage(SIZE size, int flags, Pointer<IntPtr> phbm)
    final sz = calloc<SIZE>();
    sz.ref.cx = size;
    sz.ref.cy = size;

    try {
      final hr2 = factory.getImage(sz.ref, _siigbfResizeToFit, phbm);
      if (FAILED(hr2) || phbm.value == 0) return null;

      final hbitmap = phbm.value;
      try {
        return _bitmapToPng(hbitmap, size: size);
      } finally {
        DeleteObject(hbitmap);
      }
    } finally {
      calloc.free(sz);
      calloc.free(phbm);
      factory.release();
    }
  } catch (e) {
    debugPrint('Shell thumbnail error: $e');
    return null;
  } finally {
    calloc.free(pathPtr);
    calloc.free(riid);
    calloc.free(ppv);
  }
}

class _MaskBits {
  final Uint8List bytes;
  final int width;
  final int height;
  final int rowBytes;

  const _MaskBits(this.bytes, this.width, this.height, this.rowBytes);
}

_MaskBits? _readMaskBitsFromIcon(int hicon, int maxWidth, int maxHeight) {
  final iconInfo = calloc<ICONINFO>();
  var hbmMask = 0;
  var hbmColor = 0;
  try {
    final ok = GetIconInfo(hicon, iconInfo);
    if (ok == 0) return null;
    hbmMask = iconInfo.ref.hbmMask;
    hbmColor = iconInfo.ref.hbmColor;
    if (hbmMask == 0) return null;
    return _readMaskBits(hbmMask, maxWidth, maxHeight, hasColor: hbmColor != 0);
  } finally {
    if (hbmMask != 0) DeleteObject(hbmMask);
    if (hbmColor != 0) DeleteObject(hbmColor);
    calloc.free(iconInfo);
  }
}

_MaskBits? _readMaskBits(
  int hbmMask,
  int maxWidth,
  int maxHeight, {
  required bool hasColor,
}) {
  final bitmap = calloc<BITMAP>();
  try {
    final res = GetObject(hbmMask, sizeOf<BITMAP>(), bitmap.cast());
    if (res == 0) return null;
    final maskWidth = bitmap.ref.bmWidth;
    var maskHeight = bitmap.ref.bmHeight.abs();
    if (!hasColor && maskHeight >= maxHeight * 2) {
      maskHeight = maskHeight ~/ 2;
    }

    final targetWidth = math.min(maxWidth, maskWidth);
    final targetHeight = math.min(maxHeight, maskHeight);
    if (targetWidth <= 0 || targetHeight <= 0) return null;

    final rowBytes = ((maskWidth + 31) ~/ 32) * 4;
    final totalBytes = rowBytes * maskHeight;
    final buffer = calloc<Uint8>(totalBytes);
    final bmi = calloc<BITMAPINFO>();
    final dc = GetDC(NULL);
    try {
      if (dc == 0) return null;
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = maskWidth;
      bmi.ref.bmiHeader.biHeight = -maskHeight;
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 1;
      bmi.ref.bmiHeader.biCompression = BI_RGB;
      final lines = GetDIBits(
        dc,
        hbmMask,
        0,
        maskHeight,
        buffer.cast(),
        bmi,
        DIB_RGB_COLORS,
      );
      if (lines == 0) return null;

      final bytes = Uint8List.fromList(buffer.asTypedList(totalBytes));
      return _MaskBits(bytes, targetWidth, targetHeight, rowBytes);
    } finally {
      if (dc != 0) ReleaseDC(NULL, dc);
      calloc.free(bmi);
      calloc.free(buffer);
    }
  } finally {
    calloc.free(bitmap);
  }
}

bool _alphaHasMeaning(img.Image image) {
  if (!image.hasAlpha) return false;
  var hasTransparent = false;
  var hasOpaque = false;
  for (final p in image) {
    final a = p.a.toInt();
    if (a == 0) {
      hasTransparent = true;
    } else if (a == 255) {
      hasOpaque = true;
    } else {
      return true;
    }
  }
  return hasTransparent && hasOpaque;
}

void _applyMaskToAlpha(
  img.Image image,
  _MaskBits mask, {
  required bool alphaMeaningful,
}) {
  if (!image.hasAlpha) return;
  final width = math.min(image.width, mask.width);
  final height = math.min(image.height, mask.height);
  final bytes = mask.bytes;
  for (var y = 0; y < height; y++) {
    final rowOffset = y * mask.rowBytes;
    for (var x = 0; x < width; x++) {
      final byteIndex = rowOffset + (x >> 3);
      final bitMask = 0x80 >> (x & 7);
      final transparent = (bytes[byteIndex] & bitMask) != 0;
      final p = image.getPixel(x, y);
      if (transparent) {
        p
          ..r = 0
          ..g = 0
          ..b = 0
          ..a = 0;
      } else if (!alphaMeaningful) {
        p.a = 255;
      }
    }
  }
}

void _forceOpaque(img.Image image) {
  if (!image.hasAlpha) return;
  for (final p in image) {
    p.a = 255;
  }
}

void _unpremultiplyAlphaIfNeeded(img.Image image) {
  if (!image.hasAlpha) return;
  if (!_isLikelyPremultiplied(image)) return;
  _unpremultiplyAlpha(image);
}

bool _isLikelyPremultiplied(img.Image image) {
  if (!image.hasAlpha) return false;
  var samples = 0;
  var premultiplied = 0;
  for (final p in image) {
    final a = p.a.toInt();
    if (a == 0 || a == 255) continue;
    samples++;
    if (p.r <= a && p.g <= a && p.b <= a) {
      premultiplied++;
    }
    if (samples >= 2000) break;
  }
  if (samples == 0) return false;
  return premultiplied / samples >= 0.9;
}

void _unpremultiplyAlpha(img.Image image) {
  for (final p in image) {
    final a = p.a.toInt();
    if (a == 0) {
      p
        ..r = 0
        ..g = 0
        ..b = 0;
      continue;
    }
    if (a >= 255) continue;
    final scale = 255.0 / a;
    p
      ..r = (p.r * scale).round().clamp(0, 255)
      ..g = (p.g * scale).round().clamp(0, 255)
      ..b = (p.b * scale).round().clamp(0, 255);
  }
}

Future<Uint8List?> extractIconAsync(String filePath, {int size = 64}) {
  final desiredSize = size.clamp(16, 256);
  final cacheKey = _cacheKeyForFile(filePath, desiredSize);
  final cached = _readIconCache(cacheKey);
  if (cached.found) return Future.value(cached.value);

  final existing = _iconInFlight[cacheKey];
  if (existing != null) return existing;

  final completer = Completer<Uint8List?>();
  _iconInFlight[cacheKey] = completer.future;
  _iconTaskQueue.add(_IconTask(filePath, desiredSize, cacheKey, completer));
  _drainIconTasks();
  return completer.future;
}

void _drainIconTasks() {
  while (_activeIconIsolates < _maxIconIsolates && _iconTaskQueue.isNotEmpty) {
    final task = _iconTaskQueue.removeFirst();
    _activeIconIsolates++;
    final path = task.path;
    final size = task.size;

    _runIconIsolate(path, size)
        .then((data) {
          final result = (data == null || data.isEmpty) ? null : data;
          if (result != null) {
            _writeIconCache(task.cacheKey, result);
            task.completer.complete(result);
            _iconInFlight.remove(task.cacheKey);
          } else {
            _debugLog('icon isolate empty: ${task.path} size=${task.size}');
            _mainIconTaskQueue.add(task);
            _scheduleMainIconDrain();
          }
        })
        .catchError((err, st) {
          _debugLog(
            'icon isolate error: ${task.path} size=${task.size} err=$err\n$st',
          );
          _mainIconTaskQueue.add(task);
          _scheduleMainIconDrain();
        })
        .whenComplete(() {
          _activeIconIsolates--;
          _drainIconTasks();
        });
  }
}

void _scheduleMainIconDrain() {
  if (_mainIconDrainScheduled) return;
  _mainIconDrainScheduled = true;
  Future<void>(() async {
    while (_mainIconTaskQueue.isNotEmpty) {
      final task = _mainIconTaskQueue.removeFirst();
      Uint8List? result;
      try {
        result = extractIcon(task.path, size: task.size);
      } catch (_) {
        _debugLog('icon main fallback error: ${task.path} size=${task.size}');
        result = null;
      }
      _writeIconCache(task.cacheKey, result);
      if (!task.completer.isCompleted) {
        task.completer.complete(result);
      }
      _iconInFlight.remove(task.cacheKey);
      // Yield between tasks to keep UI responsive.
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    _mainIconDrainScheduled = false;
  });
}

_IconCacheResult _readIconCache(String key) {
  if (!_iconCache.containsKey(key)) return const _IconCacheResult(found: false);
  return _IconCacheResult(found: true, value: _iconCache[key]);
}

void _writeIconCache(String key, Uint8List? value) {
  if (value == null) return;
  // Refresh insertion order for LRU.
  _iconCache.remove(key);
  _iconCache[key] = value;
  while (_iconCache.length > _iconCacheCapacity) {
    _iconCache.remove(_iconCache.keys.first);
  }
}

String _cacheKeyForLocation(_IconLocation loc, int size) =>
    'v$_iconCacheVersion|loc:${path.normalize(loc.path)}|${loc.index}|$size';

String _cacheKeyForSystemIndex(int index, int size) =>
    'v$_iconCacheVersion|sys:$index|$size';

String _cacheKeyForFile(String filePath, int size) =>
    'v$_iconCacheVersion|file:${path.normalize(filePath)}|$size';

bool _ensureComReady() {
  final hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  return hr == S_OK || hr == S_FALSE;
}

Uint8List? _extractIconIsolate(String path, int size) {
  return extractIcon(path, size: size);
}

Future<Uint8List?> _runIconIsolate(String path, int size) async {
  final port = ReceivePort();
  await Isolate.spawn(_iconIsolateEntry, <Object>[port.sendPort, path, size]);
  final message = await port.first;
  port.close();
  if (message is TransferableTypedData) {
    return message.materialize().asUint8List();
  }
  if (message is Uint8List) {
    return message;
  }
  return null;
}

void _iconIsolateEntry(List<Object> args) {
  final sendPort = args[0] as SendPort;
  final path = args[1] as String;
  final size = args[2] as int;
  final bytes = _extractIconIsolate(path, size);
  if (bytes == null || bytes.isEmpty) {
    sendPort.send(null);
    return;
  }
  sendPort.send(TransferableTypedData.fromList([bytes]));
}

List<String> getClipboardFilePaths() {
  if (!Platform.isWindows) return [];
  if (OpenClipboard(NULL) == 0) return [];

  final paths = <String>[];
  try {
    final hDrop = GetClipboardData(CF_HDROP);
    if (hDrop != 0) {
      final count = DragQueryFile(hDrop, 0xFFFFFFFF, nullptr, 0);
      for (var i = 0; i < count; i++) {
        final len = DragQueryFile(hDrop, i, nullptr, 0);
        if (len > 0) {
          final buffer = calloc<Uint16>(len + 1);
          try {
            DragQueryFile(hDrop, i, buffer.cast<Utf16>(), len + 1);
            paths.add(buffer.cast<Utf16>().toDartString());
          } finally {
            calloc.free(buffer);
          }
        }
      }
    }
  } finally {
    CloseClipboard();
  }
  return paths;
}

Future<String?> createNewFolder(
  String parentPath, {
  String preferredName = '新建文件夹',
}) async {
  try {
    final dir = Directory(parentPath);
    if (!dir.existsSync()) return null;

    String targetName = preferredName;
    String targetPath = path.join(parentPath, targetName);
    int counter = 2;

    while (Directory(targetPath).existsSync() ||
        File(targetPath).existsSync()) {
      targetName = '$preferredName ($counter)';
      targetPath = path.join(parentPath, targetName);
      counter++;
    }

    await Directory(targetPath).create();
    return targetPath;
  } catch (e) {
    debugPrint('Error creating folder: $e');
    return null;
  }
}

Future<void> showInExplorer(String targetPath) async {
  try {
    // explorer.exe /select,"path" opens the folder and selects the file.
    await Process.run('explorer.exe', ['/select,', targetPath]);
  } catch (e) {
    debugPrint('Error showing in explorer: $e');
  }
}
