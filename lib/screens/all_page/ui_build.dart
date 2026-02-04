part of '../all_page.dart';

extension _AllPageUi on _AllPageState {
  Widget _buildSelectionDetail() {
    final selected = _selected;
    if (selected == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: EntityDetailBar(
        name: selected.name,
        path: selected.fullPath,
        folderPath: selected.folderPath,
        onCopyName: () =>
            _copyToClipboard(selected.name, label: '名称', quoted: false),
        onCopyPath: () =>
            _copyToClipboard(selected.fullPath, label: '路径', quoted: true),
        onCopyFolder: () =>
            _copyToClipboard(selected.folderPath, label: '文件夹', quoted: true),
        onRename: (newName) => _renameEntity(selected.entity, newName),
        onEditingChanged: (editing) =>
            _setState(() => _isDetailEditing = editing),
      ),
    );
  }

  Widget _buildBody() {
    final pathLabel = _currentPath ?? '${widget.desktopPath} (合并视图)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            opacity: 0.14,
            blurSigma: 10,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: const Icon(Icons.home),
                  onPressed: _currentPath == null ? null : _goHome,
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _currentPath == null ? null : _goUp,
                ),
                Expanded(
                  child: Text(
                    pathLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            opacity: 0.14,
            blurSigma: 10,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.16),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: '搜索...',
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: Theme.of(
                          context,
                        ).iconTheme.color?.withValues(alpha: 0.7),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) => _setState(() => _searchQuery = value),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                Builder(
                  builder: (menuContext) {
                    final iconColor = Theme.of(
                      menuContext,
                    ).iconTheme.color?.withValues(alpha: 0.7);
                    return IconButton(
                      padding: const EdgeInsets.all(8),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.sort, size: 20, color: iconColor),
                      onPressed: () {
                        final overlayBox =
                            Overlay.of(menuContext).context.findRenderObject()
                                as RenderBox?;
                        final buttonBox =
                            menuContext.findRenderObject() as RenderBox?;
                        if (overlayBox == null || buttonBox == null) return;
                        final topLeft = buttonBox.localToGlobal(
                          Offset.zero,
                          ancestor: overlayBox,
                        );
                        final menuPosition = RelativeRect.fromRect(
                          Rect.fromLTWH(
                            topLeft.dx,
                            topLeft.dy,
                            buttonBox.size.width,
                            buttonBox.size.height,
                          ),
                          Offset.zero & overlayBox.size,
                        );

                        Future.microtask(() async {
                          if (!mounted) return;
                          final type = await showMenu<_SortType>(
                            context: menuContext,
                            position: menuPosition,
                            items: [
                              PopupMenuItem(
                                value: _SortType.name,
                                child: _buildSortItem('名称', _SortType.name),
                              ),
                              PopupMenuItem(
                                value: _SortType.date,
                                child: _buildSortItem('修改时间', _SortType.date),
                              ),
                              PopupMenuItem(
                                value: _SortType.size,
                                child: _buildSortItem('大小', _SortType.size),
                              ),
                              PopupMenuItem(
                                value: _SortType.type,
                                child: _buildSortItem('类型', _SortType.type),
                              ),
                            ],
                          );
                          if (!mounted || type == null) return;
                          if (_sortType == type) {
                            _setState(() => _sortAscending = !_sortAscending);
                            return;
                          }
                          _setState(() {
                            _sortType = type;
                            _sortAscending = true;
                          });
                        });
                      },
                    );
                  },
                ),
                if (_selected != null)
                  IconButton(
                    icon: Icon(
                      _showDetails ? Icons.info : Icons.info_outline,
                      size: 20,
                      color: _showDetails
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).iconTheme.color?.withValues(alpha: 0.7),
                    ),
                    onPressed: () =>
                        _setState(() => _showDetails = !_showDetails),
                  ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_EntityFilterMode>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _EntityFilterMode.all, label: Text('全部')),
                ButtonSegment(
                  value: _EntityFilterMode.folders,
                  label: Text('文件夹'),
                ),
                ButtonSegment(
                  value: _EntityFilterMode.files,
                  label: Text('文件'),
                ),
              ],
              selected: {_filterMode},
              onSelectionChanged: (newSelection) =>
                  _setState(() => _filterMode = newSelection.first),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final showDetailsPanel = _selected != null && _showDetails;

              Widget buildList() {
                return _filteredItems.isEmpty
                    ? const Center(child: Text('未找到文件或快捷方式'))
                    : RepaintBoundary(
                        child: ListView.builder(
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final entity = item.entity;
                            final isDir = item.isDirectory;
                            final displayName =
                                item.name.toLowerCase().endsWith('.lnk')
                                ? item.name.substring(0, item.name.length - 4)
                                : item.name;
                            final isSelected =
                                _selected?.fullPath == entity.path;
                            return Material(
                              key: ValueKey(entity.path),
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              child: InkWell(
                                onFocusChange: (hasFocus) {
                                  if (hasFocus) {
                                    _selectEntity(entity, displayName);
                                  }
                                },
                                onTapDown: (_) {
                                  _selectEntity(entity, displayName);
                                  _focusNode.requestFocus();
                                },
                                onTap: () async {
                                  final now =
                                      DateTime.now().millisecondsSinceEpoch;
                                  if (now - _lastTapTime < 300 &&
                                      _lastTappedPath == entity.path) {
                                    if (isDir)
                                      _openFolder(entity.path);
                                    else
                                      await openWithDefault(entity.path);
                                    _lastTapTime = 0;
                                  } else {
                                    _lastTapTime = now;
                                    _lastTappedPath = entity.path;
                                  }
                                },
                                onSecondaryTapDown: (details) {
                                  _selectEntity(entity, displayName);
                                  _focusNode.requestFocus();
                                  final pos = details.globalPosition;
                                  Future.microtask(() {
                                    if (!mounted) return;
                                    _showEntityMenu(
                                      entity,
                                      displayName,
                                      pos,
                                      anchorContext: context,
                                    );
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                hoverColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  leading: _EntityIcon(
                                    entity: entity,
                                    getIconFuture: _getIconFuture,
                                    beautifyIcon: widget.beautifyIcons,
                                    beautifyStyle: widget.beautifyStyle,
                                  ),
                                  title: Text(
                                    displayName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: MiddleEllipsisText(
                                    text: entity.path,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
              }

              Widget buildDetails() {
                if (!showDetailsPanel) return const SizedBox.shrink();
                return SizedBox(
                  width: isWide
                      ? (constraints.maxWidth * 0.45 > 320
                            ? 320
                            : constraints.maxWidth * 0.45)
                      : double.infinity,
                  child: SingleChildScrollView(child: _buildSelectionDetail()),
                );
              }

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
                      if (_selected != null) {
                        copyEntityPathsToClipboard([_selected!.fullPath]);
                        _showSnackBar('已复制到剪贴板');
                        return KeyEventResult.handled;
                      }
                    } else if (event.logicalKey == LogicalKeyboardKey.keyV) {
                      _handlePaste();
                      return KeyEventResult.handled;
                    }
                  }
                  if (_isDetailEditing) return KeyEventResult.ignored;
                  final focus = FocusManager.instance.primaryFocus;
                  if (focus?.context?.widget is EditableText)
                    return KeyEventResult.ignored;

                  if (event.logicalKey == LogicalKeyboardKey.delete ||
                      event.logicalKey == LogicalKeyboardKey.backspace ||
                      event.logicalKey == LogicalKeyboardKey.numpadDecimal) {
                    if (_selected != null) {
                      _deleteEntity(File(_selected!.fullPath));
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey == LogicalKeyboardKey.f2) {
                    if (_selected != null) {
                      _promptRename(_selected!.entity, null);
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
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: buildList()),
                            buildDetails(),
                          ],
                        )
                      : Column(
                          children: [
                            buildDetails(),
                            Expanded(child: buildList()),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
