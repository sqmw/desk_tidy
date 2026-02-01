part of '../desktop_helper.dart';

// SIIGBF flags
const int _siigbfResizeToFit = 0x00;

Uint8List? _extractThumbnailShell(String pathStr, int size) {
  final pathPtr = pathStr.toNativeUtf16();
  final riid = convertToIID(IID_IShellItemImageFactory);
  final ppv = calloc<Pointer>();

  try {
    final hr = SHCreateItemFromParsingName(pathPtr, nullptr, riid, ppv);
    if (FAILED(hr)) return null;

    final factory = IShellItemImageFactory(ppv.cast());
    final phbm = calloc<IntPtr>();

    // Windows expects SIZE struct by value?
    // In win32 package, GetImage definition:
    // int GetImage(SIZE size, int flags, Pointer<IntPtr> phbm)
    final sz = calloc<SIZE>();
    sz.ref.cx = size;
    sz.ref.cy = size;

    try {
      final hr2 = factory.getImage(sz.ref, _siigbfResizeToFit, phbm);
      if (FAILED(hr2) || phbm.value == 0) return null;

      final hbitmap = phbm.value;
      try {
        return _bitmapToPng(hbitmap, size: size);
      } finally {
        DeleteObject(hbitmap);
      }
    } finally {
      calloc.free(sz);
      calloc.free(phbm);
      factory.release();
    }
  } catch (e) {
    debugPrint('Shell thumbnail error: $e');
    return null;
  } finally {
    calloc.free(pathPtr);
    calloc.free(riid);
    calloc.free(ppv);
  }
}

class _MaskBits {
  final Uint8List bytes;
  final int width;
  final int height;
  final int rowBytes;

  const _MaskBits(this.bytes, this.width, this.height, this.rowBytes);
}

_MaskBits? _readMaskBitsFromIcon(int hicon, int maxWidth, int maxHeight) {
  final iconInfo = calloc<ICONINFO>();
  var hbmMask = 0;
  var hbmColor = 0;
  try {
    final ok = GetIconInfo(hicon, iconInfo);
    if (ok == 0) return null;
    hbmMask = iconInfo.ref.hbmMask;
    hbmColor = iconInfo.ref.hbmColor;
    if (hbmMask == 0) return null;
    return _readMaskBits(hbmMask, maxWidth, maxHeight, hasColor: hbmColor != 0);
  } finally {
    if (hbmMask != 0) DeleteObject(hbmMask);
    if (hbmColor != 0) DeleteObject(hbmColor);
    calloc.free(iconInfo);
  }
}

_MaskBits? _readMaskBits(
  int hbmMask,
  int maxWidth,
  int maxHeight, {
  required bool hasColor,
}) {
  final bitmap = calloc<BITMAP>();
  try {
    final res = GetObject(hbmMask, sizeOf<BITMAP>(), bitmap.cast());
    if (res == 0) return null;
    final maskWidth = bitmap.ref.bmWidth;
    var maskHeight = bitmap.ref.bmHeight.abs();
    if (!hasColor && maskHeight >= maxHeight * 2) {
      maskHeight = maskHeight ~/ 2;
    }

    final targetWidth = math.min(maxWidth, maskWidth);
    final targetHeight = math.min(maxHeight, maskHeight);
    if (targetWidth <= 0 || targetHeight <= 0) return null;

    final rowBytes = ((maskWidth + 31) ~/ 32) * 4;
    final totalBytes = rowBytes * maskHeight;
    final buffer = calloc<Uint8>(totalBytes);
    final bmi = calloc<BITMAPINFO>();
    final dc = GetDC(NULL);
    try {
      if (dc == 0) return null;
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = maskWidth;
      bmi.ref.bmiHeader.biHeight = -maskHeight;
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 1;
      bmi.ref.bmiHeader.biCompression = BI_RGB;
      final lines = GetDIBits(
        dc,
        hbmMask,
        0,
        maskHeight,
        buffer.cast(),
        bmi,
        DIB_RGB_COLORS,
      );
      if (lines == 0) return null;

      final bytes = Uint8List.fromList(buffer.asTypedList(totalBytes));
      return _MaskBits(bytes, targetWidth, targetHeight, rowBytes);
    } finally {
      if (dc != 0) ReleaseDC(NULL, dc);
      calloc.free(bmi);
      calloc.free(buffer);
    }
  } finally {
    calloc.free(bitmap);
  }
}

bool _alphaHasMeaning(img.Image image) {
  if (!image.hasAlpha) return false;
  var hasTransparent = false;
  var hasOpaque = false;
  for (final p in image) {
    final a = p.a.toInt();
    if (a == 0) {
      hasTransparent = true;
    } else if (a == 255) {
      hasOpaque = true;
    } else {
      return true;
    }
  }
  return hasTransparent && hasOpaque;
}

void _applyMaskToAlpha(
  img.Image image,
  _MaskBits mask, {
  required bool alphaMeaningful,
}) {
  if (!image.hasAlpha) return;
  final width = math.min(image.width, mask.width);
  final height = math.min(image.height, mask.height);
  final bytes = mask.bytes;
  for (var y = 0; y < height; y++) {
    final rowOffset = y * mask.rowBytes;
    for (var x = 0; x < width; x++) {
      final byteIndex = rowOffset + (x >> 3);
      final bitMask = 0x80 >> (x & 7);
      final transparent = (bytes[byteIndex] & bitMask) != 0;
      final p = image.getPixel(x, y);
      if (transparent) {
        p
          ..r = 0
          ..g = 0
          ..b = 0
          ..a = 0;
      } else if (!alphaMeaningful) {
        p.a = 255;
      }
    }
  }
}

void _forceOpaque(img.Image image) {
  if (!image.hasAlpha) return;
  for (final p in image) {
    p.a = 255;
  }
}

void _unpremultiplyAlphaIfNeeded(img.Image image) {
  if (!image.hasAlpha) return;
  if (!_isLikelyPremultiplied(image)) return;
  _unpremultiplyAlpha(image);
}

bool _isLikelyPremultiplied(img.Image image) {
  if (!image.hasAlpha) return false;
  var samples = 0;
  var premultiplied = 0;
  for (final p in image) {
    final a = p.a.toInt();
    if (a == 0 || a == 255) continue;
    samples++;
    if (p.r <= a && p.g <= a && p.b <= a) {
      premultiplied++;
    }
    if (samples >= 2000) break;
  }
  if (samples == 0) return false;
  return premultiplied / samples >= 0.9;
}

void _unpremultiplyAlpha(img.Image image) {
  for (final p in image) {
    final a = p.a.toInt();
    if (a == 0) {
      p
        ..r = 0
        ..g = 0
        ..b = 0;
      continue;
    }
    if (a >= 255) continue;
    final scale = 255.0 / a;
    p
      ..r = (p.r * scale).round().clamp(0, 255)
      ..g = (p.g * scale).round().clamp(0, 255)
      ..b = (p.b * scale).round().clamp(0, 255);
  }
}
