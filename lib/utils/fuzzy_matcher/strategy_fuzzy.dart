part of '../fuzzy_matcher.dart';

MatchResult? _tryFuzzy(String query, AppSearchIndex index) {
  final indices = _fuzzyMatchIndices(query, index.normalizedName);
  if (indices != null) {
    // 计算匹配质量：连续字符越多，分数越高
    final continuityBonus = _calculateContinuityBonus(indices);
    // 计算紧凑度：匹配范围越小，分数越高
    final compactnessBonus = _calculateCompactnessBonus(indices, query.length);

    return MatchResult(
      matched: true,
      score: MatchType.fuzzy.baseScore + continuityBonus + compactnessBonus,
      type: MatchType.fuzzy,
      matchedIndices: indices,
    );
  }

  // 也尝试在拼音中进行模糊匹配
  if (index.pinyin.isNotEmpty) {
    final pinyinIndices = _fuzzyMatchIndices(query, index.pinyin);
    if (pinyinIndices != null) {
      return MatchResult(
        matched: true,
        score: MatchType.fuzzy.baseScore,
        type: MatchType.fuzzy,
      );
    }
  }

  return null;
}

// ==================== 辅助方法 ====================

/// 模糊匹配：检查 query 中的字符是否按顺序出现在 text 中
List<int>? _fuzzyMatchIndices(String query, String text) {
  final indices = <int>[];
  var textIdx = 0;

  for (var i = 0; i < query.length; i++) {
    final char = query[i];
    var found = false;

    while (textIdx < text.length) {
      if (text[textIdx] == char) {
        indices.add(textIdx);
        textIdx++;
        found = true;
        break;
      }
      textIdx++;
    }

    if (!found) return null;
  }

  return indices;
}

/// 提取驼峰命名的首字母（如 DeskTidy -> DT）
String _extractCamelCaseInitials(String name) {
  final buffer = StringBuffer();
  var prevWasLower = false;

  for (var i = 0; i < name.length; i++) {
    final char = name[i];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    final isLetter =
        (char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90) ||
        (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 122);

    if (i == 0 && isLetter) {
      buffer.write(char.toUpperCase());
    } else if (isUpper && prevWasLower) {
      buffer.write(char);
    }

    prevWasLower = isLetter && !isUpper;
  }

  return buffer.toString();
}

/// 找到驼峰首字母在原始字符串中的索引
List<int> _findCamelCaseIndices(String query, String source) {
  final indices = <int>[];
  var queryIdx = 0;
  var prevWasLower = false;

  for (var i = 0; i < source.length && queryIdx < query.length; i++) {
    final char = source[i];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    final isLetter =
        (char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90) ||
        (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 122);

    final isInitial = (i == 0 && isLetter) || (isUpper && prevWasLower);

    if (isInitial && char.toLowerCase() == query[queryIdx].toLowerCase()) {
      indices.add(i);
      queryIdx++;
    }

    prevWasLower = isLetter && !isUpper;
  }

  return indices;
}

/// 在源字符串中找到匹配的索引位置
List<int> _findIndicesInSource(String query, String token, String source) {
  final lowerSource = source.toLowerCase();
  final lowerToken = token.toLowerCase();
  final tokenStart = lowerSource.indexOf(lowerToken);
  if (tokenStart < 0) return [];

  return List.generate(query.length, (i) => tokenStart + i);
}

/// 计算连续性加分
int _calculateContinuityBonus(List<int> indices) {
  if (indices.length < 2) return 0;

  var consecutiveCount = 0;
  for (var i = 1; i < indices.length; i++) {
    if (indices[i] == indices[i - 1] + 1) {
      consecutiveCount++;
    }
  }

  return (consecutiveCount * 2).clamp(0, 10);
}

/// 计算紧凑度加分
int _calculateCompactnessBonus(List<int> indices, int queryLength) {
  if (indices.isEmpty) return 0;

  final span = indices.last - indices.first + 1;
  final ratio = queryLength / span;

  return (ratio * 5).round().clamp(0, 5);
}

/// 子序列匹配（字符按顺序出现，可以在任何位置开始）
/// 与 _tryFuzzy 的区别：fuzzy 已经在 normalizedName 和 pinyin 上尝试过了，
/// subsequence 会尝试在 normalizedName 的任意子串中匹配。
/// 例如：'abao' 可以匹配 'doubao'（跳过 'dou'，匹配 'ubao' 中的 'a' 后匹配 'bao'）
