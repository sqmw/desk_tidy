import 'package:flutter/material.dart';

import 'glass.dart';

class EntityDetailBar extends StatelessWidget {
  final String name;
  final String path;
  final String folderPath;
  final VoidCallback? onCopyName;
  final VoidCallback? onCopyPath;
  final VoidCallback? onCopyFolder;

  const EntityDetailBar({
    super.key,
    required this.name,
    required this.path,
    required this.folderPath,
    this.onCopyName,
    this.onCopyPath,
    this.onCopyFolder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium;
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      opacity: 0.14,
      blurSigma: 10,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Details', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                SelectableText(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Path', style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                SelectableText(path, style: textStyle),
                const SizedBox(height: 6),
                SelectableText(folderPath, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Copy name',
                icon: const Icon(Icons.copy),
                onPressed: onCopyName,
              ),
              IconButton(
                tooltip: 'Copy path',
                icon: const Icon(Icons.link),
                onPressed: onCopyPath,
              ),
              IconButton(
                tooltip: 'Copy folder',
                icon: const Icon(Icons.folder),
                onPressed: onCopyFolder,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

