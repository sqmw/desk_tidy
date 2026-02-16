import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';

import '../../utils/desktop_helper.dart';

class TaskbarWindowIconAnimationFactory {
  TaskbarWindowIconAnimationFactory._();

  static List<int> createAnimatedWindowIconHandles({
    required String iconSourcePath,
  }) {
    final iconBytes = extractIcon(iconSourcePath, size: 96);
    if (iconBytes == null || iconBytes.isEmpty) {
      return const [];
    }

    final sourceImage = img.decodeImage(iconBytes);
    if (sourceImage == null) {
      return const [];
    }

    final handles = <int>[];
    final tempDir = Directory(
      '${Directory.systemTemp.path}\\desk_tidy_window_icon_frames',
    );
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }

    const frameCount = 12;
    for (var frame = 0; frame < frameCount; frame++) {
      final frameImage = _composeFrame(sourceImage, frame, frameCount);
      final bytes = img.encodeIco(frameImage, singleFrame: true);
      final file = File('${tempDir.path}\\window_icon_frame_$frame.ico');
      file.writeAsBytesSync(bytes, flush: true);

      final pathPtr = file.path.toNativeUtf16();
      try {
        final hIcon = LoadImage(
          0,
          pathPtr,
          IMAGE_ICON,
          32,
          32,
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

  static img.Image _composeFrame(img.Image source, int frame, int frameCount) {
    const canvasSize = 64;
    final canvas = img.Image(
      width: canvasSize,
      height: canvasSize,
      numChannels: 4,
    );

    final phase = frame * 2 * math.pi / frameCount;
    final bounce = math.max(0.0, math.sin(phase));
    final lift = (bounce * 7).round();
    final scale = 0.84 + (bounce * 0.11);

    final maxIconSize = (canvasSize * scale).round();
    final sourceRatio = source.width / source.height;
    final targetWidth = sourceRatio >= 1
        ? maxIconSize
        : (maxIconSize * sourceRatio).round();
    final targetHeight = sourceRatio >= 1
        ? (maxIconSize / sourceRatio).round()
        : maxIconSize;

    final resized = img.copyResize(
      source,
      width: targetWidth.clamp(1, canvasSize),
      height: targetHeight.clamp(1, canvasSize),
      interpolation: img.Interpolation.cubic,
    );

    final shadowRadius = (11 - bounce * 2).round().clamp(8, 11);
    final shadowAlpha = (70 - bounce * 36).round().clamp(20, 70);
    img.fillCircle(
      canvas,
      x: canvasSize ~/ 2,
      y: canvasSize - 10,
      radius: shadowRadius,
      color: img.ColorRgba8(0, 0, 0, shadowAlpha),
    );

    final dstX = (canvasSize - resized.width) ~/ 2;
    final dstY = ((canvasSize - resized.height) ~/ 2) - lift;
    img.compositeImage(
      canvas,
      resized,
      dstX: dstX,
      dstY: dstY.clamp(0, canvasSize - resized.height),
    );

    return canvas;
  }
}
