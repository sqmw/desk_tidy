import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

const _clsidTaskbarList = '{56FDF344-FD6D-11d0-958A-006097C9A090}';
const _iidITaskbarList3 = '{EA1AFB91-9E28-4B86-90E9-9E9F8A5EEA84}';

const _tbpfNoProgress = 0;
const _tbpfIndeterminate = 0x1;

class TaskbarProgressController {
  TaskbarProgressController._(this._taskbarList3, this._shouldUninitializeCom);

  final _ITaskbarList3 _taskbarList3;
  final bool _shouldUninitializeCom;
  bool _disposed = false;

  static TaskbarProgressController? create() {
    final hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    final shouldUninitializeCom = hr == S_OK || hr == S_FALSE;

    try {
      final taskbarList3 = _ITaskbarList3(
        COMObject.createFromID(_clsidTaskbarList, _iidITaskbarList3),
      );
      final initHr = taskbarList3.hrInit();
      if (FAILED(initHr)) {
        taskbarList3.detach();
        taskbarList3.release();
        if (shouldUninitializeCom) {
          CoUninitialize();
        }
        return null;
      }
      return TaskbarProgressController._(taskbarList3, shouldUninitializeCom);
    } catch (_) {
      if (shouldUninitializeCom) {
        CoUninitialize();
      }
      return null;
    }
  }

  void startIndeterminate(int hwnd) {
    if (_disposed) return;
    _taskbarList3.setProgressState(hwnd, _tbpfIndeterminate);
  }

  void stop(int hwnd) {
    if (_disposed) return;
    _taskbarList3.setProgressState(hwnd, _tbpfNoProgress);
  }

  void setOverlayIcon(int hwnd, int hIcon, String description) {
    if (_disposed) return;
    _taskbarList3.setOverlayIcon(hwnd, hIcon, description);
  }

  void clearOverlayIcon(int hwnd) {
    if (_disposed) return;
    _taskbarList3.clearOverlayIcon(hwnd);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _taskbarList3.detach();
    _taskbarList3.release();
    if (_shouldUninitializeCom) {
      CoUninitialize();
    }
  }
}

class _ITaskbarList3 extends IUnknown {
  _ITaskbarList3(super.ptr);

  int hrInit() => (ptr.ref.vtable + 3)
      .cast<Pointer<NativeFunction<Int32 Function(Pointer)>>>()
      .value
      .asFunction<int Function(Pointer)>()(ptr.ref.lpVtbl);

  int setProgressState(int hwnd, int flags) =>
      (ptr.ref.vtable + 10)
          .cast<
            Pointer<
              NativeFunction<Int32 Function(Pointer, IntPtr hwnd, Int32 flags)>
            >
          >()
          .value
          .asFunction<int Function(Pointer, int hwnd, int flags)>()(
        ptr.ref.lpVtbl,
        hwnd,
        flags,
      );

  int setOverlayIcon(int hwnd, int hIcon, String description) {
    final descriptionPtr = description.toNativeUtf16();
    try {
      return (ptr.ref.vtable + 18)
          .cast<
            Pointer<
              NativeFunction<
                Int32 Function(
                  Pointer,
                  IntPtr hwnd,
                  IntPtr hIcon,
                  Pointer<Utf16> pszDescription,
                )
              >
            >
          >()
          .value
          .asFunction<
            int Function(Pointer, int hwnd, int hIcon, Pointer<Utf16>)
          >()(ptr.ref.lpVtbl, hwnd, hIcon, descriptionPtr);
    } finally {
      free(descriptionPtr);
    }
  }

  int clearOverlayIcon(int hwnd) => (ptr.ref.vtable + 18)
      .cast<
        Pointer<
          NativeFunction<
            Int32 Function(
              Pointer,
              IntPtr hwnd,
              IntPtr hIcon,
              Pointer<Utf16> pszDescription,
            )
          >
        >
      >()
      .value
      .asFunction<
        int Function(Pointer, int hwnd, int hIcon, Pointer<Utf16>)
      >()(ptr.ref.lpVtbl, hwnd, 0, nullptr);
}
