part of '../desktop_helper.dart';

bool copyEntityPathsToClipboard(List<String> paths, {bool cut = false}) {
  if (!Platform.isWindows) return false;
  final filtered = paths.where((p) => p.trim().isNotEmpty).toList();
  if (filtered.isEmpty) return false;

  final normalized = filtered.map(path.normalize).toList();
  final units = <int>[];
  for (final entry in normalized) {
    units.addAll(entry.codeUnits);
    units.add(0);
  }
  units.add(0);

  final bytes = units.length * sizeOf<Uint16>();
  final totalBytes = sizeOf<DROPFILES>() + bytes;
  final hGlobal = GlobalAlloc(GMEM_MOVEABLE, totalBytes);
  if (hGlobal == nullptr) return false;

  final locked = GlobalLock(hGlobal);
  if (locked == nullptr) {
    GlobalFree(hGlobal);
    return false;
  }

  try {
    final dropFiles = locked.cast<DROPFILES>();
    dropFiles.ref
      ..pFiles = sizeOf<DROPFILES>()
      ..fWide = 1
      ..fNC = 0;
    dropFiles.ref.pt
      ..x = 0
      ..y = 0;

    final dataPtr = (locked.cast<Uint8>() + sizeOf<DROPFILES>()).cast<Uint16>();
    dataPtr.asTypedList(units.length).setAll(0, units);
  } finally {
    GlobalUnlock(hGlobal);
  }

  if (OpenClipboard(NULL) == 0) {
    GlobalFree(hGlobal);
    return false;
  }

  var success = false;
  try {
    if (EmptyClipboard() == 0) {
      GlobalFree(hGlobal);
      return false;
    }
    if (SetClipboardData(CF_HDROP, hGlobal.address) == 0) {
      GlobalFree(hGlobal);
      return false;
    }
    _setClipboardDropEffect(cut ? _dropEffectMove : _dropEffectCopy);
    success = true;
  } finally {
    CloseClipboard();
  }

  return success;
}

void _setClipboardDropEffect(int effect) {
  final formatPtr = _clipboardDropEffectFormat.toNativeUtf16();
  try {
    final format = RegisterClipboardFormat(formatPtr);
    if (format == 0) return;
    final hGlobal = GlobalAlloc(GMEM_MOVEABLE, sizeOf<Uint32>());
    if (hGlobal == nullptr) return;
    final locked = GlobalLock(hGlobal);
    if (locked == nullptr) {
      GlobalFree(hGlobal);
      return;
    }
    try {
      locked.cast<Uint32>().value = effect;
    } finally {
      GlobalUnlock(hGlobal);
    }
    if (SetClipboardData(format, hGlobal.address) == 0) {
      GlobalFree(hGlobal);
    }
  } finally {
    calloc.free(formatPtr);
  }
}
