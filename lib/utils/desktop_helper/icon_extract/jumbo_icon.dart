part of '../../desktop_helper.dart';

Uint8List? _extractJumboIconPng(String filePath, int desiredSize) {
  final iconIndex = _getSystemIconIndex(filePath);
  if (iconIndex < 0) return null;

  final cacheKey = _cacheKeyForSystemIndex(iconIndex, desiredSize);
  final cached = _readIconCache(cacheKey);
  if (cached.found) return cached.value;

  final iid = convertToIID(_iidIImageList);
  final imageListPtr = calloc<COMObject>();
  try {
    final hr = _shGetImageList(_shilJumbo, iid, imageListPtr.cast());
    if (FAILED(hr) || imageListPtr.ref.isNull) return null;

    final imageList = IImageList(imageListPtr);
    final hiconPtr = calloc<IntPtr>();
    try {
      final hr2 = imageList.getIcon(
        iconIndex,
        _ildTransparent | _ildImage,
        hiconPtr,
      );
      if (FAILED(hr2) || hiconPtr.value == 0) return null;
      final png = _encodeHicon(hiconPtr.value, size: desiredSize);
      DestroyIcon(hiconPtr.value);
      if (png != null && png.isNotEmpty) {
        _writeIconCache(cacheKey, png);
      }
      return png;
    } finally {
      calloc.free(hiconPtr);
      imageList.detach();
      imageList.release();
    }
  } catch (_) {
    return null;
  } finally {
    calloc.free(iid);
    calloc.free(imageListPtr);
  }
}
