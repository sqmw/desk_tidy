part of '../desktop_helper.dart';

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
    final from = ('$fullPath\u0000\u0000').toNativeUtf16();

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
    if (!Platform.isWindows) {
      final shell = pr.Shell(runInShell: true, verbose: false);
      await shell.run('cmd /c start "" "${fullPath.replaceAll('"', '\\"')}"');
      return true;
    }

    final ext = path.extension(fullPath).toLowerCase();
    final opPtr = 'open'.toNativeUtf16();
    final filePtr = fullPath.toNativeUtf16();
    final dir = ext == '.exe' ? path.dirname(fullPath) : '';
    Pointer<Utf16> dirPtr = nullptr;
    if (dir.isNotEmpty) {
      dirPtr = dir.toNativeUtf16();
    }
    final result = ShellExecute(
      0,
      opPtr,
      filePtr,
      nullptr,
      dirPtr,
      SW_SHOWNORMAL,
    );
    calloc.free(opPtr);
    calloc.free(filePtr);
    if (dirPtr != nullptr) {
      calloc.free(dirPtr);
    }

    // ShellExecute success code is > 32.
    if (result > 32) return true;

    // Fallback to cmd start when shell execute fails.
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
