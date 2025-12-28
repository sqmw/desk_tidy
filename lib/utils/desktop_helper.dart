import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

const int INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF;

class _IconLocation {
  final String path;
  final int index;

  const _IconLocation(this.path, this.index);
}

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

List<String> _desktopLocations(String primaryPath, {bool includePublic = true}) {
  final destinations = <String>{primaryPath};
  if (includePublic) {
    final publicDesktop = _getKnownFolderPath(FOLDERID_PublicDesktop);
    if (publicDesktop != null && publicDesktop.isNotEmpty) {
      destinations.add(publicDesktop);
    }
  }
  return destinations.toList();
}

List<String> desktopLocations(String primaryPath, {bool includePublic = true}) =>
    _desktopLocations(primaryPath, includePublic: includePublic);

bool isHiddenOrSystem(String fullPath) {
  try {
    final ptr = fullPath.toNativeUtf16();
    final attrs = GetFileAttributes(ptr.cast());
    calloc.free(ptr);

    if (attrs == INVALID_FILE_ATTRIBUTES) return false;
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
    final from = ('${fullPath}\u0000\u0000').toNativeUtf16();

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

const int SLR_NO_UI = 0x0001;
const int SLGP_SHORTPATH = 0x0001;
const int SLGP_UNCPRIORITY = 0x0002;
const int SLGP_RAWPATH = 0x0004;

String? getShortcutTarget(String lnkPath) {
  try {
    final shellLink = ShellLink.createInstance();
    final persistFile = IPersistFile.from(shellLink);

    final lnkPtr = lnkPath.toNativeUtf16();
    final loadHr = persistFile.load(lnkPtr.cast(), STGM_READ);
    calloc.free(lnkPtr);

    if (loadHr != S_OK) {
      shellLink.release();
      return null;
    }

    shellLink.resolve(0, SLR_NO_UI);

    final pathBuffer = calloc.allocate<Utf16>(MAX_PATH);
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

Future<List<String>> scanDesktopShortcuts(
  String desktopPath, {
  bool showHidden = false,
}) async {
  final directories = _desktopLocations(desktopPath);
  final shortcuts = <String>{};
  const allowedExtensions = {
    '.exe',
    '.lnk',
    '.url',
    '.appref-ms',
  };

  for (final dirPath in directories) {
    try {
      final desktopDir = Directory(dirPath);
      if (!desktopDir.existsSync()) continue;

      await for (final entity in desktopDir.list()) {
        final name = path.basename(entity.path);
        final lowerName = name.toLowerCase();

        if (!showHidden &&
            (name.startsWith('.') || isHiddenOrSystem(entity.path))) {
          continue;
        }

        if (lowerName == 'desktop.ini' || lowerName == 'thumbs.db') {
          continue;
        }

        if (entity is File) {
          final ext = path.extension(lowerName);
          if (!allowedExtensions.contains(ext)) continue;
          shortcuts.add(entity.path);
        }
      }
    } catch (e) {
      print('扫描桌面失败 ($dirPath): $e');
    }
  }

  return shortcuts.toList();
}

Uint8List? extractIcon(String filePath, {int size = 64}) {
  // Try to locate the icon resource via shell, then extract a high-res icon via
  // PrivateExtractIconsW (handles PNG-in-ICO as well). Fallback to SHGetFileInfo
  // HICON if needed.
  final desiredSize = size.clamp(16, 256);

  final location = _getIconLocation(filePath);
  if (location != null && location.path.isNotEmpty) {
    final hicon =
        _extractHiconFromLocation(location.path, location.index, desiredSize);
    if (hicon != 0) {
      final png = _hiconToPng(hicon, size: desiredSize);
      DestroyIcon(hicon);
      if (png != null && png.isNotEmpty) return png;
    }
  }

  // Fallback: obtain HICON from shell, draw it into a 32bpp DIB, then encode.
  final pathPtr = filePath.toNativeUtf16();
  final shFileInfo = calloc<SHFILEINFO>();
  final hr = SHGetFileInfo(
    pathPtr.cast(),
    0,
    shFileInfo.cast(),
    sizeOf<SHFILEINFO>(),
    SHGFI_ICON | SHGFI_LARGEICON,
  );
  calloc.free(pathPtr);
  if (hr == 0) {
    calloc.free(shFileInfo);
    return null;
  }

  final iconHandle = shFileInfo.ref.hIcon;
  calloc.free(shFileInfo);
  if (iconHandle == 0) return null;

  final png = _hiconToPng(iconHandle, size: desiredSize);
  DestroyIcon(iconHandle);
  return png;
}

_IconLocation? _getIconLocation(String filePath) {
  final pathPtr = filePath.toNativeUtf16();
  final shFileInfo = calloc<SHFILEINFO>();
  final result = SHGetFileInfo(
    pathPtr.cast(),
    0,
    shFileInfo.cast(),
    sizeOf<SHFILEINFO>(),
    SHGFI_ICONLOCATION,
  );
  calloc.free(pathPtr);
  if (result == 0) {
    calloc.free(shFileInfo);
    return null;
  }

  final iconPath = shFileInfo.ref.szDisplayName;
  final iconIndex = shFileInfo.ref.iIcon;
  calloc.free(shFileInfo);

  if (iconPath.isEmpty) return null;
  return _IconLocation(iconPath, iconIndex);
}

int _extractHiconFromLocation(String iconPath, int iconIndex, int size) {
  final iconPathPtr = iconPath.toNativeUtf16();
  final hiconPtr = calloc<IntPtr>();
  final iconIdPtr = calloc<Uint32>();

  final extracted = PrivateExtractIcons(
    iconPathPtr.cast(),
    iconIndex,
    size,
    size,
    hiconPtr,
    iconIdPtr,
    1,
    0,
  );

  calloc.free(iconPathPtr);
  calloc.free(iconIdPtr);

  final hicon = hiconPtr.value;
  calloc.free(hiconPtr);

  if (extracted <= 0 || hicon == 0) return 0;
  return hicon;
}

Uint8List? _hiconToPng(int icon, {required int size}) {
  final screenDC = GetDC(NULL);
  if (screenDC == 0) return null;
  final memDC = CreateCompatibleDC(screenDC);

  final bmi = calloc<BITMAPINFO>();
  bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
  bmi.ref.bmiHeader.biWidth = size;
  bmi.ref.bmiHeader.biHeight = -size; // top-down DIB
  bmi.ref.bmiHeader.biPlanes = 1;
  bmi.ref.bmiHeader.biBitCount = 32;
  bmi.ref.bmiHeader.biCompression = BI_RGB;

  final ppBits = calloc<Pointer<Void>>();
  final dib = CreateDIBSection(screenDC, bmi, DIB_RGB_COLORS, ppBits, NULL, 0);
  if (dib == 0) {
    calloc.free(ppBits);
    calloc.free(bmi);
    DeleteDC(memDC);
    ReleaseDC(NULL, screenDC);
    return null;
  }

  final oldBmp = SelectObject(memDC, dib);
  final pixelCount = size * size * 4;
  final pixels = ppBits.value.cast<Uint8>().asTypedList(pixelCount);
  pixels.fillRange(0, pixels.length, 0);

  final scaled = CopyImage(icon, IMAGE_ICON, size, size, 0);
  final iconToDraw = scaled != 0 ? scaled : icon;
  DrawIcon(memDC, 0, 0, iconToDraw);
  if (scaled != 0) {
    DestroyIcon(scaled);
  }

  final image = img.Image.fromBytes(
    width: size,
    height: size,
    bytes: pixels.buffer,
    numChannels: 4,
    order: img.ChannelOrder.bgra,
    rowStride: size * 4,
  );

  final normalized = _normalizeIcon(image, fill: 0.92);

  final png = Uint8List.fromList(
    img.encodePng(
      normalized,
    ),
  );

  SelectObject(memDC, oldBmp);
  DeleteObject(dib);
  DeleteDC(memDC);
  ReleaseDC(NULL, screenDC);
  calloc.free(ppBits);
  calloc.free(bmi);
  return png;
}

img.Image _normalizeIcon(img.Image source, {double fill = 0.92}) {
  final width = source.width;
  final height = source.height;
  if (width == 0 || height == 0) return source;

  const alphaThreshold = 4;
  var minX = width;
  var minY = height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = source.getPixel(x, y);
      if (p.a > alphaThreshold) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX < 0 || maxY < 0) return source;

  minX = math.max(0, minX - 1);
  minY = math.max(0, minY - 1);
  maxX = math.min(width - 1, maxX + 1);
  maxY = math.min(height - 1, maxY + 1);

  final cropWidth = maxX - minX + 1;
  final cropHeight = maxY - minY + 1;
  if (cropWidth <= 0 || cropHeight <= 0) return source;

  final cropped = img.copyCrop(
    source,
    x: minX,
    y: minY,
    width: cropWidth,
    height: cropHeight,
  );

  final targetEdge = (width * fill).round().clamp(1, width);
  final scale =
      math.min(targetEdge / cropped.width, targetEdge / cropped.height);
  final scaledWidth = math.max(1, (cropped.width * scale).round());
  final scaledHeight = math.max(1, (cropped.height * scale).round());

  final resized = img.copyResize(
    cropped,
    width: scaledWidth,
    height: scaledHeight,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(width: width, height: height);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  img.compositeImage(
    canvas,
    resized,
    dstX: ((width - scaledWidth) / 2).round(),
    dstY: ((height - scaledHeight) / 2).round(),
  );

  return canvas;
}
