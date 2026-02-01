/// 模糊搜索匹配器
///
/// 提供多种匹配策略，按优先级和相关性评分排序搜索结果。
/// 支持：精确匹配、前缀匹配、分词前缀、子字符串、模糊顺序、拼音、驼峰。
library;

import 'app_search_index.dart';

/// 匹配类型枚举（按优先级排序）

part 'fuzzy_matcher/types.dart';
part 'fuzzy_matcher/api.dart';
part 'fuzzy_matcher/strategy_basic.dart';
part 'fuzzy_matcher/strategy_pinyin.dart';
part 'fuzzy_matcher/strategy_fuzzy.dart';
part 'fuzzy_matcher/strategy_subsequence.dart';
