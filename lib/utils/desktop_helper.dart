import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
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
      bool showHidden = false,
    }) async {
  final shortcuts = <String>[];

  try {
    final desktopDir = Directory(desktopPath);
    if (!await desktopDir.exists()) return shortcuts;

    await for (final entity in desktopDir.list()) {
      final name = path.basename(entity.path);

      if (!showHidden && name.startsWith('.')) {
        continue;
      }

      if (entity is File) {
        final ext = name.toLowerCase();

        if (ext.endsWith('.exe')) {
          shortcuts.add(entity.path);
          continue;
        }

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

/// 从文件路径提取图标并返回 PNG 格式的字节数据
Uint8List? extractIcon(String filePath) {
  try {
    final filePathPtr = filePath.toNativeUtf16();

    final shFileInfo = calloc<SHFILEINFO>();
    final flags = SHGFI_ICON | SHGFI_LARGEICON | SHGFI_USEFILEATTRIBUTES;

    final hIcon = SHGetFileInfo(
      filePathPtr.cast(),
      FILE_ATTRIBUTE_NORMAL,
      shFileInfo.cast(),
      sizeOf<SHFILEINFO>(),
      flags,
    );

    calloc.free(filePathPtr);

    if (hIcon == 0) {
      calloc.free(shFileInfo);
      return null;
    }

    final iconHandle = shFileInfo.ref.hIcon;

    final iconInfo = calloc<ICONINFO>();
    if (GetIconInfo(iconHandle, iconInfo) == 0) {
      DestroyIcon(iconHandle);
      calloc.free(shFileInfo);
      calloc.free(iconInfo);
      return null;
    }

    final hdc = GetDC(0);
    final bitmapInfo = calloc<BITMAPINFO>();
    bitmapInfo.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();

    GetDIBits(
      hdc,
      iconInfo.ref.hbmColor,
      0,
      0,
      nullptr,
      bitmapInfo,
      DIB_RGB_COLORS,
    );

    final width = bitmapInfo.ref.bmiHeader.biWidth;
    final height = bitmapInfo.ref.bmiHeader.biHeight.abs();
    final bitsPerPixel = bitmapInfo.ref.bmiHeader.biBitCount;

    final stride = ((width * bitsPerPixel + 31) ~/ 32) * 4;
    final bufferSize = stride * height;
    final bits = calloc.allocate<Uint8>(bufferSize);

    bitmapInfo.ref.bmiHeader.biHeight = -height;
    GetDIBits(
      hdc,
      iconInfo.ref.hbmColor,
      0,
      height,
      bits.cast(),
      bitmapInfo,
      DIB_RGB_COLORS,
    );

    final pngData = _convertToPng(bits, width, height, bitsPerPixel);

    calloc.free(bits);
    calloc.free(bitmapInfo);
    ReleaseDC(0, hdc);
    DeleteObject(iconInfo.ref.hbmColor);
    DeleteObject(iconInfo.ref.hbmMask);
    DestroyIcon(iconHandle);
    calloc.free(iconInfo);
    calloc.free(shFileInfo);

    return pngData;
  } catch (e) {
    print('提取图标失败: $e');
    return null;
  }
}

Uint8List _convertToPng(Pointer<Uint8> bits, int width, int height, int bitsPerPixel) {
  final bytes = <int>[];

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final offset = y * ((width * bitsPerPixel + 31) ~/ 32) * 4 + x * 4;
      final b = bits[offset];
      final g = bits[offset + 1];
      final r = bits[offset + 2];
      final a = 255;
      bytes.addAll([r, g, b, a]);
    }
  }

  return Uint8List.fromList(bytes);
}

