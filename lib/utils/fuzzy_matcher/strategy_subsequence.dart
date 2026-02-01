part of '../fuzzy_matcher.dart';

MatchResult? _trySubsequence(String query, AppSearchIndex index) {
  // 在 normalizedName 中尝试子序列匹配
  final indices = _subsequenceMatchIndices(query, index.normalizedName);
  if (indices != null) {
    final continuityBonus = _calculateContinuityBonus(indices);
    final compactnessBonus = _calculateCompactnessBonus(indices, query.length);
    // 位置越靠前分数越高
    final positionBonus = indices.isEmpty
        ? 0
        : (5 - (indices.first / index.normalizedName.length * 5)).round().clamp(
            0,
            5,
          );

    return MatchResult(
      matched: true,
      score:
          MatchType.subsequence.baseScore +
          continuityBonus +
          compactnessBonus +
          positionBonus,
      type: MatchType.subsequence,
      matchedIndices: indices,
    );
  }

  // 也在拼音中尝试
  if (index.pinyin.isNotEmpty) {
    final pinyinIndices = _subsequenceMatchIndices(query, index.pinyin);
    if (pinyinIndices != null) {
      return MatchResult(
        matched: true,
        score: MatchType.subsequence.baseScore,
        type: MatchType.subsequence,
      );
    }
  }

  return null;
}

/// 子序列匹配：检查 query 中的字符是否按顺序出现在 text 中的任意位置
/// 与 _fuzzyMatchIndices 的区别：使用最优匹配策略，寻找最紧凑的匹配
List<int>? _subsequenceMatchIndices(String query, String text) {
  if (query.isEmpty) return [];
  if (text.isEmpty) return null;

  // 找到第一个字符的所有可能位置
  final firstChar = query[0];
  List<int>? bestIndices;

  for (var startPos = 0; startPos < text.length; startPos++) {
    if (text[startPos] != firstChar) continue;

    // 从这个位置开始尝试匹配
    final indices = <int>[startPos];
    var textIdx = startPos + 1;
    var matched = true;

    for (var i = 1; i < query.length; i++) {
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

      if (!found) {
        matched = false;
        break;
      }
    }

    if (matched) {
      // 选择最紧凑的匹配（跨度最小）
      if (bestIndices == null ||
          (indices.last - indices.first) <
              (bestIndices.last - bestIndices.first)) {
        bestIndices = indices;
      }
    }
  }

  return bestIndices;
}

/// 部分匹配：尝试查询的子串进行匹配
/// 例如 "abao" 可以通过 "bao" 匹配到 "doubao"
MatchResult? _tryPartialMatch(String query, AppSearchIndex index) {
  if (query.length < 2) return null;

  // 尝试查询的后缀（从第二个字符开始）
  for (var start = 1; start < query.length; start++) {
    final suffix = query.substring(start);
    if (suffix.length < 2) break; // 子串太短，没有意义

    // 尝试子字符串匹配
    final pos = index.normalizedName.indexOf(suffix);
    if (pos >= 0) {
      // 匹配分数基于子串长度占原查询的比例
      final ratio = suffix.length / query.length;
      final bonus = (ratio * 10).round();
      return MatchResult(
        matched: true,
        score: MatchType.partialMatch.baseScore + bonus,
        type: MatchType.partialMatch,
        matchedIndices: List.generate(suffix.length, (i) => pos + i),
      );
    }

    // 尝试在拼音中匹配
    if (index.pinyin.isNotEmpty) {
      final pinyinPos = index.pinyin.indexOf(suffix);
      if (pinyinPos >= 0) {
        final ratio = suffix.length / query.length;
        final bonus = (ratio * 8).round();
        return MatchResult(
          matched: true,
          score: MatchType.partialMatch.baseScore + bonus,
          type: MatchType.partialMatch,
        );
      }
    }
  }

  return null;
}

/// 中文转拼音匹配
/// 将搜索词转换为拼音后尝试匹配
MatchResult? _tryChineseToPinyin(String query, AppSearchIndex index) {
  if (query.isEmpty) return null;

  // 如果查询词不包含中文，不需要尝试此转换
  if (!RegExp(r'[\u4e00-\u9fff]').hasMatch(query)) return null;

  final queryPinyin = normalizeSearchText(safePinyin(query));
  if (queryPinyin.isEmpty) return null;

  // 1. 正向匹配：目标包含查询拼音 (Target contains Query)
  // 场景：搜"豆包"(doubao) -> 匹配"Doubao"
  if (index.normalizedName.contains(queryPinyin)) {
    final ratio = queryPinyin.length / index.normalizedName.length;
    final bonus = (ratio * 15).round(); // Max 15
    return MatchResult(
      matched: true,
      score: MatchType.chinesePinyin.baseScore + bonus,
      type: MatchType.chinesePinyin,
    );
  }

  // 2. 反向匹配：查询拼音包含目标名称 (Query contains Target)
  // 场景：搜"a抖音"(adouyin) -> 匹配"Douyin" (在后)
  // 场景：搜"抖音"(douyin) -> 匹配"Douyin" (全匹配)
  final pos = queryPinyin.indexOf(index.normalizedName);
  if (pos >= 0) {
    // 长度比重：占用查询词长度越多，分数越高
    final lenRatio = index.normalizedName.length / queryPinyin.length;
    final lenBonus = (lenRatio * 20).round(); // Max 20

    // 位置比重：越靠前分数越高
    // pos=0 -> penalty=0. pos=end -> penalty=5
    final posPenalty = (pos / queryPinyin.length * 5).round();

    return MatchResult(
      matched: true,
      score: MatchType.chinesePinyin.baseScore + lenBonus - posPenalty,
      type: MatchType.chinesePinyin,
    );
  }

  // 3. 拼音字段匹配 (Fallback)
  if (index.pinyin.contains(queryPinyin)) {
    return MatchResult(
      matched: true,
      score: MatchType.chinesePinyin.baseScore,
      type: MatchType.chinesePinyin,
    );
  }

  if (index.pinyin.isNotEmpty && queryPinyin.contains(index.pinyin)) {
    final lenRatio = index.pinyin.length / queryPinyin.length;
    final lenBonus = (lenRatio * 20).round();
    return MatchResult(
      matched: true,
      score: MatchType.chinesePinyin.baseScore + lenBonus,
      type: MatchType.chinesePinyin,
    );
  }

  // 4. Token 匹配 (解决后缀问题，如 "Doubao - 快捷方式")
  // 检查是否有任何 token (或其拼音) 被查询拼音包含
  // 遍历 normalized tokens ("doubao", "快捷方式")
  for (final token in index.tokens) {
    if (token.isEmpty) continue;
    // 英文Token直接比较: "adoubao" contains "doubao"
    // 注意：这里 token 是原词的 normalized 形式。
    if (queryPinyin.contains(token)) {
      final pos = queryPinyin.indexOf(token);
      final lenRatio = token.length / queryPinyin.length;
      final lenBonus = (lenRatio * 20).round();
      final posPenalty = (pos / queryPinyin.length * 5).round();

      return MatchResult(
        matched: true,
        score: MatchType.chinesePinyin.baseScore + lenBonus - posPenalty,
        type: MatchType.chinesePinyin,
      );
    }
  }

  // 遍历 token pinyins ("kuaijiefangshi")
  for (final tokenPinyin in index.tokenPinyins) {
    if (queryPinyin.contains(tokenPinyin)) {
      final pos = queryPinyin.indexOf(tokenPinyin);
      final lenRatio = tokenPinyin.length / queryPinyin.length;
      final lenBonus = (lenRatio * 20).round();
      final posPenalty = (pos / queryPinyin.length * 5).round();

      return MatchResult(
        matched: true,
        score: MatchType.chinesePinyin.baseScore + lenBonus - posPenalty,
        type: MatchType.chinesePinyin,
      );
    }
    // 反向：TokenPinyin 包含 QueryPinyin (搜 "快捷" -> 匹配 "快捷方式")
    if (tokenPinyin.contains(queryPinyin)) {
      final ratio = queryPinyin.length / tokenPinyin.length;
      final bonus = (ratio * 15).round();
      return MatchResult(
        matched: true,
        score: MatchType.chinesePinyin.baseScore + bonus,
        type: MatchType.chinesePinyin,
      );
    }
  }

  return null;
}
