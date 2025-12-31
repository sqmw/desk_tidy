import 'dart:ffi';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:process_run/shell.dart' as pr;

const int INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF;

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

typedef _SHGetImageListNative = Int32 Function(
  Int32 iImageList,
  Pointer<GUID> riid,
  Pointer<Pointer> ppv,
);
typedef _SHGetImageListDart = int Function(
  int iImageList,
  Pointer<GUID> riid,
  Pointer<Pointer> ppv,
);

final _SHGetImageListDart _shGetImageList =
    _shell32.lookupFunction<_SHGetImageListNative, _SHGetImageListDart>('#727');

typedef _DrawIconExNative = Int32 Function(
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
typedef _DrawIconExDart = int Function(
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

final _DrawIconExDart _drawIconEx =
    _user32.lookupFunction<_DrawIconExNative, _DrawIconExDart>('DrawIconEx');

typedef _SHChangeNotifyNative = Void Function(
  Uint32 wEventId,
  Uint32 uFlags,
  Pointer pv,
  Pointer pv2,
);
typedef _SHChangeNotifyDart = void Function(
  int wEventId,
  int uFlags,
  Pointer pv,
  Pointer pv2,
);

final _SHChangeNotifyDart _shChangeNotify =
    _shell32.lookupFunction<_SHChangeNotifyNative, _SHChangeNotifyDart>(
  'SHChangeNotify',
);

typedef _SendMessageTimeoutNative = IntPtr Function(
  IntPtr hWnd,
  Uint32 msg,
  IntPtr wParam,
  IntPtr lParam,
  Uint32 fuFlags,
  Uint32 uTimeout,
  Pointer<UintPtr> lpdwResult,
);
typedef _SendMessageTimeoutDart = int Function(
  int hWnd,
  int msg,
  int wParam,
  int lParam,
  int flags,
  int timeout,
  Pointer<UintPtr> result,
);

final _SendMessageTimeoutDart _sendMessageTimeout =
    _user32.lookupFunction<_SendMessageTimeoutNative, _SendMessageTimeoutDart>(
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

class IImageList extends IUnknown {
  IImageList(super.ptr);

  int getIcon(int i, int flags, Pointer<IntPtr> icon) => (ptr.ref.vtable + 10)
          .cast<
              Pointer<
                  NativeFunction<
                      Int32 Function(
                          Pointer, Int32, Int32, Pointer<IntPtr>)>>>()
          .value
          .asFunction<int Function(Pointer, int, int, Pointer<IntPtr>)>()(
        ptr.ref.lpVtbl,
        i,
        flags,
        icon,
      );
}

class _IconLocation {
  final String path;
  final int index;

  const _IconLocation(this.path, this.index);
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

List<String> _desktopLocations(String primaryPath,
    {bool includePublic = true}) {
  final destinations = <String>{primaryPath};
  if (includePublic) {
    final publicDesktop = _getKnownFolderPath(FOLDERID_PublicDesktop);
    if (publicDesktop != null && publicDesktop.isNotEmpty) {
      destinations.add(publicDesktop);
    }
  }
  return destinations.toList();
}

List<String> desktopLocations(String primaryPath,
        {bool includePublic = true}) =>
    _desktopLocations(primaryPath, includePublic: includePublic);

bool isHiddenOrSystem(String fullPath) {
  try {
    final ptr = fullPath.toNativeUtf16();
    final attrs = GetFileAttributes(ptr.cast());
    calloc.free(ptr);

    if (attrs == INVALID_FILE_ATTRIBUTES) return false;
    return (attrs & FILE_ATTRIBUTE_HIDDEN) != 0 ||
        (attrs & FILE_ATTRIBUTE_SYSTEM) != 0;
  } catch (_) {
    return false;
  }
}

class DesktopItemsHiddenResult {
  final int updated;
  final int skipped;
  final int failed;

  const DesktopItemsHiddenResult({
    required this.updated,
    required this.skipped,
    required this.failed,
  });
}

String _desktopHiddenStorePath() {
  final appData =
      Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'];
  final base = (appData != null && appData.isNotEmpty)
      ? appData
      : Directory.current.path;
  return path.join(base, 'desk_tidy', 'desktop_hidden.json');
}

void _writeDesktopHiddenStore(List<String> paths) {
  final storePath = _desktopHiddenStorePath();
  final dir = Directory(path.dirname(storePath));
  dir.createSync(recursive: true);
  final file = File(storePath);
  final payload = <String, Object?>{
    'version': 1,
    'paths': paths,
    'updatedAt': DateTime.now().toIso8601String(),
  };
  file.writeAsStringSync(jsonEncode(payload));
}

List<String> _readDesktopHiddenStorePaths() {
  final storePath = _desktopHiddenStorePath();
  final file = File(storePath);
  if (!file.existsSync()) return const [];
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) return const [];
    final paths = decoded['paths'];
    if (paths is! List) return const [];
    return paths.whereType<String>().toList();
  } catch (_) {
    return const [];
  }
}

void _deleteDesktopHiddenStore() {
  final storePath = _desktopHiddenStorePath();
  final file = File(storePath);
  if (file.existsSync()) {
    try {
      file.deleteSync();
    } catch (_) {}
  }
}

bool hasDesktopHiddenStore() {
  final storePath = _desktopHiddenStorePath();
  return File(storePath).existsSync();
}

int _getFileAttributesSafe(String fullPath) {
  try {
    final ptr = fullPath.toNativeUtf16();
    final attrs = GetFileAttributes(ptr.cast());
    calloc.free(ptr);
    return attrs;
  } catch (_) {
    return INVALID_FILE_ATTRIBUTES;
  }
}

bool _setFileAttributesSafe(String fullPath, int attrs) {
  try {
    final ptr = fullPath.toNativeUtf16();
    final ok = SetFileAttributes(ptr.cast(), attrs) != 0;
    calloc.free(ptr);
    return ok;
  } catch (_) {
    return false;
  }
}

Future<DesktopItemsHiddenResult> setDesktopItemsHidden(
  String desktopPath, {
  required bool hidden,
  bool includePublic = true,
}) async {
  if (hidden) {
    int updated = 0;
    int skipped = 0;
    int failed = 0;
    final updatedPaths = <String>[];

    final directories = desktopLocations(
      desktopPath,
      includePublic: includePublic,
    );
    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync()) {
        final name = path.basename(entity.path);
        final lower = name.toLowerCase();
        if (lower == 'desktop.ini' || lower == 'thumbs.db') {
          skipped++;
          continue;
        }

        final attrs = _getFileAttributesSafe(entity.path);
        if (attrs == INVALID_FILE_ATTRIBUTES) {
          failed++;
          continue;
        }

        if ((attrs & FILE_ATTRIBUTE_SYSTEM) != 0 ||
            (attrs & FILE_ATTRIBUTE_HIDDEN) != 0) {
          skipped++;
          continue;
        }

        final ok =
            _setFileAttributesSafe(entity.path, attrs | FILE_ATTRIBUTE_HIDDEN);
        if (ok) {
          updated++;
          updatedPaths.add(entity.path);
        } else {
          failed++;
        }
      }
    }

    _writeDesktopHiddenStore(updatedPaths);
    return DesktopItemsHiddenResult(
      updated: updated,
      skipped: skipped,
      failed: failed,
    );
  } else {
    int updated = 0;
    int skipped = 0;
    int failed = 0;

    final paths = _readDesktopHiddenStorePaths();
    for (final fullPath in paths) {
      if (FileSystemEntity.typeSync(fullPath) ==
          FileSystemEntityType.notFound) {
        skipped++;
        continue;
      }
      final attrs = _getFileAttributesSafe(fullPath);
      if (attrs == INVALID_FILE_ATTRIBUTES) {
        failed++;
        continue;
      }
      if ((attrs & FILE_ATTRIBUTE_HIDDEN) == 0) {
        skipped++;
        continue;
      }
      final ok =
          _setFileAttributesSafe(fullPath, attrs & ~FILE_ATTRIBUTE_HIDDEN);
      if (ok) {
        updated++;
      } else {
        failed++;
      }
    }

    _deleteDesktopHiddenStore();
    return DesktopItemsHiddenResult(
      updated: updated,
      skipped: skipped,
      failed: failed,
    );
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
  final directories = _desktopLocations(desktopPath);
  final shortcuts = <String>{};
  const allowedExtensions = {
    '.exe',
    '.lnk',
    '.url',
    '.appref-ms',
  };

  for (final dirPath in directories) {
    try {
      final desktopDir = Directory(dirPath);
      if (!desktopDir.existsSync()) continue;

      await for (final entity in desktopDir.list()) {
        final name = path.basename(entity.path);
        final lowerName = name.toLowerCase();

        if (!showHidden &&
            (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
          continue;
        }

        if (lowerName == 'desktop.ini' || lowerName == 'thumbs.db') {
          continue;
        }

        if (entity is File) {
          final ext = path.extension(lowerName);
          if (!allowedExtensions.contains(ext)) continue;
          shortcuts.add(entity.path);
        }
      }
    } catch (e) {
      print('扫描桌面失败 ($dirPath): $e');
    }
  }

  return shortcuts.toList();
}

Uint8List? extractIcon(String filePath, {int size = 64}) {
  // Try to locate the icon resource via shell, then extract a high-res icon via
  // PrivateExtractIconsW (handles PNG-in-ICO as well). Fallback to SHGetFileInfo
  // HICON if needed.
  final desiredSize = size.clamp(16, 256);

  final location = _getIconLocation(filePath);
  if (location != null && location.path.isNotEmpty) {
    final hicon =
        _extractHiconFromLocation(location.path, location.index, desiredSize);
    if (hicon != 0) {
      final png = _hiconToPng(hicon, size: desiredSize);
      DestroyIcon(hicon);
      if (png != null && png.isNotEmpty) return png;
    }
  }

  final jumbo = _extractJumboIconPng(filePath, desiredSize);
  if (jumbo != null && jumbo.isNotEmpty) return jumbo;

  // Fallback: obtain HICON from shell, draw it into a 32bpp DIB, then encode.
  final pathPtr = filePath.toNativeUtf16();
  final shFileInfo = calloc<SHFILEINFO>();
  final hr = SHGetFileInfo(
    pathPtr.cast(),
    0,
    shFileInfo.cast(),
    sizeOf<SHFILEINFO>(),
    SHGFI_ICON | SHGFI_LARGEICON,
  );
  calloc.free(pathPtr);
  if (hr == 0) {
    calloc.free(shFileInfo);
    return null;
  }

  final iconHandle = shFileInfo.ref.hIcon;
  calloc.free(shFileInfo);
  if (iconHandle == 0) return null;

  final png = _hiconToPng(iconHandle, size: desiredSize);
  DestroyIcon(iconHandle);
  return png;
}

Uint8List? _extractJumboIconPng(String filePath, int desiredSize) {
  final iconIndex = _getSystemIconIndex(filePath);
  if (iconIndex < 0) return null;

  final iid = convertToIID(_iidIImageList);
  final imageListPtr = calloc<COMObject>();
  try {
    final hr = _shGetImageList(_shilJumbo, iid, imageListPtr.cast());
    if (FAILED(hr) || imageListPtr.ref.isNull) return null;

    final imageList = IImageList(imageListPtr);
    final hiconPtr = calloc<IntPtr>();
    try {
      final hr2 =
          imageList.getIcon(iconIndex, _ildTransparent | _ildImage, hiconPtr);
      if (FAILED(hr2) || hiconPtr.value == 0) return null;
      final png = _hiconToPng(hiconPtr.value, size: desiredSize);
      DestroyIcon(hiconPtr.value);
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
  final hr = SHGetFileInfo(
    pathPtr.cast(),
    attrs,
    shFileInfo.cast(),
    sizeOf<SHFILEINFO>(),
    SHGFI_SYSICONINDEX | SHGFI_USEFILEATTRIBUTES,
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

Uint8List? _hiconToPng(int icon, {required int size}) {
  final screenDC = GetDC(NULL);
  if (screenDC == 0) return null;
  final memDC = CreateCompatibleDC(screenDC);

  final bmi = calloc<BITMAPINFO>();
  bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
  bmi.ref.bmiHeader.biWidth = size;
  bmi.ref.bmiHeader.biHeight = -size; // top-down DIB
  bmi.ref.bmiHeader.biPlanes = 1;
  bmi.ref.bmiHeader.biBitCount = 32;
  bmi.ref.bmiHeader.biCompression = BI_RGB;

  final ppBits = calloc<Pointer<Void>>();
  final dib = CreateDIBSection(screenDC, bmi, DIB_RGB_COLORS, ppBits, NULL, 0);
  if (dib == 0) {
    calloc.free(ppBits);
    calloc.free(bmi);
    DeleteDC(memDC);
    ReleaseDC(NULL, screenDC);
    return null;
  }

  final oldBmp = SelectObject(memDC, dib);
  final pixelCount = size * size * 4;
  final pixels = ppBits.value.cast<Uint8>().asTypedList(pixelCount);
  pixels.fillRange(0, pixels.length, 0);

  _drawIconEx(memDC, 0, 0, icon, size, size, 0, NULL, _diNormal);

  final image = img.Image.fromBytes(
    width: size,
    height: size,
    bytes: pixels.buffer,
    numChannels: 4,
    order: img.ChannelOrder.bgra,
    rowStride: size * 4,
  );

  final normalized = _normalizeIcon(image, fill: 0.92);

  final png = Uint8List.fromList(
    img.encodePng(
      normalized,
    ),
  );

  SelectObject(memDC, oldBmp);
  DeleteObject(dib);
  DeleteDC(memDC);
  ReleaseDC(NULL, screenDC);
  calloc.free(ppBits);
  calloc.free(bmi);
  return png;
}

img.Image _normalizeIcon(img.Image source, {double fill = 0.92}) {
  final width = source.width;
  final height = source.height;
  if (width == 0 || height == 0) return source;

  const alphaThreshold = 4;
  var minX = width;
  var minY = height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = source.getPixel(x, y);
      if (p.a > alphaThreshold) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX < 0 || maxY < 0) return source;

  minX = math.max(0, minX - 1);
  minY = math.max(0, minY - 1);
  maxX = math.min(width - 1, maxX + 1);
  maxY = math.min(height - 1, maxY + 1);

  final cropWidth = maxX - minX + 1;
  final cropHeight = maxY - minY + 1;
  if (cropWidth <= 0 || cropHeight <= 0) return source;

  final cropped = img.copyCrop(
    source,
    x: minX,
    y: minY,
    width: cropWidth,
    height: cropHeight,
  );

  final targetEdge = (width * fill).round().clamp(1, width);
  final scale =
      math.min(targetEdge / cropped.width, targetEdge / cropped.height);
  final scaledWidth = math.max(1, (cropped.width * scale).round());
  final scaledHeight = math.max(1, (cropped.height * scale).round());

  final resized = img.copyResize(
    cropped,
    width: scaledWidth,
    height: scaledHeight,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(width: width, height: height);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  img.compositeImage(
    canvas,
    resized,
    dstX: ((width - scaledWidth) / 2).round(),
    dstY: ((height - scaledHeight) / 2).round(),
  );

  return canvas;
}
