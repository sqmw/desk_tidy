import 'package:flutter/material.dart';
import '../models/shortcut_item.dart';

class ShortcutCard extends StatelessWidget {
  final ShortcutItem shortcut;

  const ShortcutCard({
    Key? key,
    required this.shortcut,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          // TODO: 实现点击启动应用
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.apps,
                size: 32,  // 固定图标大小
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                shortcut.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 10,  // 减小文本大小
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
