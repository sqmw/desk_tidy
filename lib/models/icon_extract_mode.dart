enum IconExtractMode {
  system,
  bitmapMask,
}

String iconExtractModeId(IconExtractMode mode) {
  switch (mode) {
    case IconExtractMode.system:
      return 'system';
    case IconExtractMode.bitmapMask:
      return 'bitmapMask';
  }
}
