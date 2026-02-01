part of '../all_page.dart';

class AllPage extends StatefulWidget {
  final String desktopPath;
  final bool showHidden;
  final bool beautifyIcons;
  final IconBeautifyStyle beautifyStyle;

  const AllPage({
    super.key,
    required this.desktopPath,
    this.showHidden = false,
    this.beautifyIcons = false,
    this.beautifyStyle = IconBeautifyStyle.cute,
  });

  @override
  State<AllPage> createState() => _AllPageState();
}

class _AllPageState extends State<AllPage> {
  String? _currentPath; // null means aggregate desktop roots
  bool _loading = true;
  String? _error;
  List<FileItem> _items = [];
  bool _entityMenuActive = false;

  // Search & Sort State
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  _SortType _sortType = _SortType.name;
  bool _sortAscending = true;
  _EntitySelectionInfo? _selected;
  bool _isDetailEditing = false;
  bool _showDetails = true;
  _EntityFilterMode _filterMode = _EntityFilterMode.all;
  final Map<String, Future<Uint8List?>> _iconFutures = {};

  // Custom double-tap state
  int _lastTapTime = 0;
  String _lastTappedPath = '';
  final FocusNode _focusNode = FocusNode();
  final FloatingRenameOverlay _renameOverlay = FloatingRenameOverlay();

  void _setState(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AllPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showHidden != widget.showHidden) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    return _buildBody();
  }
}
