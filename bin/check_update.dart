import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// 简单的命令行脚本，直接调 Gitee Releases latest 接口并做一次版本比对。
/// 运行：`dart run bin/check_update.dart`
Future<void> main() async {
  final currentVersion = await _readPubspecVersion();
  if (currentVersion == null) {
    stderr.writeln('无法读取 pubspec.yaml 里的 version');
    exitCode = 1;
    return;
  }

  final uri =
      Uri.parse('https://gitee.com/api/v5/repos/zlmw/desk_tidy/releases/latest');
  stdout.writeln('请求: $uri, 当前版本: $currentVersion');

  try {
    final resp = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'desk_tidy-cli/$currentVersion',
          },
        )
        .timeout(const Duration(seconds: 10));

    stdout.writeln('HTTP ${resp.statusCode}');
    if (resp.statusCode != 200) {
      stdout.writeln('Body: ${resp.body}');
      exitCode = 1;
      return;
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String? ?? '').replaceAll('v', '');
    final normalizedTag = tag.split('+').first;
    final hasUpdate =
        normalizedTag.isNotEmpty && _compareVersions(currentVersion, normalizedTag) < 0;

    stdout.writeln('最新 tag: $tag (normalized: $normalizedTag)');
    stdout.writeln('hasUpdate: $hasUpdate');

    final assets = data['assets'] as List<dynamic>? ?? const [];
    for (final a in assets) {
      final name = a['name'] as String?;
      final url = a['browser_download_url'] as String?;
      stdout.writeln('asset: $name -> $url');
    }
  } catch (e, st) {
    stderr.writeln('请求/解析失败: $e');
    stderr.writeln(st);
    exitCode = 1;
  }
}

Future<String?> _readPubspecVersion() async {
  try {
    final pubspec = await File('pubspec.yaml').readAsLines();
    for (final line in pubspec) {
      final trimmed = line.trim();
      if (trimmed.startsWith('version:')) {
        final v = trimmed.split(':').last.trim();
        return v.split('+').first; // ignore build metadata
      }
    }
  } catch (_) {
    // ignore
  }
  return null;
}

int _compareVersions(String v1, String v2) {
  final v1Parts = v1.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final v2Parts = v2.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final len = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

  for (var i = 0; i < len; i++) {
    final a = i < v1Parts.length ? v1Parts[i] : 0;
    final b = i < v2Parts.length ? v2Parts[i] : 0;
    if (a > b) return 1;
    if (a < b) return -1;
  }
  return 0;
}
