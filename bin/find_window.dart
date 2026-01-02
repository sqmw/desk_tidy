import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

String _targetClass = 'DESK_TIDY_WIN32_WINDOW';
late Pointer<Utf16> _classBuf;
int _foundHwnd = 0;

@pragma('vm:entry-point')
int _enumProc(int hwnd, int lParam) {
  final len = GetClassName(hwnd, _classBuf, 256);
  if (len > 0) {
    final cls = _classBuf.toDartString(length: len);
    if (cls == _targetClass) {
      _foundHwnd = hwnd;
      return 0; // stop enumeration
    }
  }
  return 1; // continue
}

/// Find the first top-level window whose class name matches [argv[0]].
/// Prints the HWND in hex if found; exits with code 1 when not found or args missing.
void main(List<String> args) {
  _targetClass = args.isNotEmpty ? args.first : 'DESK_TIDY_WIN32_WINDOW';
  _classBuf = wsalloc(256);
  _foundHwnd = 0;

  final cb = Pointer.fromFunction<WNDENUMPROC>(_enumProc, 1); // default continue
  EnumWindows(cb, 0);

  free(_classBuf);

  if (_foundHwnd == 0) {
    stdout.writeln('not found');
    exitCode = 1;
    return;
  }

  stdout.writeln(
      'found HWND=0x${_foundHwnd.toRadixString(16).padLeft(8, '0')}');
}
