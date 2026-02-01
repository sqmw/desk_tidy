part of '../../desktop_helper.dart';

Uint8List? _hiconToPngBitmap(int icon, {required int size}) {
  final iconInfo = calloc<ICONINFO>();
  var hbmMask = 0;
  var hbmColor = 0;
  try {
    final ok = GetIconInfo(icon, iconInfo);
    if (ok == 0) return null;
    hbmMask = iconInfo.ref.hbmMask;
    hbmColor = iconInfo.ref.hbmColor;
    if (hbmColor == 0) return _hiconToPng(icon, size: size);

    return _bitmapToPng(hbmColor, size: size, hbmMask: hbmMask);
  } finally {
    if (hbmMask != 0) DeleteObject(hbmMask);
    if (hbmColor != 0) DeleteObject(hbmColor);
    calloc.free(iconInfo);
  }
}

Uint8List? _bitmapToPng(int hbitmap, {required int size, int hbmMask = 0}) {
  final bitmap = calloc<BITMAP>();
  try {
    final res = GetObject(hbitmap, sizeOf<BITMAP>(), bitmap.cast());
    if (res == 0) return null;
    final width = bitmap.ref.bmWidth;
    final height = bitmap.ref.bmHeight.abs();
    if (width <= 0 || height <= 0) return null;

    final stride = width * 4;
    final buffer = calloc<Uint8>(stride * height);
    final bmi = calloc<BITMAPINFO>();
    final dc = GetDC(NULL);
    try {
      if (dc == 0) return null;
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = width;
      bmi.ref.bmiHeader.biHeight = -height;
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 32;
      bmi.ref.bmiHeader.biCompression = BI_RGB;
      final lines = GetDIBits(
        dc,
        hbitmap,
        0,
        height,
        buffer.cast(),
        bmi,
        DIB_RGB_COLORS,
      );
      if (lines == 0) return null;

      final pixels = Uint8List.fromList(buffer.asTypedList(stride * height));
      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: pixels.buffer,
        numChannels: 4,
        order: img.ChannelOrder.bgra,
        rowStride: stride,
      );

      final mask = hbmMask != 0
          ? _readMaskBits(hbmMask, width, height, hasColor: true)
          : null;
      final alphaMeaningful = _alphaHasMeaning(image);
      if (mask != null) {
        _applyMaskToAlpha(image, mask, alphaMeaningful: alphaMeaningful);
      } else if (!alphaMeaningful) {
        _forceOpaque(image);
      }
      _unpremultiplyAlphaIfNeeded(image);

      img.Image output = image;
      if (image.width > size || image.height > size) {
        if (image.width >= image.height) {
          output = img.copyResize(
            image,
            width: size,
            interpolation: img.Interpolation.cubic,
          );
        } else {
          output = img.copyResize(
            image,
            height: size,
            interpolation: img.Interpolation.cubic,
          );
        }
      }

      return Uint8List.fromList(img.encodePng(output));
    } finally {
      if (dc != 0) ReleaseDC(NULL, dc);
      calloc.free(bmi);
      calloc.free(buffer);
    }
  } finally {
    calloc.free(bitmap);
  }
}
