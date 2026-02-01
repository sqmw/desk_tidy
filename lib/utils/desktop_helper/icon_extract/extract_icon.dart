part of '../../desktop_helper.dart';

Uint8List? extractIcon(String filePath, {int size = 64}) {
  // Try to locate the icon resource via shell, then extract a high-res icon via
  // PrivateExtractIconsW (handles PNG-in-ICO as well). Fallback to SHGetFileInfo
  // HICON if needed.
  final comReady = _ensureComReady();
  try {
    final desiredSize = size.clamp(16, 256);

    final primaryKey = _cacheKeyForFile(filePath, desiredSize);
    final primaryCached = _readIconCache(primaryKey);
    if (primaryCached.found) return primaryCached.value;

    Uint8List? cachedValue;
    _IconLocation? cachedLocation;

    final location = _getIconLocation(filePath);
    if (location != null && location.path.isNotEmpty) {
      final cacheKey = _cacheKeyForLocation(location, desiredSize);
      final existing = _readIconCache(cacheKey);
      if (existing.found) return existing.value;

      final hicon = _extractHiconFromLocation(
        location.path,
        location.index,
        desiredSize,
      );
      if (hicon != 0) {
        final png = _encodeHicon(hicon, size: desiredSize);
        DestroyIcon(hicon);
        if (png != null && png.isNotEmpty) {
          _writeIconCache(cacheKey, png);
          cachedLocation = location;
          cachedValue = png;
        }
      }
    }

    if (cachedValue == null) {
      String? targetPath;
      final ext = path.extension(filePath).toLowerCase();
      const imageExts = {'.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp'};

      if (imageExts.contains(ext)) {
        targetPath = filePath;
      } else if (ext == '.lnk') {
        try {
          final resolved = getShortcutTarget(filePath);
          if (resolved != null &&
              imageExts.contains(path.extension(resolved).toLowerCase())) {
            targetPath = resolved;
          }
        } catch (_) {}
      }

      if (targetPath != null) {
        try {
          final file = File(targetPath);
          if (file.existsSync()) {
            final bytes = file.readAsBytesSync();
            if (bytes.isNotEmpty) {
              final image = img.decodeImage(bytes);
              if (image != null) {
                img.Image resized = image;
                if (image.width > desiredSize || image.height > desiredSize) {
                  if (image.width > image.height) {
                    resized = img.copyResize(image, width: desiredSize);
                  } else {
                    resized = img.copyResize(image, height: desiredSize);
                  }
                }

                final png = Uint8List.fromList(img.encodePng(resized));
                if (png.isNotEmpty) {
                  cachedValue = png;
                  _writeIconCache(primaryKey, png);
                }
              }
            }
          }
        } catch (e) {
          _debugLog('Failed to generate thumbnail for $targetPath: $e');
        }
      }
    }

    if (cachedValue == null) {
      // Check for video files
      final ext = path.extension(filePath).toLowerCase();
      const videoExts = {
        '.mp4',
        '.mkv',
        '.avi',
        '.mov',
        '.wmv',
        '.flv',
        '.webm',
        '.m4v',
        '.mpg',
        '.mpeg',
        '.3gp',
      };

      String? videoPath;
      if (videoExts.contains(ext)) {
        videoPath = filePath;
      } else if (ext == '.lnk') {
        // Check if link points to video
        try {
          final resolved = getShortcutTarget(filePath);
          if (resolved != null &&
              videoExts.contains(path.extension(resolved).toLowerCase())) {
            videoPath = resolved;
          }
        } catch (_) {}
      }

      if (videoPath != null) {
        cachedValue = _extractThumbnailShell(videoPath, desiredSize);
        if (cachedValue != null) {
          _writeIconCache(primaryKey, cachedValue);
        }
      }
    }

    if (cachedValue == null) {
      final jumbo = _extractJumboIconPng(filePath, desiredSize);
      if (jumbo != null && jumbo.isNotEmpty) {
        final idx = _getSystemIconIndex(filePath);
        if (idx >= 0) {
          _writeIconCache(_cacheKeyForSystemIndex(idx, desiredSize), jumbo);
        }
        cachedValue = jumbo;
      }
    }

    // Fallback: obtain HICON from shell, draw it into a 32bpp DIB, then encode.
    if (cachedValue == null) {
      final pathPtr = filePath.toNativeUtf16();
      final shFileInfo = calloc<SHFILEINFO>();
      final isVirtual =
          filePath.startsWith('::') ||
          filePath.startsWith('shell::') ||
          filePath.contains(',');
      final hr = SHGetFileInfo(
        pathPtr.cast(),
        0,
        shFileInfo.cast(),
        sizeOf<SHFILEINFO>(),
        SHGFI_ICON |
            SHGFI_LARGEICON |
            (isVirtual ? 0 : SHGFI_USEFILEATTRIBUTES),
      );
      calloc.free(pathPtr);
      if (hr == 0) {
        calloc.free(shFileInfo);
        return null;
      }

      final iconHandle = shFileInfo.ref.hIcon;
      calloc.free(shFileInfo);
      if (iconHandle == 0) {
        return null;
      }

      cachedValue = _encodeHicon(iconHandle, size: desiredSize);
      DestroyIcon(iconHandle);
    }

    final finalKey = cachedLocation != null
        ? _cacheKeyForLocation(cachedLocation, desiredSize)
        : primaryKey;
    _writeIconCache(finalKey, cachedValue);
    return cachedValue;
  } finally {
    if (comReady) {
      CoUninitialize();
    }
  }
}
