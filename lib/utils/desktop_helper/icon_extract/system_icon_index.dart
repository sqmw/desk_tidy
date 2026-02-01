part of '../../desktop_helper.dart';

int _getSystemIconIndex(String filePath) {
  final attrs = _fileAttributesForSystemIcon(filePath);
  final pathPtr = filePath.toNativeUtf16();
  final shFileInfo = calloc<SHFILEINFO>();
  final isVirtual =
      filePath.startsWith('::') ||
      filePath.startsWith('shell::') ||
      filePath.contains(',');
  final hr = SHGetFileInfo(
    pathPtr.cast(),
    isVirtual ? 0 : attrs,
    shFileInfo.cast(),
    sizeOf<SHFILEINFO>(),
    SHGFI_SYSICONINDEX | (isVirtual ? 0 : SHGFI_USEFILEATTRIBUTES),
  );
  calloc.free(pathPtr);
  if (hr == 0) {
    calloc.free(shFileInfo);
    return -1;
  }
  final index = shFileInfo.ref.iIcon;
  calloc.free(shFileInfo);
  return index;
}

int _fileAttributesForSystemIcon(String filePath) {
  try {
    final type = FileSystemEntity.typeSync(filePath, followLinks: false);
    if (type == FileSystemEntityType.directory) return FILE_ATTRIBUTE_DIRECTORY;
    return FILE_ATTRIBUTE_NORMAL;
  } catch (_) {
    final ext = path.extension(filePath).toLowerCase();
    if (ext.isEmpty) return FILE_ATTRIBUTE_NORMAL;
    return FILE_ATTRIBUTE_NORMAL;
  }
}

_IconLocation? _getIconLocation(String filePath) {
  // Support manual resource path: "path,index"
  if (filePath.contains(',')) {
    final parts = filePath.split(',');
    if (parts.length == 2) {
      final path = parts[0].trim();
      final indexStr = parts[1].trim();
      final index = int.tryParse(indexStr);
      if (index != null) {
        return _IconLocation(path, index);
      }
    }
  }

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
