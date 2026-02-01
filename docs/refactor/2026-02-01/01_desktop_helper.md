# `desktop_helper` 拆分说明（2026-02-01）

## 拆分前的问题
- `lib/utils/desktop_helper.dart` 集中包含：窗口/桌面图标控制、开机启动、剪贴板、文件复制、快捷方式扫描、图标提取（含缓存/多 isolate）、Win32/COM 细节等。
- 违反单一职责（SRP），且修改/定位问题时需要在一个文件里“横向跳转”。

## 拆分后的结构
入口文件：
- `lib/utils/desktop_helper.dart`

实现文件（按职责拆分）：
- `lib/utils/desktop_helper/constants.dart`：常量、共享缓存/队列、日志小工具
- `lib/utils/desktop_helper/windowing.dart`：屏幕/窗口/前台焦点相关
- `lib/utils/desktop_helper/desktop_icons.dart`：桌面图标显示/隐藏与刷新通知
- `lib/utils/desktop_helper/autorun.dart`：开机自启（Registry Run）
- `lib/utils/desktop_helper/paths_and_shell.dart`：桌面/开始菜单路径、Explorer 打开、回收站删除、托盘气泡
- `lib/utils/desktop_helper/clipboard.dart`：CF_HDROP + DropEffect 复制/剪切到剪贴板
- `lib/utils/desktop_helper/file_copy.dart`：递归复制到目录（CopyResult）
- `lib/utils/desktop_helper/shortcut_scan.dart`：快捷方式解析与扫描
- `lib/utils/desktop_helper/icon_types.dart`：图标提取相关类型
- `lib/utils/desktop_helper/icon_extract_sync.dart`：同步图标提取（HICON/thumbnail 等）
- `lib/utils/desktop_helper/icon_thumbnail_alpha.dart`：thumbnail + alpha/mask 处理
- `lib/utils/desktop_helper/icon_extract_async.dart`：异步提取（多 isolate + 缓存）

## 对外 API 兼容性
外部仍然通过 `import '../utils/desktop_helper.dart';` 使用：
- `extractIconAsync(...)`
- `isDesktopIconsVisible() / setDesktopIconsVisible(...)`
- `setAutoLaunchEnabled(...) / isAutoLaunchEnabled(...)`
- `moveToRecycleBin(...)`
- `openInExplorer(...) / openWithApp(...) / openWithDefault(...)`
- `copyEntityPathsToClipboard(...)`
- `copyEntityToDirectory(...)`
等原有函数，不需要改调用方代码。

