import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SingleInstance {
  static const int _port = 43991;
  static const String _activateMessage = 'activate';

  static ServerSocket? _server;

  static Future<bool> ensure({
    required Future<void> Function() onActivate,
  }) async {
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
}
