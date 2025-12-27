import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:path/path.dart' as path;

Future<String> getDesktopPath() async {
  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null) {
    return path.join(userProfile, 'Desktop');
  }
  return 'C:\\Users\\Public\\Desktop';
}

// ===== Win32 Shortcut Constants (自己定义的) =====
const int SLR_NO_UI = 0x0001;
const int SLGP_SHORTPATH = 0x0001;
const int SLGP_UNCPRIORITY = 0x0002;
const int SLGP_RAWPATH = 0x0004;

/// 解析 Windows 快捷方式 .lnk 文件目标路径
String? getShortcutTarget(String lnkPath) {
  try {
    final shellLink = ShellLink.createInstance();
    final persistFile = IPersistFile.from(shellLink);

    // 载入快捷方式
    final lnkPtr = lnkPath.toNativeUtf16();
    final loadHr = persistFile.load(lnkPtr.cast(), STGM_READ);
    calloc.free(lnkPtr);

    if (loadHr != S_OK) {
      shellLink.release();
      return null;
    }

    // 解析快捷方式（不弹 UI）
    shellLink.resolve(0, SLR_NO_UI);

    // 分配 Utf16 缓冲区
    final pathBuffer = calloc.allocate<Utf16>(MAX_PATH);

    // 获取目标路径
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

/// 扫描桌面目录，返回可执行应用程序列表（包含 .exe 和指向 .exe 的快捷方式）。
Future<List<String>> scanDesktopShortcuts(
    String desktopPath, {
      bool showHidden = false,  // 新增参数
    }) async {
  final shortcuts = <String>[];

  try {
    final desktopDir = Directory(desktopPath);
    if (!await desktopDir.exists()) return shortcuts;

    await for (final entity in desktopDir.list()) {
      final name = path.basename(entity.path);

      // 如果不显示隐藏，则跳过以 "." 开头或隐藏文件
      if (!showHidden && name.startsWith('.')) {
        continue;
      }

      // 处理文件
      if (entity is File) {
        final ext = name.toLowerCase();

        // 直接 .exe
        if (ext.endsWith('.exe')) {
          shortcuts.add(entity.path);
          continue;
        }

        // .lnk 快捷方式
        if (ext.endsWith('.lnk')) {
          final target = getShortcutTarget(entity.path);
          if (target != null && target.toLowerCase().endsWith('.exe')) {
            shortcuts.add(entity.path);
          }
        }
      }
    }
  } catch (e) {
    print('扫描桌面失败: $e');
  }

  return shortcuts;
}

