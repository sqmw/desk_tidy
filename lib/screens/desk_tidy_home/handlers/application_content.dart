part of '../../desk_tidy_home_page.dart';

extension _DeskTidyHomeApplicationContent on _DeskTidyHomePageState {
  Widget _buildApplicationContent() {
    final scale = _uiScale(context);
    final shortcuts = _filteredShortcuts;
    final searchActive = normalizeSearchText(_appSearchQuery).isNotEmpty;
    final isFiltering = _activeCategoryId != null;
    final editingCategory = _isEditingCategory;
    final editingName = _categories
        .firstWhere(
          (c) => c.id == _editingCategoryId,
          orElse: () => AppCategory.empty,
        )
        .name;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            10 * scale,
            10 * scale,
            10 * scale,
            6 * scale,
          ),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(16),
            // Use a lighter tint here; the whole content already sits on a
            // frosted panel, so a dark tint makes this strip look "blackened".
            color: Colors.white,
            opacity: _toolbarPanelOpacity,
            blurSigma: _toolbarPanelBlur,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.16),
            ),
            padding: EdgeInsets.fromLTRB(
              10 * scale,
              6 * scale,
              10 * scale,
              10 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryStrip(
                  categories: _categories,
                  activeCategoryId: _activeCategoryId,
                  totalCount: _shortcuts.length,
                  scale: scale,
                  onAllSelected: () => _handleCategorySelected(null),
                  onCategorySelected: (id) => _handleCategorySelected(id),
                  onReorder: _reorderVisibleCategories,
                  onRenameRequested: _renameCategory,
                  onDeleteRequested: _deleteCategory,
                  onEditRequested: (_) => _beginInlineCategoryEdit(),
                ),
                SizedBox(height: 8 * scale),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final showCount =
                        searchActive && constraints.maxWidth > 420 * scale;
                    return Row(
                      children: [
                        Expanded(child: _buildSearchBar(scale)),
                        if (showCount) ...[
                          SizedBox(width: 8 * scale),
                          _buildSearchCountChip(
                            scale,
                            matchCount: shortcuts.length,
                            totalCount: _shortcuts.length,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (editingCategory)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 4 * scale,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420 * scale;

                Future<void> handleDelete() async {
                  final id = _editingCategoryId;
                  if (id == null) return;
                  final category = _categories.firstWhere(
                    (c) => c.id == id,
                    orElse: () => AppCategory.empty,
                  );
                  if (category.id.isEmpty) return;
                  await _deleteCategory(category);
                }

                Widget actions;
                if (compact) {
                  final iconSize = (constraints.maxWidth * 0.045).clamp(
                    20 * scale,
                    24 * scale,
                  );
                  final btnWidth = (constraints.maxWidth * 0.085).clamp(
                    40 * scale,
                    56 * scale,
                  );
                  final btnHeight = (constraints.maxWidth * 0.070).clamp(
                    34 * scale,
                    40 * scale,
                  );
                  final btnConstraints = BoxConstraints.tightFor(
                    width: btnWidth,
                    height: btnHeight,
                  );
                  actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: handleDelete,
                        constraints: btnConstraints,
                        padding: EdgeInsets.zero,
                        iconSize: iconSize,
                        visualDensity: VisualDensity.compact,
                        color: Theme.of(context).colorScheme.error,
                        icon: const Icon(Icons.delete_outline),
                      ),
                      IconButton(
                        onPressed: () => _cancelInlineCategoryEdit(save: false),
                        constraints: btnConstraints,
                        padding: EdgeInsets.zero,
                        iconSize: iconSize,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close),
                      ),
                      IconButton(
                        onPressed: _saveInlineCategoryEdit,
                        constraints: btnConstraints,
                        padding: EdgeInsets.zero,
                        iconSize: iconSize,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.check),
                      ),
                    ],
                  );
                } else {
                  actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: handleDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => _cancelInlineCategoryEdit(save: false),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: _saveInlineCategoryEdit,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('保存'),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '编辑：$editingName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    actions,
                  ],
                );
              },
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : shortcuts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        searchActive
                            ? '没有匹配的应用'
                            : isFiltering
                            ? '该分类暂无应用'
                            : '未找到桌面快捷方式',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      if (!isFiltering && !searchActive) ...[
                        const SizedBox(height: 8),
                        Text(
                          '桌面路径: $_desktopPath',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = _calculateLayoutMetrics(scale);

                    final crossAxisCount =
                        ((metrics.horizontalPadding * 2 +
                                    constraints.maxWidth -
                                    metrics.horizontalPadding * 2 +
                                    metrics.mainAxisSpacing) /
                                (120.0 + metrics.mainAxisSpacing))
                            .ceil();

                    final effectiveCrossAxisCount = math.max(1, crossAxisCount);

                    if (_gridCrossAxisCount != effectiveCrossAxisCount) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _setState(
                            () => _gridCrossAxisCount = effectiveCrossAxisCount,
                          );
                        }
                      });
                    }

                    return RepaintBoundary(
                      child: GridView.builder(
                        controller: _gridScrollController,
                        padding: EdgeInsets.fromLTRB(
                          metrics.horizontalPadding / 2,
                          0,
                          metrics.horizontalPadding / 2,
                          metrics.horizontalPadding / 2,
                        ),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 120.0,
                          crossAxisSpacing: metrics.mainAxisSpacing,
                          mainAxisSpacing: metrics.mainAxisSpacing,
                          childAspectRatio: metrics.cardHeight > 0
                              ? (120.0 / metrics.cardHeight)
                              : 1.0,
                        ),
                        itemCount: shortcuts.length,
                        itemBuilder: (context, index) {
                          final shortcut = shortcuts[index];
                          if (editingCategory) {
                            return SelectableShortcutTile(
                              shortcut: shortcut,
                              iconSize: _iconSize,
                              scale: scale,
                              selected: _editingSelection.contains(
                                shortcut.path,
                              ),
                              onTap: () => _toggleInlineSelection(shortcut),
                              beautifyIcon: _beautifyAppIcons,
                              beautifyStyle: _beautifyStyle,
                            );
                          }
                          return ShortcutCard(
                            shortcut: shortcut,
                            iconSize: _iconSize,
                            windowFocusNotifier: _windowFocusNotifier,
                            isHighlighted: index == _searchSelectedIndex,
                            onOpenRequested: _openShortcutFromHome,
                            onDeleted: () {
                              _loadShortcuts(showLoading: false);
                            },
                            onCategoryMenuRequested:
                                _showCategoryMenuForShortcut,
                            beautifyIcon: _beautifyAppIcons,
                            beautifyStyle: _beautifyStyle,
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  double _estimateTextHeight() {
    final size = (_iconSize * 0.34).clamp(10, 18);
    // allow up to 2 lines with some spacing
    return size * 2.9 + 6;
  }
}
