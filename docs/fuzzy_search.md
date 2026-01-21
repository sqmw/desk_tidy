# 模糊搜索系统

## 概述

DeskTidy 使用自定义的模糊搜索系统，支持多种匹配方式并按相关性排序结果。

## 核心组件

### FuzzyMatcher (`lib/utils/fuzzy_matcher.dart`)

模糊匹配器，提供多种匹配策略：

```dart
// 单个匹配
MatchResult result = FuzzyMatcher.match(query, searchIndex);

// 批量过滤并排序
List<T> filtered = FuzzyMatcher.filter(query, items, indexer);

// 带匹配结果的过滤（用于高亮）
List<(T, MatchResult)> results = FuzzyMatcher.filterWithResult(...);
```

### AppSearchIndex (`lib/utils/app_search_index.dart`)

预构建的搜索索引，包含：
- `normalizedName` - 规范化名称（小写，去除特殊字符）
- `tokens` - 分词列表
- `pinyin` - 拼音全拼
- `pinyinInitials` - 拼音首字母
- `latinInitials` - 英文首字母

---

## 匹配类型

按优先级从高到低排列：

| 类型 | 分数 | 说明 | 示例 |
|------|------|------|------|
| `exact` | 100 | 完全匹配 | "doubao" → "doubao" |
| `prefix` | 90 | 前缀匹配 | "dou" → "doubao" |
| `tokenPrefix` | 80 | 分词前缀匹配 | "exe" → "doubao.exe" |
| `contains` | 70 | 子字符串匹配 | "bao" → "doubao" |
| `camelCase` | 65 | 驼峰首字母匹配 | "DT" → "DeskTidy" |
| `pinyin` | 60 | 拼音全拼匹配 | "doubao" → "豆包" |
| `pinyinInitials` | 55 | 拼音首字母匹配 | "db" → "豆包" |
| `fuzzy` | 50 | 模糊顺序匹配 | "dbe" → "doubao.exe" |
| `subsequence` | 40 | 子序列匹配 | "dao" → "doubao" |
| `partialMatch` | 35 | 部分匹配（查询子串） | "abao" → "doubao" |

---

## 评分算法

基础分数由匹配类型决定，还会根据以下因素加分：

### 位置加分
- 匹配位置越靠前，分数越高
- 第一个分词匹配额外 +5 分

### 连续性加分
- 模糊匹配时，连续字符越多分数越高
- 每对相邻匹配 +2 分（最多 +10）

### 紧凑度加分
- 匹配范围越小，分数越高
- 基于 `queryLength / matchSpan` 计算

---

## 使用示例

### 基本搜索

```dart
final index = AppSearchIndex.fromName("Doubao.exe");
final result = FuzzyMatcher.match("bao", index);

if (result.matched) {
  print("匹配类型: ${result.type}");  // contains
  print("分数: ${result.score}");      // 约 78
  print("高亮位置: ${result.matchedIndices}");  // [3, 4, 5]
}
```

### 列表过滤

```dart
final shortcuts = [...];
final filtered = FuzzyMatcher.filter<ShortcutItem>(
  "bao",
  shortcuts,
  (item) => AppSearchIndex.fromName(item.name),
);
// 返回按相关性排序的结果
```

---

## 修改历史

| 日期 | 变更 |
|------|------|
| 2026-01-21 | 添加部分匹配（partialMatch），让 "abao" 通过 "bao" 匹配 "doubao"；修正 subsequence 示例 |
| 2026-01-21 | 添加子序列匹配（subsequence），支持非连续字符匹配 |
| 2026-01-18 | 创建模糊搜索系统，替换原有的前缀匹配 |
