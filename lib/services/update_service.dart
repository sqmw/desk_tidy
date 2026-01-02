import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _giteeOwner = 'zlmw';
  static const String _giteeRepo = 'desk_tidy';
  static const String _giteeApiBaseUrl = 'https://gitee.com/api/v5';

  /// 检查 Gitee 上的最新 Release 是否高于当前版本。
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final currentVersion = await _resolveCurrentVersion();
      final requestUri = Uri.parse(
        '$_giteeApiBaseUrl/repos/$_giteeOwner/$_giteeRepo/releases/latest',
      );

      print('UpdateService: checking $requestUri, current=$currentVersion');

      final response = await http
          .get(
            requestUri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'desk_tidy/$currentVersion',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final bodyPreview = response.body.length > 160
            ? '${response.body.substring(0, 160)}...'
            : response.body;
        throw HttpException(
          'HTTP ${response.statusCode} when requesting $requestUri, body: $bodyPreview',
          uri: requestUri,
        );
      }

      final releaseData =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final latestVersion =
          (releaseData['tag_name']?.toString() ?? '').replaceAll('v', '');
      final releaseUrl = releaseData['html_url'] as String?;
      final assets = releaseData['assets'] as List<dynamic>?;
      String? downloadUrl;

      if (assets != null) {
        for (final asset in assets) {
          final assetName = asset['name'] as String?;
          if (assetName != null && assetName.toLowerCase().endsWith('.exe')) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      final normalizedLatest = latestVersion.split('+').first;
      final hasUpdate = normalizedLatest.isNotEmpty &&
          _compareVersions(currentVersion, normalizedLatest) < 0;

      return UpdateInfo(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        downloadUrl: downloadUrl,
        releaseNotes: releaseData['body']?.toString() ?? '',
      );
    } catch (e, st) {
      print('检查更新时出错: $e\n$st');
      return null;
    }
  }

  /// 优先通过 package_info_plus 读取版本；若插件不可用（如 MissingPlugin），
  /// 退回到编译期的环境变量或者本地 pubspec 里的版本号，避免直接失败。
  static Future<String> _resolveCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version.split('+').first;
    } catch (e) {
      print('UpdateService: PackageInfo.fromPlatform failed, fallback. $e');
      final envVersion =
          const String.fromEnvironment('DESK_TIDY_VERSION', defaultValue: '')
              .trim();
      if (envVersion.isNotEmpty) {
        return envVersion.split('+').first;
      }
      final pubspecVersion = await _readLocalPubspecVersion();
      if (pubspecVersion != null) return pubspecVersion;
      // 最后退回一个兜底版本，保证 HTTP 请求能继续。
      return '0.0.0';
    }
  }

  static Future<String?> _readLocalPubspecVersion() async {
    try {
      final file = File('pubspec.yaml');
      if (!await file.exists()) return null;
      final lines = await file.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('version:')) {
          final version = trimmed.split(':').last.trim();
          return version.split('+').first;
        }
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  static int _compareVersions(String v1, String v2) {
    final v1Parts =
        v1.split('.').map((segment) => int.tryParse(segment) ?? 0).toList();
    final v2Parts =
        v2.split('.').map((segment) => int.tryParse(segment) ?? 0).toList();
    final maxLength =
        v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      final part1 = i < v1Parts.length ? v1Parts[i] : 0;
      final part2 = i < v2Parts.length ? v2Parts[i] : 0;
      if (part1 > part2) return 1;
      if (part1 < part2) return -1;
    }
    return 0;
  }

  static Future<bool> openDownloadUrl(String? downloadUrl) async {
    if (downloadUrl == null) return false;
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String? releaseUrl;
  final String? downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    this.releaseUrl,
    this.downloadUrl,
    required this.releaseNotes,
  });
}
