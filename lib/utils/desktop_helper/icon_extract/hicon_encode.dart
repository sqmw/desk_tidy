part of '../../desktop_helper.dart';

Uint8List? _encodeHicon(int icon, {required int size}) {
  return _hiconToPngBitmap(icon, size: size) ?? _hiconToPng(icon, size: size);
}

Uint8List? _hiconToPng(int icon, {required int size}) {
  final screenDC = GetDC(NULL);
  if (screenDC == 0) return null;
  final memDC = CreateCompatibleDC(screenDC);
  if (memDC == 0) {
    ReleaseDC(NULL, screenDC);
    return null;
  }

  final bmi = calloc<BITMAPINFO>();
  final ppBits = calloc<Pointer<Void>>();
  var dib = 0;
  var oldBmp = 0;
  try {
    bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
    bmi.ref.bmiHeader.biWidth = size;
    bmi.ref.bmiHeader.biHeight = -size; // top-down DIB
    bmi.ref.bmiHeader.biPlanes = 1;
    bmi.ref.bmiHeader.biBitCount = 32;
    bmi.ref.bmiHeader.biCompression = BI_RGB;

    dib = CreateDIBSection(screenDC, bmi, DIB_RGB_COLORS, ppBits, NULL, 0);
    if (dib == 0) return null;

    oldBmp = SelectObject(memDC, dib);
    final pixelCount = size * size * 4;
    final pixelsView = ppBits.value.cast<Uint8>().asTypedList(pixelCount);
    pixelsView.fillRange(0, pixelsView.length, 0);

    _drawIconEx(memDC, 0, 0, icon, size, size, 0, NULL, _diNormal);

    final pixels = Uint8List.fromList(pixelsView);
    final image = img.Image.fromBytes(
      width: size,
      height: size,
      bytes: pixels.buffer,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
      rowStride: size * 4,
    );

    final mask = _readMaskBitsFromIcon(icon, image.width, image.height);
    final alphaMeaningful = _alphaHasMeaning(image);
    if (mask != null) {
      _applyMaskToAlpha(image, mask, alphaMeaningful: alphaMeaningful);
    } else if (!alphaMeaningful) {
      _forceOpaque(image);
    }
    _unpremultiplyAlphaIfNeeded(image);

    final output = (image.width == size && image.height == size)
        ? image
        : img.copyResize(
            image,
            width: size,
            height: size,
            interpolation: img.Interpolation.cubic,
          );

    return Uint8List.fromList(img.encodePng(output));
  } finally {
    if (oldBmp != 0) {
      SelectObject(memDC, oldBmp);
    }
    if (dib != 0) {
      DeleteObject(dib);
    }
    DeleteDC(memDC);
    ReleaseDC(NULL, screenDC);
    calloc.free(ppBits);
    calloc.free(bmi);
  }
}
