part of '../all_page.dart';

class _EntitySelectionInfo {
  final String name;
  final String fullPath;
  final String folderPath;
  final FileSystemEntity entity;

  const _EntitySelectionInfo({
    required this.name,
    required this.fullPath,
    required this.folderPath,
    required this.entity,
  });
}
