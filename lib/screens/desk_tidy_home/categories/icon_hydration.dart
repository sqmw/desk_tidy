part of '../../desk_tidy_home_page.dart';

extension _DeskTidyHomeIconHydration on _DeskTidyHomePageState {
  Future<void> _hydrateShortcutIcons(
    List<ShortcutItem> baseItems,
    int loadToken,
    int requestIconSize,
    bool forceReloadIcons,
  ) async {
    final updatedIcons = <String, Uint8List?>{};
    final tasks = <Future<void>>[];

    for (final item in baseItems) {
      if (!forceReloadIcons && item.iconData != null) {
        continue;
      }
      tasks.add(() async {
        try {
          Uint8List? icon;
          if (item.isSystemItem && item.systemItemType != null) {
            final info = SystemItemInfo.all[item.systemItemType]!;
            icon = await extractIconAsync(
              info.iconResource,
              size: requestIconSize,
            );
          } else {
            final primary = await extractIconAsync(
              item.path,
              size: requestIconSize,
            );
            final targetPath = item.targetPath.isNotEmpty
                ? item.targetPath
                : item.path;
            icon =
                primary ??
                await extractIconAsync(targetPath, size: requestIconSize);
          }

          if (icon != null && icon.isNotEmpty) {
            updatedIcons[item.path] = icon;
          }
        } catch (_) {
          // Ignore icon failures to keep UI responsive.
        }
      }());
    }

    if (tasks.isEmpty) return;
    await Future.wait(tasks);

    if (!mounted || loadToken != _shortcutLoadToken) return;
    if (updatedIcons.isEmpty) return;

    final updated = baseItems.map((item) {
      final icon = updatedIcons[item.path];
      if (icon == null) return item;
      return ShortcutItem(
        name: item.name,
        path: item.path,
        iconPath: item.iconPath,
        description: item.description,
        targetPath: item.targetPath,
        iconData: icon,
        isSystemItem: item.isSystemItem,
        systemItemType: item.systemItemType,
      );
    }).toList();

    _setState(() {
      _shortcuts = updated;
    });
  }
}
