import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'taskbar_overlay_spinner_icon_factory.dart';
import 'taskbar_progress_controller.dart';
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
    this._iconHandle,
    this._iconOwned,
    this._taskbarProgress,
  );

  final int _hwnd;
  final String _iconSourcePath;
  final int _iconHandle;
  final bool _iconOwned;
  final TaskbarProgressController? _taskbarProgress;
  Timer? _overlaySpinTimer;
  Timer? _windowIconAnimationTimer;
  List<int> _overlaySpinIcons = const [];
  List<int> _windowAnimatedIcons = const [];
  int _overlaySpinFrame = 0;
  int _windowIconFrame = 0;
  bool _closed = false;

  static TaskbarLaunchIndicator? show({required String iconSourcePath}) {
    if (!Platform.isWindows) return null;

    final classNamePtr = 'STATIC'.toNativeUtf16();
    final titlePtr = ''.toNativeUtf16();
    try {
      final hwnd = CreateWindowEx(
        _indicatorWindowExStyle,
        classNamePtr,
        titlePtr,
        _indicatorWindowStyle,
        -32000,
        -32000,
        1,
        1,
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

      ShowWindow(hwnd, SW_SHOWMINNOACTIVE);
      UpdateWindow(hwnd);
      return TaskbarLaunchIndicator._(
        hwnd,
        iconSourcePath,
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
    _startWindowIconAnimation();
    _startOverlaySpinner();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _overlaySpinTimer?.cancel();
    _overlaySpinTimer = null;
    _windowIconAnimationTimer?.cancel();
    _windowIconAnimationTimer = null;

    _taskbarProgress?.clearOverlayIcon(_hwnd);
    _taskbarProgress?.stop(_hwnd);
    _taskbarProgress?.dispose();

    for (final hIcon in _overlaySpinIcons) {
      if (hIcon != 0) {
        DestroyIcon(hIcon);
      }
    }
    _overlaySpinIcons = const [];
    for (final hIcon in _windowAnimatedIcons) {
      if (hIcon != 0) {
        DestroyIcon(hIcon);
      }
    }
    _windowAnimatedIcons = const [];

    _flashTaskbar(flags: _flashwStop, count: 0);
    DestroyWindow(_hwnd);
    if (_iconOwned && _iconHandle != 0) {
      DestroyIcon(_iconHandle);
    }
  }

  void _startOverlaySpinner() {
    if (_taskbarProgress == null) return;
    _overlaySpinIcons = TaskbarOverlaySpinnerIconFactory.createIconHandles();
    if (_overlaySpinIcons.isEmpty) return;

    _overlaySpinFrame = 0;
    _applyOverlayFrame();
    _overlaySpinTimer?.cancel();
    _overlaySpinTimer = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (_closed || _overlaySpinIcons.isEmpty) return;
      _overlaySpinFrame = (_overlaySpinFrame + 1) % _overlaySpinIcons.length;
      _applyOverlayFrame();
    });
  }

  void _startWindowIconAnimation() {
    _windowAnimatedIcons =
        TaskbarWindowIconAnimationFactory.createAnimatedWindowIconHandles(
          iconSourcePath: _iconSourcePath,
        );
    if (_windowAnimatedIcons.isEmpty) return;

    _windowIconFrame = 0;
    _applyWindowIconFrame();
    _windowIconAnimationTimer?.cancel();
    _windowIconAnimationTimer = Timer.periodic(
      const Duration(milliseconds: 95),
      (_) {
        if (_closed || _windowAnimatedIcons.isEmpty) return;
        _windowIconFrame = (_windowIconFrame + 1) % _windowAnimatedIcons.length;
        _applyWindowIconFrame();
      },
    );
  }

  void _applyWindowIconFrame() {
    if (_windowAnimatedIcons.isEmpty) return;
    final hIcon = _windowAnimatedIcons[_windowIconFrame];
    SendMessage(_hwnd, WM_SETICON, ICON_BIG, hIcon);
    SendMessage(_hwnd, WM_SETICON, ICON_SMALL, hIcon);
  }

  void _applyOverlayFrame() {
    if (_overlaySpinIcons.isEmpty) return;
    _taskbarProgress?.setOverlayIcon(
      _hwnd,
      _overlaySpinIcons[_overlaySpinFrame],
      '启动中',
    );
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
