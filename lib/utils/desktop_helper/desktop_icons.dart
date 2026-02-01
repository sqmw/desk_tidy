part of '../desktop_helper.dart';

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
