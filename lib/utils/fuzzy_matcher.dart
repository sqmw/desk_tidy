/// 模糊搜索匹配器
///
/// 提供多种匹配策略，按优先级和相关性评分排序搜索结果。
/// 支持：精确匹配、前缀匹配、分词前缀、子字符串、模糊顺序、拼音、驼峰。
library;

import 'app_search_index.dart';

/// 匹配类型枚举（按优先级排序）
enum MatchType {
  /// 完全匹配 - 100分
  exact(100),

  /// 前缀匹配 - 90分
  prefix(90),

  /// 分词前缀匹配 - 80分
  tokenPrefix(80),

  /// 子字符串匹配 - 70分
  contains(70),

  /// 驼峰首字母匹配 - 65分
  camelCase(65),

  /// 拼音全拼匹配 - 60分
  pinyin(60),

  /// 中文转拼音匹配 - 58分
  chinesePinyin(58),

  /// 拼音首字母匹配 - 55分
  pinyinInitials(55),

  /// 模糊顺序匹配 - 50分
  fuzzy(50),

  /// 子序列匹配（允许跳跃但不要求从头开始）- 40分
  subsequence(40),

  /// 部分匹配（查询子串匹配）- 35分
  partialMatch(35),

  /// 不匹配 - 0分
  none(0);

  const MatchType(this.baseScore);

  /// 基础分数
  final int baseScore;
}

/// 匹配结果
class MatchResult {
  const MatchResult({
    required this.matched,
    required this.score,
    required this.type,
    this.matchedIndices = const [],
  });

  /// 无匹配结果
  static const none = MatchResult(
    matched: false,
    score: 0,
    type: MatchType.none,
  );

  /// 是否匹配
  final bool matched;

  /// 匹配分数（用于排序，越高越好）
  final int score;

  /// 匹配类型
  final MatchType type;

  /// 匹配字符的索引位置（用于高亮显示）
  final List<int> matchedIndices;

  @override
  String toString() => 'MatchResult($type, score=$score, matched=$matched)';
}

/// 模糊匹配器
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

  // ==================== 私有匹配方法 ====================

  /// 精确匹配
  static MatchResult? _tryExact(String query, AppSearchIndex index) {
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
  static MatchResult? _tryPrefix(String query, AppSearchIndex index) {
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
  static MatchResult? _tryTokenPrefix(String query, AppSearchIndex index) {
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
  static MatchResult? _tryContains(String query, AppSearchIndex index) {
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
  static MatchResult? _tryCamelCase(String query, AppSearchIndex index) {
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
  static MatchResult? _tryPinyin(String query, AppSearchIndex index) {
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
  static MatchResult? _tryPinyinInitials(String query, AppSearchIndex index) {
    // 主拼音首字母
    if (index.pinyinInitials.isNotEmpty &&
        index.pinyinInitials.contains(query)) {
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
  static MatchResult? _tryFuzzy(String query, AppSearchIndex index) {
    final indices = _fuzzyMatchIndices(query, index.normalizedName);
    if (indices != null) {
      // 计算匹配质量：连续字符越多，分数越高
      final continuityBonus = _calculateContinuityBonus(indices);
      // 计算紧凑度：匹配范围越小，分数越高
      final compactnessBonus = _calculateCompactnessBonus(
        indices,
        query.length,
      );

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
  static List<int>? _fuzzyMatchIndices(String query, String text) {
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
  static String _extractCamelCaseInitials(String name) {
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
  static List<int> _findCamelCaseIndices(String query, String source) {
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
  static List<int> _findIndicesInSource(
    String query,
    String token,
    String source,
  ) {
    final lowerSource = source.toLowerCase();
    final lowerToken = token.toLowerCase();
    final tokenStart = lowerSource.indexOf(lowerToken);
    if (tokenStart < 0) return [];

    return List.generate(query.length, (i) => tokenStart + i);
  }

  /// 计算连续性加分
  static int _calculateContinuityBonus(List<int> indices) {
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
  static int _calculateCompactnessBonus(List<int> indices, int queryLength) {
    if (indices.isEmpty) return 0;

    final span = indices.last - indices.first + 1;
    final ratio = queryLength / span;

    return (ratio * 5).round().clamp(0, 5);
  }

  /// 子序列匹配（字符按顺序出现，可以在任何位置开始）
  /// 与 _tryFuzzy 的区别：fuzzy 已经在 normalizedName 和 pinyin 上尝试过了，
  /// subsequence 会尝试在 normalizedName 的任意子串中匹配。
  /// 例如：'abao' 可以匹配 'doubao'（跳过 'dou'，匹配 'ubao' 中的 'a' 后匹配 'bao'）
  static MatchResult? _trySubsequence(String query, AppSearchIndex index) {
    // 在 normalizedName 中尝试子序列匹配
    final indices = _subsequenceMatchIndices(query, index.normalizedName);
    if (indices != null) {
      final continuityBonus = _calculateContinuityBonus(indices);
      final compactnessBonus = _calculateCompactnessBonus(
        indices,
        query.length,
      );
      // 位置越靠前分数越高
      final positionBonus = indices.isEmpty
          ? 0
          : (5 - (indices.first / index.normalizedName.length * 5))
                .round()
                .clamp(0, 5);

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
  static List<int>? _subsequenceMatchIndices(String query, String text) {
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
  static MatchResult? _tryPartialMatch(String query, AppSearchIndex index) {
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
  static MatchResult? _tryChineseToPinyin(String query, AppSearchIndex index) {
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
}
