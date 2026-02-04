part of '../desktop_helper.dart';

const int _invalidFileAttributes = 0xFFFFFFFF;
const int _shilJumbo = 0x4;
const int _ildTransparent = 0x00000001;
const int _ildImage = 0x00000020;
const int _diNormal = 0x0003;
const String _iidIImageList = '{46EB5926-582E-4017-9FDF-E8998DAA0950}';

final DynamicLibrary _shell32 = DynamicLibrary.open('shell32.dll');
final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

const int _smtoAbortIfHung = 0x0002;
const int _hwndBroadcast = 0xFFFF;
const int _smtoNormal = 0x0000;
const int _wmSettingChange = 0x001A;
const int _timeoutMs = 1000;
const int _wmThemeChanged = 0x031A;
const int _shcneAssocChanged = 0x08000000;
const int _shcnfIdList = 0x0000;
const int _wmCommand = 0x0111;
const int _cmdToggleDesktopIcons = 0x7402;
const int _dropEffectCopy = 1;
const int _dropEffectMove = 2;
const String _clipboardDropEffectFormat = 'Preferred DropEffect';

bool? _readBoolEnv(String key) {
  final raw = Platform.environment[key];
  if (raw == null) return null;
  final v = raw.trim().toLowerCase();
  if (v.isEmpty) return null;
  if (['1', 'true', 'yes', 'y', 'on'].contains(v)) return true;
  if (['0', 'false', 'no', 'n', 'off'].contains(v)) return false;
  return null;
}

final bool? _iconIsolatesEnvOverride =
    _readBoolEnv('DESK_TIDY_ICON_ISOLATES');
bool _enableIconIsolates = _iconIsolatesEnvOverride ?? true;

// Cache extracted icons by a stable key to avoid repeated FFI work.
const int _iconCacheVersion = 9;
const int _iconCacheCapacity = 256;
final LinkedHashMap<String, Uint8List?> _iconCache =
    LinkedHashMap<String, Uint8List?>();
final Map<String, Future<Uint8List?>> _iconInFlight = {};

class _IconTask {
  final String path;
  final int size;
  final String cacheKey;
  final Completer<Uint8List?> completer;

  _IconTask(this.path, this.size, this.cacheKey, this.completer);
}

final Queue<_IconTask> _iconTaskQueue = Queue<_IconTask>();
int _activeIconIsolates = 0;
// Limit concurrent isolates to avoid creating too many DCs at once.
const int _maxIconIsolates = 3;
final Queue<_IconTask> _mainIconTaskQueue = Queue<_IconTask>();
bool _mainIconDrainScheduled = false;

void _debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
