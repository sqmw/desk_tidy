import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';

class TaskbarOverlaySpinnerIconFactory {
  TaskbarOverlaySpinnerIconFactory._();

  static List<int> createIconHandles() {
    final handles = <int>[];
    final tempDir = Directory(
      '${Directory.systemTemp.path}\\desk_tidy_spinner_icons',
    );
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }

    const frameCount = 10;
    for (var frame = 0; frame < frameCount; frame++) {
      final bytes = _buildSpinnerFrame(frame, frameCount);
      final file = File('${tempDir.path}\\spinner_frame_$frame.ico');
      file.writeAsBytesSync(bytes, flush: true);

      final pathPtr = file.path.toNativeUtf16();
      try {
        final hIcon = LoadImage(
          0,
          pathPtr,
          IMAGE_ICON,
          16,
          16,
          LR_LOADFROMFILE,
        );
        if (hIcon != 0) {
          handles.add(hIcon);
        }
      } finally {
        free(pathPtr);
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
    }

    return handles;
  }

  static List<int> _buildSpinnerFrame(int frame, int frameCount) {
    const size = 32;
    const center = 16;
    const backgroundRadius = 13;
    const tailLength = 7;
    const orbitRadius = 8.6;

    final image = img.Image(width: size, height: size, numChannels: 4);

    img.fillCircle(
      image,
      x: center,
      y: center,
      radius: backgroundRadius,
      color: img.ColorRgba8(18, 22, 31, 178),
    );
    img.drawCircle(
      image,
      x: center,
      y: center,
      radius: backgroundRadius,
      color: img.ColorRgba8(255, 255, 255, 76),
    );

    for (var tail = 0; tail < tailLength; tail++) {
      final index = (frame - tail + frameCount) % frameCount;
      final angle = (index * 2 * math.pi / frameCount) - math.pi / 2;
      final x = (center + math.cos(angle) * orbitRadius).round();
      final y = (center + math.sin(angle) * orbitRadius).round();

      final alpha = ((tailLength - tail) / tailLength * 255).round().clamp(
        52,
        255,
      );
      final radius = tail == 0 ? 3 : 2;
      final blue = tail == 0 ? 255 : 222;
      final green = tail == 0 ? 245 : 203;
      final red = tail == 0 ? 255 : 149;

      img.fillCircle(
        image,
        x: x,
        y: y,
        radius: radius,
        color: img.ColorRgba8(red, green, blue, alpha),
      );
    }

    return img.encodeIco(image, singleFrame: true);
  }
}
