import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  AppLogger._();

  static IOSink? _sink;
  static String? _logPath;
  static Timer? _flushTimer;

  static String? get logPath => _logPath;

  static Future<void> init() async {
    if (_sink != null) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final logDir = Directory('${dir.path}${Platform.pathSeparator}logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final file = File('${logDir.path}${Platform.pathSeparator}desk_tidy.log');
      _logPath = file.path;
      _sink = file.openWrite(mode: FileMode.append);
      _flushTimer?.cancel();
      _flushTimer = Timer.periodic(const Duration(seconds: 2), (_) => flush());
      info('logger init', details: {'path': _logPath});
    } catch (e, st) {
      debugPrint('AppLogger init failed: $e\n$st');
    }
  }

  static void info(String message, {Map<String, Object?>? details}) {
    _write('INFO', message, details: details);
  }

  static void warn(String message, {Map<String, Object?>? details}) {
    _write('WARN', message, details: details);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? details,
  }) {
    _write(
      'ERROR',
      message,
      error: error,
      stackTrace: stackTrace,
      details: details,
    );
  }

  static void _write(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? details,
  }) {
    final ts = DateTime.now().toIso8601String();
    final buf = StringBuffer()..write('$ts [$level] $message');
    if (details != null && details.isNotEmpty) {
      buf.write(' ');
      buf.write(details);
    }
    if (error != null) {
      buf.write(' error=$error');
    }
    if (stackTrace != null) {
      buf.write('\n$stackTrace');
    }
    final line = buf.toString();

    try {
      _sink?.writeln(line);
    } catch (_) {}
    if (kDebugMode) {
      debugPrint(line);
    }
  }

  static Future<void> flush() async {
    try {
      await _sink?.flush();
    } catch (_) {}
  }

  static Future<void> dispose() async {
    final sink = _sink;
    _sink = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    try {
      await sink?.flush();
      await sink?.close();
    } catch (_) {}
  }
}

Future<T> runWithLogging<T>(
  FutureOr<T> Function() body, {
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  final completer = Completer<T>();
  runZonedGuarded(
    () async {
      try {
        final value = await body();
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
        rethrow;
      }
    },
    (error, stackTrace) {
      AppLogger.error('uncaught', error: error, stackTrace: stackTrace);
      onError?.call(error, stackTrace);
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
  );
  return completer.future;
}
