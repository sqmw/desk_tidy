import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

class BoxLauncher {
  BoxLauncher._();
  static final BoxLauncher instance = BoxLauncher._();

  Process? _foldersProc;
  Process? _filesProc;

  Future<void> updateBoxes({
    required bool enabled,
    required String desktopPath,
  }) async {
    if (!Platform.isWindows) return;

    if (!enabled) {
      await stopAll();
      return;
    }

    await _ensureRunning('folders', desktopPath);
    await _ensureRunning('files', desktopPath);
  }

  Future<void> stopAll() async {
    _foldersProc?.kill();
    _foldersProc = null;
    _filesProc?.kill();
    _filesProc = null;

    // Also try to find and kill by name just in case
    await Process.run('taskkill', ['/F', '/IM', 'desk_tidy_box.exe', '/T']);
  }

  Future<void> _ensureRunning(String type, String desktopPath) async {
    final current = type == 'folders' ? _foldersProc : _filesProc;
    if (current != null) {
      // Check if still alive
      final isAlive = await _isAlive(current);
      if (isAlive) return;
    }

    final exePath = await _getBoxExePath();
    if (exePath == null) {
      print('Error: Could not find desk_tidy_box.exe');
      return;
    }

    final args = [
      '--type=$type',
      '--desktop-path=$desktopPath',
      '--parent-pid=$pid',
    ];

    try {
      final proc = await Process.start(
        exePath,
        args,
        mode: ProcessStartMode.detachedWithStdio,
      );

      if (type == 'folders') {
        _foldersProc = proc;
      } else {
        _filesProc = proc;
      }

      // Drain streams to avoid hanging
      unawaited(proc.stdout.drain());
      unawaited(proc.stderr.drain());
    } catch (e) {
      print('Failed to start box process: $e');
    }
  }

  Future<bool> _isAlive(Process proc) async {
    try {
      // In detached mode, we might not get exitCode easily.
      // This is a simple check.
      return await proc.exitCode
          .then((_) => false)
          .timeout(const Duration(milliseconds: 10), onTimeout: () => true);
    } catch (_) {
      return false;
    }
  }

  Future<String?> _getBoxExePath() async {
    // 1. Production: Same directory as current exe
    final mainExe = Platform.resolvedExecutable;
    final mainDir = p.dirname(mainExe);
    final prodPath = p.join(mainDir, 'box', 'desk_tidy_box.exe');
    if (await File(prodPath).exists()) return prodPath;

    // 2. Development: Sibling project directory
    // Main app: f:\language\dart\code\desk_tidy\build\windows\x64\runner\Debug\desk_tidy.exe
    // Box app:  f:\language\dart\code\desk_tidy_box\build\windows\x64\runner\Debug\desk_tidy_box.exe

    // Attempt relative path from current exe
    final devPath = p.join(
      mainDir,
      '..',
      '..',
      '..',
      '..',
      '..',
      'desk_tidy_box',
      'build',
      'windows',
      'x64',
      'runner',
      'Debug',
      'desk_tidy_box.exe',
    );
    if (await File(devPath).exists()) return devPath;

    // Attempt absolute path as fallback
    const fallbackPath =
        'f:\\language\\dart\\code\\desk_tidy_box\\build\\windows\\x64\\runner\\Debug\\desk_tidy_box.exe';
    if (await File(fallbackPath).exists()) return fallbackPath;

    return null;
  }
}
