import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../utils/desktop_helper.dart';
import 'launch_feedback/taskbar_launch_indicator.dart';
import 'launch_feedback/window_locator.dart';

class LaunchFeedbackSession {
  LaunchFeedbackSession({required this.launched, required this.ready});

  final bool launched;
  final Future<void> ready;
}

class LaunchFeedbackService {
  LaunchFeedbackService._();

  static final LaunchFeedbackService instance = LaunchFeedbackService._();
  final LaunchTargetWindowLocator _windowLocator = LaunchTargetWindowLocator();

  Future<LaunchFeedbackSession> launchWithPerceptibleFeedback({
    required String launchPath,
    required String targetPath,
    bool showTaskbarIndicator = false,
  }) async {
    final indicator = showTaskbarIndicator
        ? TaskbarLaunchIndicator.show(
            iconSourcePath: _resolveIndicatorIconPath(
              launchPath: launchPath,
              targetPath: targetPath,
            ),
          )
        : null;
    indicator?.startAttentionPulse();

    final launched = await openWithDefault(launchPath);
    if (!launched) {
      indicator?.close();
      return LaunchFeedbackSession(
        launched: false,
        ready: Future<void>.value(),
      );
    }

    final executablePath = _resolveExecutablePath(
      launchPath: launchPath,
      targetPath: targetPath,
    );
    if (executablePath == null) {
      return LaunchFeedbackSession(
        launched: true,
        ready: Future<void>.delayed(const Duration(milliseconds: 450))
            .whenComplete(() {
              indicator?.close();
            }),
      );
    }

    return LaunchFeedbackSession(
      launched: true,
      ready: _waitUntilTargetWindowReady(executablePath).whenComplete(() {
        indicator?.close();
      }),
    );
  }

  String? _resolveExecutablePath({
    required String launchPath,
    required String targetPath,
  }) {
    final shortcutTarget = _resolveShortcutTargetPath(launchPath);
    final candidates = <String>[targetPath, shortcutTarget ?? '', launchPath];
    for (final candidate in candidates) {
      final normalized = _normalizeExistingFilePath(candidate);
      if (normalized == null) continue;

      final ext = path.extension(normalized).toLowerCase();
      if (ext != '.exe') continue;
      return normalized;
    }
    return null;
  }

  String _resolveIndicatorIconPath({
    required String launchPath,
    required String targetPath,
  }) {
    final executablePath = _resolveExecutablePath(
      launchPath: launchPath,
      targetPath: targetPath,
    );
    if (executablePath != null) {
      return executablePath;
    }

    final shortcutTarget = _resolveShortcutTargetPath(launchPath);
    final candidates = <String>[targetPath, shortcutTarget ?? '', launchPath];
    for (final candidate in candidates) {
      final normalized = _normalizeExistingFilePath(candidate);
      if (normalized == null) continue;
      if (_isShortcutContainerPath(normalized)) continue;
      return normalized;
    }
    return launchPath;
  }

  String? _resolveShortcutTargetPath(String launchPath) {
    final launchExt = path.extension(launchPath.trim()).toLowerCase();
    if (launchExt != '.lnk') return null;

    final resolved = getShortcutTarget(launchPath);
    if (resolved == null) return null;
    return _normalizeExistingFilePath(resolved);
  }

  String? _normalizeExistingFilePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return null;

    final file = File(trimmed);
    if (!file.existsSync()) return null;
    return file.absolute.path;
  }

  bool _isShortcutContainerPath(String filePath) {
    const shortcutExts = {'.lnk', '.url', '.appref-ms'};
    return shortcutExts.contains(path.extension(filePath).toLowerCase());
  }

  Future<void> _waitUntilTargetWindowReady(String executablePath) async {
    final minIndicatorTime = Future<void>.delayed(
      const Duration(milliseconds: 450),
    );

    final detectWindow = () async {
      if (!Platform.isWindows) return;
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(deadline)) {
        final hwnd = _windowLocator.findTopLevelWindowByExecutable(
          executablePath,
        );
        if (hwnd != 0) return;
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }();

    await Future.wait<void>([minIndicatorTime, detectWindow]);
  }
}
