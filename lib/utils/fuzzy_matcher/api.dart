part of '../fuzzy_matcher.dart';

class FuzzyMatcher {
  FuzzyMatcher._();

  /// 执行匹配，返回最佳匹配结果
  ///
  /// [query] 用户输入的搜索词（会自动规范化）
  /// [index] 预构建的搜索索引
  static MatchResult match(String query, AppSearchIndex index) {
    final normalizedQuery = normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return const MatchResult(
        matched: true,
        score: 100,
        type: MatchType.exact,
      );
    }

    // 按优先级尝试各种匹配
    MatchResult? result;

    // 1. 精确匹配
    result = _tryExact(normalizedQuery, index);
    if (result != null) return result;

    // 2. 前缀匹配
    result = _tryPrefix(normalizedQuery, index);
    if (result != null) return result;

    // 3. 分词前缀匹配
    result = _tryTokenPrefix(normalizedQuery, index);
    if (result != null) return result;

    // 4. 子字符串匹配
    result = _tryContains(normalizedQuery, index);
    if (result != null) return result;

    // 5. 驼峰首字母匹配
    result = _tryCamelCase(normalizedQuery, index);
    if (result != null) return result;

    // 6. 拼音全拼匹配
    result = _tryPinyin(normalizedQuery, index);
    if (result != null) return result;

    // 6.5. 中文转拼音匹配 (输入中文匹配英文/拼音)
    result = _tryChineseToPinyin(normalizedQuery, index);
    if (result != null) return result;

    // 7. 拼音首字母匹配
    result = _tryPinyinInitials(normalizedQuery, index);
    if (result != null) return result;

    // 8. 模糊顺序匹配（最后尝试，性能消耗较大）
    result = _tryFuzzy(normalizedQuery, index);
    if (result != null) return result;

    // 9. 子序列匹配（最宽松的匹配，允许字符在任意位置按顺序出现）
    result = _trySubsequence(normalizedQuery, index);
    if (result != null) return result;

    // 10. 部分匹配：尝试查询的子串进行匹配（如 "abao" 通过 "bao" 匹配）
    result = _tryPartialMatch(normalizedQuery, index);
    if (result != null) return result;

    return MatchResult.none;
  }

  /// 批量过滤并按匹配分数排序
  ///
  /// [query] 搜索词
  /// [items] 待过滤的项目列表
  /// [indexer] 从项目获取搜索索引的函数
  static List<T> filter<T>(
    String query,
    List<T> items,
    AppSearchIndex Function(T) indexer,
  ) {
    final normalizedQuery = normalizeSearchText(query);
    if (normalizedQuery.isEmpty) return items;

    final scored = <(T, MatchResult, int)>[]; // (item, result, nameLength)
    for (final item in items) {
      final index = indexer(item);
      final result = match(query, index);
      if (result.matched) {
        scored.add((item, result, index.sourceName.length));
      }
    }

    // 按分数降序排列；分数相同时按名称长度升序（更短的名称更精确）
    scored.sort((a, b) {
      final scoreCompare = b.$2.score.compareTo(a.$2.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.$3.compareTo(b.$3); // 名称长度升序
    });

    return scored.map((e) => e.$1).toList();
  }

  /// 批量过滤并返回匹配结果（用于高亮显示）
  static List<(T, MatchResult)> filterWithResult<T>(
    String query,
    List<T> items,
    AppSearchIndex Function(T) indexer,
  ) {
    final normalizedQuery = normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return items
          .map(
            (e) => (
              e,
              const MatchResult(
                matched: true,
                score: 100,
                type: MatchType.exact,
              ),
            ),
          )
          .toList();
    }

    final scored = <(T, MatchResult, int)>[]; // (item, result, nameLength)
    for (final item in items) {
      final index = indexer(item);
      final result = match(query, index);
      if (result.matched) {
        scored.add((item, result, index.sourceName.length));
      }
    }

    // 按分数降序排列；分数相同时按名称长度升序（更短的名称更精确）
    scored.sort((a, b) {
      final scoreCompare = b.$2.score.compareTo(a.$2.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.$3.compareTo(b.$3); // 名称长度升序
    });
    return scored.map((e) => (e.$1, e.$2)).toList();
  }
}
