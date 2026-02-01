# `fuzzy_matcher` 拆分说明（2026-02-01）

## 拆分前的问题
- `lib/utils/fuzzy_matcher.dart` 单文件 ~800 行，包含：
  - 匹配类型/结果结构定义
  - `FuzzyMatcher` 对外 API
  - 多套匹配策略与辅助算法（exact/prefix/token/camelCase/pinyin/fuzzy/subsequence/partial 等）

## 拆分后的结构
入口文件（对外 import 不变）：
- `lib/utils/fuzzy_matcher.dart`

实现文件（按职责拆分）：
- `lib/utils/fuzzy_matcher/types.dart`：`MatchType`、`MatchResult`
- `lib/utils/fuzzy_matcher/api.dart`：`FuzzyMatcher` 对外 API（`match/filter/filterWithResult`）
- `lib/utils/fuzzy_matcher/strategy_basic.dart`：exact/prefix/token/contains/camelCase
- `lib/utils/fuzzy_matcher/strategy_pinyin.dart`：pinyin / initials
- `lib/utils/fuzzy_matcher/strategy_fuzzy.dart`：fuzzy + 评分/索引辅助
- `lib/utils/fuzzy_matcher/strategy_subsequence.dart`：subsequence/partial/chinese->pinyin

## 关键点
- 保留 `FuzzyMatcher.xxx` 的外部调用方式不变，仅把内部策略拆成顶层私有函数，提升可维护性与可测试性。

