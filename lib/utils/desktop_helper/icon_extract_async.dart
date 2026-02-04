part of '../desktop_helper.dart';

Future<Uint8List?> extractIconAsync(String filePath, {int size = 64}) {
  final desiredSize = size.clamp(16, 256);
  final cacheKey = _cacheKeyForFile(filePath, desiredSize);
  final cached = _readIconCache(cacheKey);
  if (cached.found) return Future.value(cached.value);

  final existing = _iconInFlight[cacheKey];
  if (existing != null) return existing;

  final completer = Completer<Uint8List?>();
  _iconInFlight[cacheKey] = completer.future;
  final task = _IconTask(filePath, desiredSize, cacheKey, completer);
  if (_enableIconIsolates) {
    _iconTaskQueue.add(task);
    _drainIconTasks();
  } else {
    _mainIconTaskQueue.add(task);
    _scheduleMainIconDrain();
  }
  return completer.future;
}

bool get iconIsolatesEnabled => _enableIconIsolates;

void setIconIsolatesEnabled(bool enabled) {
  _enableIconIsolates = _iconIsolatesEnvOverride ?? enabled;
  _drainIconTasks();
}

void _drainIconTasks() {
  if (!_enableIconIsolates) {
    while (_iconTaskQueue.isNotEmpty) {
      _mainIconTaskQueue.add(_iconTaskQueue.removeFirst());
    }
    _scheduleMainIconDrain();
    return;
  }
  while (_activeIconIsolates < _maxIconIsolates && _iconTaskQueue.isNotEmpty) {
    final task = _iconTaskQueue.removeFirst();
    _activeIconIsolates++;
    final path = task.path;
    final size = task.size;

    _runIconIsolate(path, size)
        .then((data) {
          final result = (data == null || data.isEmpty) ? null : data;
          if (result != null) {
            _writeIconCache(task.cacheKey, result);
            task.completer.complete(result);
            _iconInFlight.remove(task.cacheKey);
          } else {
            _debugLog('icon isolate empty: ${task.path} size=${task.size}');
            _mainIconTaskQueue.add(task);
            _scheduleMainIconDrain();
          }
        })
        .catchError((err, st) {
          _debugLog(
            'icon isolate error: ${task.path} size=${task.size} err=$err\n$st',
          );
          _mainIconTaskQueue.add(task);
          _scheduleMainIconDrain();
        })
        .whenComplete(() {
          _activeIconIsolates--;
          _drainIconTasks();
        });
  }
}

void _scheduleMainIconDrain() {
  if (_mainIconDrainScheduled) return;
  _mainIconDrainScheduled = true;
  Future<void>(() async {
    while (_mainIconTaskQueue.isNotEmpty) {
      final task = _mainIconTaskQueue.removeFirst();
      Uint8List? result;
      try {
        result = extractIcon(task.path, size: task.size);
      } catch (_) {
        _debugLog('icon main fallback error: ${task.path} size=${task.size}');
        result = null;
      }
      _writeIconCache(task.cacheKey, result);
      if (!task.completer.isCompleted) {
        task.completer.complete(result);
      }
      _iconInFlight.remove(task.cacheKey);
      // Yield between tasks to keep UI responsive.
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    _mainIconDrainScheduled = false;
  });
}

_IconCacheResult _readIconCache(String key) {
  if (!_iconCache.containsKey(key)) return const _IconCacheResult(found: false);
  return _IconCacheResult(found: true, value: _iconCache[key]);
}

void _writeIconCache(String key, Uint8List? value) {
  // Cache null results too, to avoid repeated extraction for missing icons.
  // Refresh insertion order for LRU.
  _iconCache.remove(key);
  _iconCache[key] = value;
  while (_iconCache.length > _iconCacheCapacity) {
    _iconCache.remove(_iconCache.keys.first);
  }
}

String _cacheKeyForLocation(_IconLocation loc, int size) =>
    'v$_iconCacheVersion|loc:${path.normalize(loc.path)}|${loc.index}|$size';

String _cacheKeyForSystemIndex(int index, int size) =>
    'v$_iconCacheVersion|sys:$index|$size';

String _cacheKeyForFile(String filePath, int size) =>
    'v$_iconCacheVersion|file:${path.normalize(filePath)}|$size';

bool _ensureComReady() {
  final hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  return hr == S_OK || hr == S_FALSE;
}

Uint8List? _extractIconIsolate(String path, int size) {
  return extractIcon(path, size: size);
}

Future<Uint8List?> _runIconIsolate(String path, int size) async {
  final port = ReceivePort();
  await Isolate.spawn(_iconIsolateEntry, <Object>[port.sendPort, path, size]);
  final message = await port.first;
  port.close();
  if (message is TransferableTypedData) {
    return message.materialize().asUint8List();
  }
  if (message is Uint8List) {
    return message;
  }
  return null;
}

void _iconIsolateEntry(List<Object> args) {
  final sendPort = args[0] as SendPort;
  final path = args[1] as String;
  final size = args[2] as int;
  final bytes = _extractIconIsolate(path, size);
  if (bytes == null || bytes.isEmpty) {
    sendPort.send(null);
    return;
  }
  sendPort.send(TransferableTypedData.fromList([bytes]));
}

List<String> getClipboardFilePaths() {
  if (!Platform.isWindows) return [];
  if (OpenClipboard(NULL) == 0) return [];

  final paths = <String>[];
  try {
    final hDrop = GetClipboardData(CF_HDROP);
    if (hDrop != 0) {
      final count = DragQueryFile(hDrop, 0xFFFFFFFF, nullptr, 0);
      for (var i = 0; i < count; i++) {
        final len = DragQueryFile(hDrop, i, nullptr, 0);
        if (len > 0) {
          final buffer = calloc<Uint16>(len + 1);
          try {
            DragQueryFile(hDrop, i, buffer.cast<Utf16>(), len + 1);
            paths.add(buffer.cast<Utf16>().toDartString());
          } finally {
            calloc.free(buffer);
          }
        }
      }
    }
  } finally {
    CloseClipboard();
  }
  return paths;
}

Future<String?> createNewFolder(
  String parentPath, {
  String preferredName = '新建文件夹',
}) async {
  try {
    final dir = Directory(parentPath);
    if (!dir.existsSync()) return null;

    String targetName = preferredName;
    String targetPath = path.join(parentPath, targetName);
    int counter = 2;

    while (Directory(targetPath).existsSync() ||
        File(targetPath).existsSync()) {
      targetName = '$preferredName ($counter)';
      targetPath = path.join(parentPath, targetName);
      counter++;
    }

    await Directory(targetPath).create();
    return targetPath;
  } catch (e) {
    debugPrint('Error creating folder: $e');
    return null;
  }
}

Future<void> showInExplorer(String targetPath) async {
  try {
    // explorer.exe /select,"path" opens the folder and selects the file.
    await Process.run('explorer.exe', ['/select,', targetPath]);
  } catch (e) {
    debugPrint('Error showing in explorer: $e');
  }
}
