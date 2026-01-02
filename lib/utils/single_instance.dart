import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SingleInstance {
  static const int _port = 43991;
  static const String _activateMessage = 'activate';

  static ServerSocket? _server;
  static RandomAccessFile? _lockFile;
  static final String _lockPath = () {
    final base =
        Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return '${base.replaceAll('\\', '/')}/desk_tidy_single_instance.lock';
  }();

  static Future<bool> ensure({
    required Future<void> Function() onActivate,
  }) async {
    // File lock guard to prevent multiple processes.
    final ok = await _acquireFileLock();
    if (!ok) {
      await _sendActivate();
      return false;
    }

    try {
      _server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _port,
        shared: false,
      );
    } on SocketException {
      // Another instance is already listening.
      await _sendActivate();
      return false;
    }

    unawaited(_listen(onActivate));
    return true;
  }

  static Future<void> _listen(Future<void> Function() onActivate) async {
    final server = _server;
    if (server == null) return;

    await for (final client in server) {
      client.listen(
        (data) async {
          final msg = utf8.decode(data).trim();
          if (msg == _activateMessage) {
            await onActivate();
          }
        },
        onDone: () => client.close(),
        onError: (_) => client.close(),
        cancelOnError: true,
      );
    }
  }

  static Future<void> _sendActivate() async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        _port,
        timeout: const Duration(milliseconds: 400),
      );
      socket.add(utf8.encode(_activateMessage));
      await socket.flush();
      await socket.close();
    } catch (_) {
      // Ignore; we tried to notify the existing instance.
    }
  }

  /// Release resources (only needed for tests; OS cleans up on exit).
  static Future<void> dispose() async {
    final file = _lockFile;
    await file?.unlock();
    await file?.close();
    _lockFile = null;
    await _server?.close();
    _server = null;
  }

  static Future<bool> _acquireFileLock() async {
    try {
      final file = File(_lockPath);
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
      final raf = await file.open(mode: FileMode.write);
      try {
        await raf.lock(FileLock.exclusive);
      } on FileSystemException {
        await raf.close();
        return false;
      }
      _lockFile = raf;
      return true;
    } catch (_) {
      return true; // Fail open to avoid blocking launch if fs not writable.
    }
  }
}
