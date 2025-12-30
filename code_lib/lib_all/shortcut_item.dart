import 'dart:typed_data';

class ShortcutItem {
  final String name;
  final String path;
  final String iconPath;
  final String description;
  final String targetPath;
  final Uint8List? iconData;

  ShortcutItem({
    required this.name,
    required this.path,
    required this.iconPath,
    this.description = '',
    this.targetPath = '',
    this.iconData,
  });
}
