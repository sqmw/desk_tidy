# 更新检查机制

## 背景
- `lib/services/update_service.dart` 会向 Gitee Releases (`/repos/<owner>/<repo>/releases/latest`) 发请求，取出 `tag_name`、发布说明和 `.exe` 资产。
- 版本判断通过去除 `v` 前缀的 tag 与本地 `pubspec.yaml` 版本做数字比较；只有最新 Release 版本比当前版本高时才会提示更新。
- 查到 `.exe` 资产后，会通过 `url_launcher` 以外部浏览器/下载管理器打开下载链接。

## 使用方式
1. 在 `update_service.dart` 中把 `_giteeOwner` 和 `_giteeRepo` 改成真实的 Gitee 仓库。
2. 确保在 Gitee 上的 Release 中上传 Windows 安装包（`.exe`），并使用规范 `tag`（例如 `v1.2.0`）。
3. 把 `pubspec.yaml` 中的 `version` 设置成比 Release 旧的版本号，以便更新检查判定 `hasUpdate` 为 `true`。
4. 设置页“检查更新”卡片负责触发 `_checkForUpdate`，它会展示状态文本/转圈、弹窗提示新版本，并调用 `UpdateService.openDownloadUrl`。

## 发布流程
1. 本地打 tag：
   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   git push gitee v1.2.0
   ```
2. GitHub 和 Gitee 各自通过 Releases 页面创建或更新发布并上传 `.exe`。
3. 确认 Gitee Release 地址 `https://gitee.com/<owner>/<repo>/releases/latest` 可访问，`tag_name` 可正确解析。

## 验证
- 运行 app，进入设置页单击“检查更新”，观察状态文本（例：`发现新版本 v1.2.0!`）或者“当前已是最新版本”提示。
- 如果有更新对话框，点击“立即下载”应回调 `url_launcher` 打开 `.exe` 链接。

