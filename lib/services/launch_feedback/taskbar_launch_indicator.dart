import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'taskbar_progress_controller.dart';
import 'taskbar_window_identity.dart';
import 'taskbar_window_icon_animation_factory.dart';

const int _flashwStop = 0x00000000;
const int _flashwTray = 0x00000002;
const int _flashwTimerNoFg = 0x0000000C;
const int _indicatorWindowExStyle = WS_EX_APPWINDOW | WS_EX_NOACTIVATE;
const int _indicatorWindowStyle = WS_POPUP | WS_MINIMIZE | WS_DISABLED;

final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
final int Function(Pointer<_FlashWindowInfo>) _flashWindowEx = _user32
    .lookupFunction<
      Int32 Function(Pointer<_FlashWindowInfo>),
      int Function(Pointer<_FlashWindowInfo>)
    >('FlashWindowEx');

final class _FlashWindowInfo extends Struct {
  @Uint32()
  external int cbSize;

  @IntPtr()
  external int hwnd;

  @Uint32()
  external int dwFlags;

  @Uint32()
  external int uCount;

  @Uint32()
  external int dwTimeout;
}

final class _LoadedIcon {
  const _LoadedIcon({required this.handle, required this.owned});

  final int handle;
  final bool owned;
}

class TaskbarLaunchIndicator {
  TaskbarLaunchIndicator._(
    this._hwnd,
    this._iconSourcePath,
    this._preferredIconBytes,
    this._iconHandle,
    this._iconOwned,
    this._taskbarProgress,
  );

  final int _hwnd;
  final String _iconSourcePath;
  final Uint8List? _preferredIconBytes;
  final int _iconHandle;
  final bool _iconOwned;
  final TaskbarProgressController? _taskbarProgress;
  Timer? _windowIconSpinTimer;
  List<int> _windowIconSpinHandles = const [];
  int _windowIconSpinFrame = 0;
  bool _closed = false;

  static TaskbarLaunchIndicator? show({
    required String iconSourcePath,
    required String appDisplayName,
    Uint8List? preferredIconBytes,
  }) {
    if (!Platform.isWindows) return null;

    final displayName = appDisplayName.trim().isEmpty ? '应用' : appDisplayName;
    final windowTitle = '正在启动 $displayName';
    final classNamePtr = 'STATIC'.toNativeUtf16();
    final titlePtr = windowTitle.toNativeUtf16();
    try {
      final hwnd = CreateWindowEx(
        _indicatorWindowExStyle,
        classNamePtr,
        titlePtr,
        _indicatorWindowStyle,
        -32000,
        -32000,
        320,
        120,
        0,
        0,
        GetModuleHandle(nullptr),
        nullptr,
      );
      if (hwnd == 0) return null;

      final icon = _loadWindowIcon(iconSourcePath);
      if (icon.handle != 0) {
        SendMessage(hwnd, WM_SETICON, ICON_BIG, icon.handle);
        SendMessage(hwnd, WM_SETICON, ICON_SMALL, icon.handle);
      }

      TaskbarWindowIdentity.applyToIndicatorWindow(
        hwnd: hwnd,
        appDisplayName: displayName,
        iconSourcePath: iconSourcePath,
      );

      ShowWindow(hwnd, SW_SHOWMINNOACTIVE);
      UpdateWindow(hwnd);
      return TaskbarLaunchIndicator._(
        hwnd,
        iconSourcePath,
        preferredIconBytes,
        icon.handle,
        icon.owned,
        TaskbarProgressController.create(),
      );
    } finally {
      free(classNamePtr);
      free(titlePtr);
    }
  }

  void startAttentionPulse() {
    if (_closed) return;
    _flashTaskbar(flags: _flashwTray | _flashwTimerNoFg, count: 0);
    _taskbarProgress?.startIndeterminate(_hwnd);
    _startWindowIconSpinner();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _windowIconSpinTimer?.cancel();
    _windowIconSpinTimer = null;

    _taskbarProgress?.stop(_hwnd);
    _taskbarProgress?.dispose();

    _flashTaskbar(flags: _flashwStop, count: 0);
    DestroyWindow(_hwnd);
    for (final hIcon in _windowIconSpinHandles) {
      if (hIcon != 0) {
        DestroyIcon(hIcon);
      }
    }
    _windowIconSpinHandles = const [];
    if (_iconOwned && _iconHandle != 0) {
      DestroyIcon(_iconHandle);
    }
  }

  void _startWindowIconSpinner() {
    _windowIconSpinHandles =
        TaskbarWindowIconAnimationFactory.createIconHandles(
          iconSourcePath: _iconSourcePath,
          preferredIconBytes: _preferredIconBytes,
        );
    if (_windowIconSpinHandles.isEmpty) return;

    _windowIconSpinFrame = 0;
    _applyWindowIconSpinFrame();
    _windowIconSpinTimer?.cancel();
    _windowIconSpinTimer = Timer.periodic(const Duration(milliseconds: 85), (
      _,
    ) {
      if (_closed || _windowIconSpinHandles.isEmpty) return;
      _windowIconSpinFrame =
          (_windowIconSpinFrame + 1) % _windowIconSpinHandles.length;
      _applyWindowIconSpinFrame();
    });
  }

  void _applyWindowIconSpinFrame() {
    if (_windowIconSpinHandles.isEmpty) return;
    final frameIcon = _windowIconSpinHandles[_windowIconSpinFrame];
    SendMessage(_hwnd, WM_SETICON, ICON_BIG, frameIcon);
    SendMessage(_hwnd, WM_SETICON, ICON_SMALL, frameIcon);
  }

  void _flashTaskbar({required int flags, required int count}) {
    final flashInfo = calloc<_FlashWindowInfo>();
    try {
      flashInfo.ref
        ..cbSize = sizeOf<_FlashWindowInfo>()
        ..hwnd = _hwnd
        ..dwFlags = flags
        ..uCount = count
        ..dwTimeout = 0;
      _flashWindowEx(flashInfo);
    } finally {
      calloc.free(flashInfo);
    }
  }
}

_LoadedIcon _loadWindowIcon(String iconSourcePath) {
  final normalized = iconSourcePath.trim();
  if (normalized.isNotEmpty) {
    final pathPtr = normalized.toNativeUtf16();
    final info = calloc<SHFILEINFO>();
    try {
      final result = SHGetFileInfo(
        pathPtr,
        FILE_ATTRIBUTE_NORMAL,
        info,
        sizeOf<SHFILEINFO>(),
        SHGFI_ICON | SHGFI_LARGEICON,
      );
      if (result != 0 && info.ref.hIcon != 0) {
        return _LoadedIcon(handle: info.ref.hIcon, owned: true);
      }
    } finally {
      free(pathPtr);
      calloc.free(info);
    }
  }

  final fallbackIcon = LoadIcon(0, IDI_APPLICATION);
  return _LoadedIcon(handle: fallbackIcon, owned: false);
}
