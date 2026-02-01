part of '../file_page.dart';

class FilePage extends StatefulWidget {
  final String desktopPath;
  final bool showHidden;
  final bool beautifyIcons;
  final IconBeautifyStyle beautifyStyle;

  const FilePage({
    super.key,
    required this.desktopPath,
    this.showHidden = false,
    this.beautifyIcons = false,
    this.beautifyStyle = IconBeautifyStyle.cute,
  });

  @override
  State<FilePage> createState() => _FilePageState();
}

class _FilePageState extends State<FilePage> {
  String? _selectedPath;
  final FocusNode _focusNode = FocusNode();
  List<File> _files = [];
  int _lastTapTime = 0;
  String _lastTappedPath = '';

  void _setState(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showHidden != widget.showHidden ||
        oldWidget.desktopPath != widget.desktopPath) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_files.isEmpty) return const Center(child: Text('未找到文件'));
    return _buildBody();
  }
}
