part of '../settings_page.dart';

extension _SettingsPageActions on _SettingsPageState {
  Future<void> _pickBackground() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
    );
    if (picked != null && picked.files.isNotEmpty) {
      final path = picked.files.single.path;
      if (path != null && path.isNotEmpty) {
        widget.onBackgroundPathChanged(path);
      }
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      _setState(() => _appVersion = 'v${info.version}');
    } catch (_) {
      // Silence failures.
    }
  }

  Future<void> _checkForUpdate() async {
    _setState(() {
      _checkingUpdate = true;
      _updateStatus = '正在检查更新...';
    });

    try {
      final updateInfo = await UpdateService.checkForUpdate();

      if (updateInfo == null) {
        _setState(() {
          _updateStatus = '无法获取更新信息';
          _checkingUpdate = false;
        });
        return;
      }

      if (updateInfo.hasUpdate) {
        _setState(() {
          _updateStatus = '发现新版本 v${updateInfo.latestVersion}!';
          _checkingUpdate = false;
        });

        // 显示更新对话框
        _showUpdateDialog(updateInfo);
      } else {
        _setState(() {
          _updateStatus = '当前已是最新版本 v${updateInfo.currentVersion}';
          _checkingUpdate = false;
        });
        // _showInfoDialog('已是最新', '当前已是最新版本 v${updateInfo.currentVersion}');
      }
    } catch (e) {
      _setState(() {
        _updateStatus = '检查更新失败: $e';
        _checkingUpdate = false;
      });
    }
  }

  void _showUpdateDialog(UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现新版本'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('新版本: v${updateInfo.latestVersion}'),
              const SizedBox(height: 8),
              if (updateInfo.releaseNotes.isNotEmpty) ...[
                const Text(
                  '更新内容:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(updateInfo.releaseNotes),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await UpdateService.openDownloadUrl(updateInfo.downloadUrl);
            },
            child: const Text('立即下载'),
          ),
        ],
      ),
    );
  }
}
