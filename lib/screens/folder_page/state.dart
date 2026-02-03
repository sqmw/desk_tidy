part of '../folder_page.dart';

class FolderPage extends StatefulWidget {
  final String desktopPath;
  final bool showHidden;
  final bool beautifyIcons;
  final IconBeautifyStyle beautifyStyle;

  const FolderPage({
    super.key,
    required this.desktopPath,
    this.showHidden = false,
    this.beautifyIcons = false,
    this.beautifyStyle = IconBeautifyStyle.cute,
  });

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  late String _currentPath;
  bool _loading = true;
  String? _error;
  List<FileSystemEntity> _entries = [];
  bool _entityMenuActive = false;
  String? _selectedPath;
  static const int _iconFutureCacheCapacity = 512;
  final LinkedHashMap<String, Future<Uint8List?>> _iconFutures =
      LinkedHashMap<String, Future<Uint8List?>>();
  int _lastTapTime = 0;
  String _lastTappedPath = '';
  final FocusNode _focusNode = FocusNode();

  bool get _isRootPath {
    final current = path.normalize(_currentPath).toLowerCase();
    final root = path.normalize(widget.desktopPath).toLowerCase();
    return current == root;
  }

  void _setState(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _currentPath = widget.desktopPath;
    _refresh();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _iconFutures.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FolderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showHidden != widget.showHidden) _refresh();
  }

  @override
  Widget build(BuildContext context) => _buildBody();
}
