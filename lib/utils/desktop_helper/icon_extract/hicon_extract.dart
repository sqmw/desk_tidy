part of '../../desktop_helper.dart';

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
