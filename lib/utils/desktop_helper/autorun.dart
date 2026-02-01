part of '../desktop_helper.dart';

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
