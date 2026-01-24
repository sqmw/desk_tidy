import 'dart:typed_data';

import 'system_items.dart';

class ShortcutItem {
  final String name;
  final String path;
  final String iconPath;
  final String description;
  final String targetPath;
  final Uint8List? iconData;
  final bool isSystemItem;
  final SystemItemType? systemItemType;

  ShortcutItem({
    required this.name,
    required this.path,
    required this.iconPath,
    this.description = '',
    this.targetPath = '',
    this.iconData,
    this.isSystemItem = false,
    this.systemItemType,
  });

  /// 创建系统项目快捷方式
  factory ShortcutItem.system(SystemItemType type, {Uint8List? iconData}) {
    final info = SystemItemInfo.all[type]!;
    return ShortcutItem(
      name: info.name,
      path: SystemItemInfo.virtualPath(type),
      iconPath: '',
      isSystemItem: true,
      systemItemType: type,
      iconData: iconData,
    );
  }
}
