part of '../fuzzy_matcher.dart';

MatchResult? _tryPinyin(String query, AppSearchIndex index) {
  // 主拼音匹配
  if (index.pinyin.isNotEmpty && index.pinyin.contains(query)) {
    final isPrefix = index.pinyin.startsWith(query);
    final bonus = isPrefix ? 5 : 0;
    return MatchResult(
      matched: true,
      score: MatchType.pinyin.baseScore + bonus,
      type: MatchType.pinyin,
    );
  }

  // 分词拼音匹配
  for (final tokenPinyin in index.tokenPinyins) {
    if (tokenPinyin.contains(query)) {
      final isPrefix = tokenPinyin.startsWith(query);
      final bonus = isPrefix ? 3 : 0;
      return MatchResult(
        matched: true,
        score: MatchType.pinyin.baseScore + bonus,
        type: MatchType.pinyin,
      );
    }
  }

  return null;
}

/// 拼音首字母匹配
MatchResult? _tryPinyinInitials(String query, AppSearchIndex index) {
  // 主拼音首字母
  if (index.pinyinInitials.isNotEmpty && index.pinyinInitials.contains(query)) {
    final isPrefix = index.pinyinInitials.startsWith(query);
    final bonus = isPrefix ? 5 : 0;
    return MatchResult(
      matched: true,
      score: MatchType.pinyinInitials.baseScore + bonus,
      type: MatchType.pinyinInitials,
    );
  }

  // 拉丁首字母
  if (index.latinInitials.isNotEmpty && index.latinInitials.contains(query)) {
    final isPrefix = index.latinInitials.startsWith(query);
    final bonus = isPrefix ? 5 : 0;
    return MatchResult(
      matched: true,
      score: MatchType.pinyinInitials.baseScore + bonus,
      type: MatchType.pinyinInitials,
    );
  }

  // 分词拼音首字母
  for (final tokenInitials in index.tokenPinyinInitials) {
    if (tokenInitials.contains(query)) {
      final isPrefix = tokenInitials.startsWith(query);
      final bonus = isPrefix ? 3 : 0;
      return MatchResult(
        matched: true,
        score: MatchType.pinyinInitials.baseScore + bonus,
        type: MatchType.pinyinInitials,
      );
    }
  }

  return null;
}

/// 模糊顺序匹配（字符按顺序出现）
