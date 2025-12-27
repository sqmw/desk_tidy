class ShortcutItem {
  final String name;
  final String path;
  final String iconPath;
  final String description;
  final String targetPath;

  ShortcutItem({
    required this.name,
    required this.path,
    required this.iconPath,
    this.description = '',
    this.targetPath = '',
  });
}
