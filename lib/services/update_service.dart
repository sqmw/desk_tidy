import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // Replace these values with the actual Gitee repository owner and name.
  static const String _giteeOwner = 'zlmw';
  static const String _giteeRepo = 'desk_tidy';
  static const String _giteeApiBaseUrl = 'https://gitee.com/api/v5';

  /// 检查 Gitee 上的最新 Release 是否高于当前版本。
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse(
          '$_giteeApiBaseUrl/repos/$_giteeOwner/$_giteeRepo/releases/latest',
        ),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        print('获取更新信息失败: ${response.statusCode}');
        return null;
      }

      final releaseData = jsonDecode(response.body);
      final latestVersion =
          releaseData['tag_name']?.toString().replaceAll('v', '') ?? '';
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

      final hasUpdate = latestVersion.isNotEmpty &&
          _compareVersions(currentVersion, latestVersion) < 0;

      return UpdateInfo(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        downloadUrl: downloadUrl,
        releaseNotes: releaseData['body']?.toString() ?? '',
      );
    } catch (e) {
      print('检查更新时出错: $e');
      return null;
    }
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
