import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'app_logger.dart';

class PerfMonitor {
  PerfMonitor._();

  static Timer? _timer;
  static bool _started = false;

  static bool get isRunning => _timer != null;

  static void start({Duration? interval}) {
    if (_started) return;
    _started = true;
    final enabled = _readBoolEnv('DESK_TIDY_PERF_LOG') ?? kDebugMode;
    if (!enabled) return;

    final tickInterval =
        interval ??
        (kDebugMode ? const Duration(seconds: 3) : const Duration(seconds: 10));
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) => _logOnce());
    _logOnce();
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static void _logOnce() {
    final rss = _mb(ProcessInfo.currentRss);
    final maxRss = _mb(ProcessInfo.maxRss);
    final imageCache = PaintingBinding.instance.imageCache;
    AppLogger.info(
      'perf',
      details: {
        'rss_mb': rss,
        'max_rss_mb': maxRss,
        'image_cache_bytes_mb': _mb(imageCache.currentSizeBytes),
        'image_cache_items': imageCache.currentSize,
        'image_cache_max_bytes_mb': _mb(imageCache.maximumSizeBytes),
        'image_cache_max_items': imageCache.maximumSize,
      },
    );
  }

  static double _mb(int bytes) {
    return double.parse((bytes / (1024 * 1024)).toStringAsFixed(2));
  }

  static bool? _readBoolEnv(String key) {
    final raw = Platform.environment[key];
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (['1', 'true', 'yes', 'y', 'on'].contains(v)) return true;
    if (['0', 'false', 'no', 'n', 'off'].contains(v)) return false;
    return null;
  }
}
