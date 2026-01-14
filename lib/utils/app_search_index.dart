import 'package:lpinyin/lpinyin.dart';

final RegExp _searchSplit = RegExp(
  r'[^a-z0-9\u4e00-\u9fff]+',
  caseSensitive: false,
);
final RegExp _latinInitial = RegExp(r'[a-z0-9]');
final RegExp _containsChinese = RegExp(r'[\u4e00-\u9fff]');

String normalizeSearchText(String input) {
  final lowered = input.toLowerCase();
  return lowered.replaceAll(_searchSplit, '');
}

List<String> tokenizeSearchText(String input) {
  return input
      .toLowerCase()
      .split(_searchSplit)
      .where((part) => part.trim().isNotEmpty)
      .toList();
}

String _safePinyin(String input) {
  if (input.trim().isEmpty) return '';
  try {
    return PinyinHelper.getPinyinE(input);
  } catch (_) {
    return '';
  }
}

String _safeShortPinyin(String input) {
  if (input.trim().isEmpty) return '';
  try {
    return PinyinHelper.getShortPinyin(input);
  } catch (_) {
    return '';
  }
}

class AppSearchIndex {
  final String sourceName;
  final String normalizedName;
  final List<String> tokens;
  final String pinyin;
  final String pinyinInitials;
  final String latinInitials;
  final List<String> tokenPinyins;
  final List<String> tokenPinyinInitials;

  AppSearchIndex({
    required this.sourceName,
    required this.normalizedName,
    required this.tokens,
    required this.pinyin,
    required this.pinyinInitials,
    required this.latinInitials,
    required this.tokenPinyins,
    required this.tokenPinyinInitials,
  });

  factory AppSearchIndex.fromName(String name) {
    final normalized = normalizeSearchText(name);
    final tokens = tokenizeSearchText(name);
    final pinyin = normalizeSearchText(_safePinyin(name));
    final pinyinInitials = normalizeSearchText(_safeShortPinyin(name));
    final latinInitials = _buildLatinInitials(tokens);
    final tokenPinyins = <String>[];
    final tokenPinyinInitials = <String>[];
    for (final token in tokens) {
      if (!_containsChinese.hasMatch(token)) continue;
      final tokenPinyin = normalizeSearchText(_safePinyin(token));
      if (tokenPinyin.isNotEmpty) {
        tokenPinyins.add(tokenPinyin);
      }
      final tokenInitials = normalizeSearchText(_safeShortPinyin(token));
      if (tokenInitials.isNotEmpty) {
        tokenPinyinInitials.add(tokenInitials);
      }
    }

    return AppSearchIndex(
      sourceName: name,
      normalizedName: normalized,
      tokens: tokens,
      pinyin: pinyin,
      pinyinInitials: pinyinInitials,
      latinInitials: latinInitials,
      tokenPinyins: tokenPinyins,
      tokenPinyinInitials: tokenPinyinInitials,
    );
  }

  bool matchesPrefix(String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    if (normalizedName.startsWith(normalizedQuery)) return true;
    if (pinyin.startsWith(normalizedQuery)) return true;
    if (pinyinInitials.startsWith(normalizedQuery)) return true;
    if (latinInitials.startsWith(normalizedQuery)) return true;
    for (final token in tokens) {
      if (token.startsWith(normalizedQuery)) return true;
    }
    for (final tokenPinyin in tokenPinyins) {
      if (tokenPinyin.startsWith(normalizedQuery)) return true;
    }
    for (final tokenInitials in tokenPinyinInitials) {
      if (tokenInitials.startsWith(normalizedQuery)) return true;
    }
    return false;
  }
}

String _buildLatinInitials(List<String> tokens) {
  final buffer = StringBuffer();
  for (final token in tokens) {
    if (token.isEmpty) continue;
    final first = token[0];
    if (_latinInitial.hasMatch(first)) {
      buffer.write(first);
    }
  }
  return buffer.toString();
}
