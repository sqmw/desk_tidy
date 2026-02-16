import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';

import '../../utils/desktop_helper.dart';

class TaskbarWindowIconAnimationFactory {
  TaskbarWindowIconAnimationFactory._();

  static List<int> createIconHandles({required String iconSourcePath}) {
    final iconBytes = extractIcon(iconSourcePath, size: 256);
    if (iconBytes == null || iconBytes.isEmpty) {
      return const [];
    }

    final appIcon = img.decodeImage(iconBytes);
    if (appIcon == null) {
      return const [];
    }

    final handles = <int>[];
    final tempDir = Directory(
      '${Directory.systemTemp.path}\\desk_tidy_taskbar_icon_spin',
    );
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }

    const frameCount = 10;
    for (var frame = 0; frame < frameCount; frame++) {
      final image = _composeFrame(appIcon, frame, frameCount);
      final bytes = img.encodeIco(image, singleFrame: true);
      final file = File('${tempDir.path}\\taskbar_icon_frame_$frame.ico');
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

  static img.Image _composeFrame(img.Image appIcon, int frame, int frameCount) {
    const canvasSize = 32;
    const appIconSize = 32;
    const spinnerCenter = 24;
    const spinnerDotCount = 10;
    const baseOrbit = 5.3;

    final canvas = img.Image(
      width: canvasSize,
      height: canvasSize,
      numChannels: 4,
    );
    final baseIcon = img.copyResize(
      appIcon,
      width: appIconSize,
      height: appIconSize,
      interpolation: img.Interpolation.linear,
    );

    img.compositeImage(canvas, baseIcon, dstX: 0, dstY: 0);

    final phase = frame * 2 * math.pi / frameCount;
    final pulse = (math.sin(phase) + 1) / 2;
    final badgeRadius = (7 + pulse * 1.4).round();
    final spinnerOrbit = baseOrbit + pulse * 0.9;
    final badgeAlpha = (190 + pulse * 44).round().clamp(190, 234);

    img.fillCircle(
      canvas,
      x: spinnerCenter,
      y: spinnerCenter,
      radius: badgeRadius,
      color: img.ColorRgba8(11, 14, 20, badgeAlpha),
    );
    img.drawCircle(
      canvas,
      x: spinnerCenter,
      y: spinnerCenter,
      radius: badgeRadius,
      color: img.ColorRgba8(255, 255, 255, 135),
    );

    for (var order = 0; order < spinnerDotCount; order++) {
      final index = (frame - order + spinnerDotCount) % spinnerDotCount;
      final angle = (index * 2 * math.pi / spinnerDotCount) - math.pi / 2;
      final x = (spinnerCenter + math.cos(angle) * spinnerOrbit).round();
      final y = (spinnerCenter + math.sin(angle) * spinnerOrbit).round();
      final alpha = ((spinnerDotCount - order) / spinnerDotCount * 255)
          .round()
          .clamp(56, 255);
      final radius = order <= 2 ? 2 : 1;

      img.fillCircle(
        canvas,
        x: x,
        y: y,
        radius: radius,
        color: img.ColorRgba8(255, 255, 255, alpha),
      );
      if (order == 0) {
        img.fillCircle(
          canvas,
          x: x,
          y: y,
          radius: 1,
          color: img.ColorRgba8(58, 168, 255, 255),
        );
      }
    }

    return canvas;
  }
}
