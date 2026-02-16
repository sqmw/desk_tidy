import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
    Uint8List? preferredIconBytes,
    bool showTaskbarIndicator = false,
  }) async {
    final executablePath = _resolveExecutablePath(
      launchPath: launchPath,
      targetPath: targetPath,
    );
    final indicatorIconPath = _resolveIndicatorIconPath(
      launchPath: launchPath,
      targetPath: targetPath,
      executablePath: executablePath,
    );
    final preLaunchWindowCount = executablePath == null
        ? 0
        : _windowLocator.countTopLevelWindowsByExecutable(executablePath);

    final indicator = showTaskbarIndicator
        ? TaskbarLaunchIndicator.show(
            iconSourcePath: indicatorIconPath,
            appDisplayName: _resolveIndicatorDisplayName(
              launchPath: launchPath,
              targetPath: targetPath,
              executablePath: executablePath,
            ),
            preferredIconBytes: _resolvePreferredIndicatorIconBytes(
              launchPath: launchPath,
              targetPath: targetPath,
              executablePath: executablePath,
              indicatorIconPath: indicatorIconPath,
              fallbackPreferredIconBytes: preferredIconBytes,
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
      ready:
          _waitUntilTargetWindowReady(
            executablePath,
            preLaunchWindowCount: preLaunchWindowCount,
          ).whenComplete(() {
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
    String? executablePath,
  }) {
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

  String _resolveIndicatorDisplayName({
    required String launchPath,
    required String targetPath,
    String? executablePath,
  }) {
    final exePath =
        executablePath ??
        _resolveExecutablePath(launchPath: launchPath, targetPath: targetPath);
    if (exePath != null) {
      return _normalizeDisplayName(path.basenameWithoutExtension(exePath));
    }

    final shortcutTarget = _resolveShortcutTargetPath(launchPath);
    final candidates = <String>[targetPath, shortcutTarget ?? '', launchPath];
    for (final candidate in candidates) {
      final normalized = _normalizeExistingFilePath(candidate);
      if (normalized == null) continue;
      final name = path.basenameWithoutExtension(normalized);
      if (name.trim().isNotEmpty) {
        return _normalizeDisplayName(name);
      }
    }
    return '应用';
  }

  Uint8List? _resolvePreferredIndicatorIconBytes({
    required String launchPath,
    required String targetPath,
    required String indicatorIconPath,
    required Uint8List? fallbackPreferredIconBytes,
    String? executablePath,
  }) {
    final shortcutTarget = _resolveShortcutTargetPath(launchPath);
    final candidates = <String>[
      executablePath ?? '',
      targetPath,
      shortcutTarget ?? '',
      indicatorIconPath,
    ];

    for (final candidate in candidates) {
      final normalized = _normalizeExistingFilePath(candidate);
      if (normalized == null) continue;
      if (_isShortcutContainerPath(normalized)) continue;

      final bytes = extractIcon(normalized, size: 256);
      if (bytes != null && bytes.isNotEmpty) {
        return bytes;
      }
    }

    return fallbackPreferredIconBytes;
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

  String _normalizeDisplayName(String rawName) {
    var value = rawName.trim();
    const suffixes = [' - 快捷方式', ' - shortcut'];
    for (final suffix in suffixes) {
      if (value.toLowerCase().endsWith(suffix.toLowerCase())) {
        value = value.substring(0, value.length - suffix.length).trimRight();
      }
    }
    return value.isEmpty ? '应用' : value;
  }

  Future<void> _waitUntilTargetWindowReady(
    String executablePath, {
    required int preLaunchWindowCount,
  }) async {
    final minIndicatorTime = Future<void>.delayed(
      const Duration(milliseconds: 450),
    );

    final detectWindow = () async {
      if (!Platform.isWindows) return;
      final startedAt = DateTime.now();
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      final hadExistingInstance = preLaunchWindowCount > 0;
      while (DateTime.now().isBefore(deadline)) {
        final currentWindowCount = _windowLocator
            .countTopLevelWindowsByExecutable(executablePath);
        if (currentWindowCount > preLaunchWindowCount) {
          return;
        }

        if (hadExistingInstance &&
            _windowLocator.isForegroundWindowFromExecutable(executablePath)) {
          return;
        }

        if (hadExistingInstance &&
            currentWindowCount > 0 &&
            DateTime.now().difference(startedAt).inMilliseconds >= 1200) {
          return;
        }

        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }();

    await Future.wait<void>([minIndicatorTime, detectWindow]);
  }
}
