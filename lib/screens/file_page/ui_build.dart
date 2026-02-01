part of '../file_page.dart';

extension _FilePageUi on _FilePageState {
  Widget _buildBody() {
    if (_files.isEmpty) return const Center(child: Text('未找到文件'));
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final isCtrl =
            HardwareKeyboard.instance.isLogicalKeyPressed(
              LogicalKeyboardKey.controlLeft,
            ) ||
            HardwareKeyboard.instance.isLogicalKeyPressed(
              LogicalKeyboardKey.controlRight,
            );
        if (isCtrl) {
          if (event.logicalKey == LogicalKeyboardKey.keyC) {
            if (_selectedPath != null) {
              copyEntityPathsToClipboard([_selectedPath!]);
              _showSnackBar('已复制到剪贴板');
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.keyV) {
            _handlePaste();
            return KeyEventResult.handled;
          }
        }
        final focus = FocusManager.instance.primaryFocus;
        if (focus?.context?.widget is EditableText)
          return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.numpadDecimal) {
          if (_selectedPath != null) {
            _deleteFile(_selectedPath!);
            return KeyEventResult.handled;
          }
        } else if (event.logicalKey == LogicalKeyboardKey.f2) {
          if (_selectedPath != null) {
            _promptRenameFile(context, File(_selectedPath!));
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) => _showPageMenu(details.globalPosition),
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 100,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: _files.length,
          itemBuilder: (context, index) {
            final file = _files[index];
            final name = path.basename(file.path);
            final isSelected = file.path == _selectedPath;
            return Material(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              child: InkWell(
                onTapDown: (_) {
                  _setState(() => _selectedPath = file.path);
                  _focusNode.requestFocus();
                },
                onTap: () {
                  final now = DateTime.now().millisecondsSinceEpoch;
                  if (now - _lastTapTime < 300 &&
                      _lastTappedPath == file.path) {
                    openWithDefault(file.path);
                    _lastTapTime = 0;
                  } else {
                    _lastTapTime = now;
                    _lastTappedPath = file.path;
                  }
                },
                onSecondaryTapDown: (details) {
                  _setState(() => _selectedPath = file.path);
                  _focusNode.requestFocus();
                  _showFileMenu(context, file, details.globalPosition);
                },
                borderRadius: BorderRadius.circular(12),
                hoverColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FileIcon(
                        filePath: file.path,
                        beautifyIcon: widget.beautifyIcons,
                        beautifyStyle: widget.beautifyStyle,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Tooltip(
                          message: name,
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(height: 1.2, fontSize: 11),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
