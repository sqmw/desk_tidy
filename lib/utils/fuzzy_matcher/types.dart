part of '../fuzzy_matcher.dart';

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
