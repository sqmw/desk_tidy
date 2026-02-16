import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

const _appUserModelFmtid = '{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}';
const _baseAppUserModelId = 'DeskTidy.LaunchFeedback';

final DynamicLibrary _shell32 = DynamicLibrary.open('shell32.dll');
final int Function(int, Pointer<GUID>, Pointer<Pointer>)
_shGetPropertyStoreForWindow = _shell32
    .lookupFunction<
      Int32 Function(IntPtr hwnd, Pointer<GUID> riid, Pointer<Pointer> ppv),
      int Function(int hwnd, Pointer<GUID> riid, Pointer<Pointer> ppv)
    >('SHGetPropertyStoreForWindow');

class TaskbarWindowIdentity {
  TaskbarWindowIdentity._();

  static void applyToIndicatorWindow({
    required int hwnd,
    required String appDisplayName,
    required String iconSourcePath,
  }) {
    if (!Platform.isWindows || hwnd == 0) return;

    final handle = _openPropertyStore(hwnd);
    if (handle == null) return;

    try {
      final normalizedIconPath = _normalizePath(iconSourcePath);
      final displayName = _sanitizeDisplayName(appDisplayName);
      final appModelId = _buildAppUserModelId(
        normalizedIconPath: normalizedIconPath,
        displayName: displayName,
      );

      _setStringProperty(handle.store, pid: 5, value: appModelId);
      _setStringProperty(handle.store, pid: 4, value: '正在启动 $displayName');

      handle.store.commit();
    } finally {
      handle.store.detach();
      handle.store.release();
      free(handle.rawPointer);
    }
  }

  static _PropertyStoreHandle? _openPropertyStore(int hwnd) {
    final iid = GUIDFromString(IID_IPropertyStore);
    final propertyStorePtr = calloc<COMObject>();
    try {
      final hr = _shGetPropertyStoreForWindow(
        hwnd,
        iid,
        propertyStorePtr.cast(),
      );
      if (FAILED(hr)) {
        free(propertyStorePtr);
        return null;
      }

      return _PropertyStoreHandle(
        store: IPropertyStore(propertyStorePtr),
        rawPointer: propertyStorePtr,
      );
    } finally {
      free(iid);
    }
  }

  static void _setStringProperty(
    IPropertyStore store, {
    required int pid,
    required String value,
  }) {
    if (value.trim().isEmpty) return;

    final key = calloc<PROPERTYKEY>()
      ..ref.fmtid.setGUID(_appUserModelFmtid)
      ..ref.pid = pid;
    final propVariant = calloc<PROPVARIANT>();
    final valuePtr = value.toNativeUtf16();
    try {
      PropVariantInit(propVariant);
      propVariant.ref.vt = VT_LPWSTR;
      propVariant.ref.pwszVal = valuePtr;
      store.setValue(key, propVariant);
    } finally {
      free(valuePtr);
      free(propVariant);
      free(key);
    }
  }

  static String _normalizePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return '';
    try {
      return File(trimmed).absolute.path;
    } catch (_) {
      return trimmed;
    }
  }

  static String _sanitizeDisplayName(String rawName) {
    final trimmed = rawName.trim();
    return trimmed.isEmpty ? '应用' : trimmed;
  }

  static String _buildAppUserModelId({
    required String normalizedIconPath,
    required String displayName,
  }) {
    final seed = normalizedIconPath.isEmpty ? displayName : normalizedIconPath;
    final hash = _fnv1a32(seed.toLowerCase());
    final suffix = hash.toRadixString(16).padLeft(8, '0');
    return '$_baseAppUserModelId.$suffix';
  }

  static int _fnv1a32(String value) {
    var hash = 0x811c9dc5;
    const prime = 0x01000193;
    for (final codePoint in value.codeUnits) {
      hash ^= codePoint;
      hash = (hash * prime) & 0xffffffff;
    }
    return hash;
  }
}

final class _PropertyStoreHandle {
  const _PropertyStoreHandle({required this.store, required this.rawPointer});

  final IPropertyStore store;
  final Pointer<COMObject> rawPointer;
}
