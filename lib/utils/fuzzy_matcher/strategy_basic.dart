part of '../fuzzy_matcher.dart';

MatchResult? _tryExact(String query, AppSearchIndex index) {
  if (index.normalizedName == query) {
    return MatchResult(
      matched: true,
      score: MatchType.exact.baseScore,
      type: MatchType.exact,
      matchedIndices: List.generate(query.length, (i) => i),
    );
  }
  return null;
}

/// 前缀匹配
MatchResult? _tryPrefix(String query, AppSearchIndex index) {
  if (index.normalizedName.startsWith(query)) {
    // 前缀匹配：查询越接近完整名称，分数越高
    final ratio = query.length / index.normalizedName.length;
    final bonus = (ratio * 10).round();
    return MatchResult(
      matched: true,
      score: MatchType.prefix.baseScore + bonus,
      type: MatchType.prefix,
      matchedIndices: List.generate(query.length, (i) => i),
    );
  }
  return null;
}

/// 分词前缀匹配
MatchResult? _tryTokenPrefix(String query, AppSearchIndex index) {
  for (var i = 0; i < index.tokens.length; i++) {
    final token = index.tokens[i];
    if (token.startsWith(query)) {
      // 分词匹配：第一个分词得分更高
      final positionBonus = i == 0 ? 5 : 0;
      final ratio = query.length / token.length;
      final bonus = (ratio * 5).round() + positionBonus;
      return MatchResult(
        matched: true,
        score: MatchType.tokenPrefix.baseScore + bonus,
        type: MatchType.tokenPrefix,
        matchedIndices: _findIndicesInSource(query, token, index.sourceName),
      );
    }
  }
  return null;
}

/// 子字符串匹配
MatchResult? _tryContains(String query, AppSearchIndex index) {
  final pos = index.normalizedName.indexOf(query);
  if (pos >= 0) {
    // 子字符串匹配：位置越靠前，分数越高
    final positionBonus = pos == 0 ? 10 : (10 - pos).clamp(0, 8);
    return MatchResult(
      matched: true,
      score: MatchType.contains.baseScore + positionBonus,
      type: MatchType.contains,
      matchedIndices: List.generate(query.length, (i) => pos + i),
    );
  }
  return null;
}

/// 驼峰首字母匹配
MatchResult? _tryCamelCase(String query, AppSearchIndex index) {
  final initials = _extractCamelCaseInitials(index.sourceName);
  if (initials.isEmpty) return null;

  final lowerInitials = initials.toLowerCase();
  final lowerQuery = query.toLowerCase();

  if (lowerInitials.startsWith(lowerQuery)) {
    final ratio = query.length / initials.length;
    final bonus = (ratio * 10).round();
    return MatchResult(
      matched: true,
      score: MatchType.camelCase.baseScore + bonus,
      type: MatchType.camelCase,
      matchedIndices: _findCamelCaseIndices(query, index.sourceName),
    );
  }

  if (lowerInitials.contains(lowerQuery)) {
    return MatchResult(
      matched: true,
      score: MatchType.camelCase.baseScore,
      type: MatchType.camelCase,
      matchedIndices: _findCamelCaseIndices(query, index.sourceName),
    );
  }

  return null;
}

/// 拼音全拼匹配
