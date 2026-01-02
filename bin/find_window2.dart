import 'dart:ffi';

import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';

/// 通过窗口标题精确查找（大小写敏感与否取决于系统比较方式，但基本是“完全相等”）
/// 找到返回 hwnd(>0)，否则返回 0
int findWindowByExactTitle(String title) {
  final lpWindowName = title.toNativeUtf16();
  // 类名不限制的话传 nullptr
  final hwnd = FindWindow(nullptr, lpWindowName);
  calloc.free(lpWindowName);
  return hwnd;
}

bool existsWindowByExactTitle(String title) => findWindowByExactTitle(title) != 0;

void main() {
  final hwnd = findWindowByExactTitle('DESK_TIDY_WIN32_WINDOW');
  if (hwnd != 0) {
    print('找到了窗口: hwnd=0x${hwnd.toRadixString(16)}');
  } else {
    print('没找到');
  }
}
