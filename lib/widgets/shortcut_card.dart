import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
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
              _buildIcon(),
              const SizedBox(height: 8),
              Text(
                shortcut.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 10,
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

  Widget _buildIcon() {
    if (shortcut.iconData != null && shortcut.iconData!.isNotEmpty) {
      return FutureBuilder<ui.Image>(
        future: _loadImage(shortcut.iconData!),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return RawImage(
              image: snapshot.data,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            );
          }
          return Icon(
            Icons.apps,
            size: 32,
            color: Theme.of(context).primaryColor,
          );
        },
      );
    }
    return Icon(
      Icons.apps,
      size: 32,
      color: Colors.grey,
    );
  }

  Future<ui.Image> _loadImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
