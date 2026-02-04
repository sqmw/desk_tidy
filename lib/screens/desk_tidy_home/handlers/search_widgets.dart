part of '../../desk_tidy_home_page.dart';

extension _DeskTidyHomeSearchWidgets on _DeskTidyHomePageState {
  Widget _buildSearchBar(double scale) {
    final theme = Theme.of(context);
    final hasQuery = _appSearchQuery.trim().isNotEmpty;
    final iconSize = (18 * scale).clamp(16.0, 22.0);
    // 移除边框，改用背景色区分
    // 聚焦时稍微增加背景不透明度，而不是加边框
    final opacity = (_toolbarPanelOpacity + (_searchHasFocus ? 0.12 : 0.05))
        .clamp(0.0, 1.0);

    final iconColor = _searchHasFocus
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.72);

    return GlassContainer(
      borderRadius: BorderRadius.circular(14),
      opacity: opacity,
      blurSigma: _toolbarPanelBlur,
      // border: null, // 移除边框
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: iconSize, color: iconColor),
          SizedBox(width: 6 * scale),
          Expanded(
            child: Focus(
              onKeyEvent: _handleSearchNavigation,
              child: TextField(
                controller: _appSearchController,
                focusNode: _appSearchFocus,
                onChanged: _updateSearchQuery,
                // onSubmitted 已不再需要，因为 Enter 键已在 _handleSearchNavigation 中处理
                autocorrect: false,
                enableSuggestions: false,
                maxLines: 1,
                textInputAction: TextInputAction.search,
                cursorColor: theme.colorScheme.primary,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '搜索应用（支持拼音前缀）',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          if (hasQuery)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: 28 * scale,
                height: 28 * scale,
              ),
              iconSize: iconSize,
              onPressed: () => _clearSearch(keepFocus: true),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchCountChip(
    double scale, {
    required int matchCount,
    required int totalCount,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        '匹配 $matchCount/$totalCount',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
