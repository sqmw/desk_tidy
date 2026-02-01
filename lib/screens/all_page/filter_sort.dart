part of '../all_page.dart';

extension _AllPageFilterAndSort on _AllPageState {
  List<FileItem> get _filteredItems {
    List<FileItem> list;
    switch (_filterMode) {
      case _EntityFilterMode.folders:
        list = _items
            .where((e) => e.isDirectory && !e.name.startsWith('.'))
            .toList();
        break;
      case _EntityFilterMode.files:
        list = _items.where((e) {
          if (e.isDirectory) return false;
          final lower = e.name.toLowerCase();
          if (lower == 'desktop.ini' || lower == 'thumbs.db') return false;
          if (lower.endsWith('.lnk') || lower.endsWith('.exe')) return false;
          return true;
        }).toList();
        break;
      case _EntityFilterMode.all:
        list = List.of(_items);
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final scored = <MapEntry<FileItem, int>>[];
      for (final item in list) {
        final result = item.searchIndex.matchWithScore(_searchQuery);
        if (result.matched) {
          scored.add(MapEntry(item, result.score));
        }
      }
      scored.sort((a, b) => b.value.compareTo(a.value));
      return scored.map((e) => e.key).toList();
    }

    list.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int cmp = 0;
      switch (_sortType) {
        case _SortType.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case _SortType.date:
          cmp = a.modified.compareTo(b.modified);
          break;
        case _SortType.size:
          cmp = a.size.compareTo(b.size);
          break;
        case _SortType.type:
          cmp = a.extension.compareTo(b.extension);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return list;
  }

  String _getSortLabel(_SortType type) {
    String label;
    switch (type) {
      case _SortType.name:
        label = '名称';
        break;
      case _SortType.date:
        label = '修改时间';
        break;
      case _SortType.size:
        label = '大小';
        break;
      case _SortType.type:
        label = '类型';
        break;
    }
    return '$label ${_sortAscending ? "↑" : "↓"}';
  }

  Widget _buildSortItem(String label, _SortType type) {
    final isSelected = _sortType == type;
    return Row(
      children: [
        Expanded(child: Text(label)),
        if (isSelected)
          Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }
}
