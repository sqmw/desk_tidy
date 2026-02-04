part of '../folder_page.dart';

extension _FolderPageUi on _FolderPageState {
  Widget _buildBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            opacity: 0.1,
            blurSigma: 10,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: _isRootPath ? null : _goUp,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentPath,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _refresh,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Focus(
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
                  _deleteEntity(File(_selectedPath!));
                  return KeyEventResult.handled;
                }
              } else if (event.logicalKey == LogicalKeyboardKey.f2) {
                if (_selectedPath != null) {
                  final entity = File(_selectedPath!).existsSync()
                      ? File(_selectedPath!) as FileSystemEntity
                      : Directory(_selectedPath!);
                  _promptRename(entity);
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapDown: (details) {
                final pos = details.globalPosition;
                Future.microtask(() {
                  if (!mounted) return;
                  _showPageMenu(pos);
                });
              },
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_error != null
                        ? Center(child: Text(_error!))
                        : (_entries.isEmpty
                              ? const Center(child: Text('未找到内容'))
                              : GridView.builder(
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 100,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.8,
                                      ),
                                  itemCount: _entries.length,
                                  itemBuilder: (context, index) {
                                    final entity = _entries[index];
                                    final name = path.basename(entity.path);
                                    final isDir = entity is Directory;
                                    final isSelected =
                                        entity.path == _selectedPath;
                                    return Material(
                                      color: isSelected
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.1)
                                          : Colors.transparent,
                                      child: InkWell(
                                        onTapDown: (_) {
                                          _setState(
                                            () => _selectedPath = entity.path,
                                          );
                                          _focusNode.requestFocus();
                                        },
                                        onTap: () {
                                          final now = DateTime.now()
                                              .millisecondsSinceEpoch;
                                          if (now - _lastTapTime < 300 &&
                                              _lastTappedPath == entity.path) {
                                            if (isDir)
                                              _openFolder(entity.path);
                                            else
                                              openWithDefault(entity.path);
                                            _lastTapTime = 0;
                                          } else {
                                            _lastTapTime = now;
                                            _lastTappedPath = entity.path;
                                          }
                                        },
                                        onSecondaryTapDown: (details) {
                                          _setState(
                                            () => _selectedPath = entity.path,
                                          );
                                          _focusNode.requestFocus();
                                          final pos = details.globalPosition;
                                          Future.microtask(() {
                                            if (!mounted) return;
                                            _showEntityMenu(entity, pos);
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        hoverColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _EntityIcon(
                                              entity: entity,
                                              beautifyIcon:
                                                  widget.beautifyIcons,
                                              beautifyStyle:
                                                  widget.beautifyStyle,
                                              getIconFuture: _getIconFuture,
                                            ),
                                            const SizedBox(height: 8),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              child: Text(
                                                name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(fontSize: 11),
                                                maxLines: 2,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ))),
            ),
          ),
        ),
      ],
    );
  }
}
