
# Desk Tidy（Windows 桌面整理）

桌面整理工具，整合桌面应用、文件夹、文件的快捷入口，并提供磨砂/玻璃视觉样式、托盘/热角交互。默认支持双击打开、右键菜单、长名称提示/复制等常用操作。

## 快速开始
- `fvm flutter pub get`
- `fvm flutter run -d windows`

## 主要功能
- 应用/文件夹/文件分类视图，支持双击打开、右键菜单。
- 右键“复制到...”可复制文件或文件夹（含子目录）到指定目录。
- 托盘模式 + Ctrl 左上角热区唤起，支持磁吸/自动隐藏。
- 开机自动启动（默认开启，可在设置中切换，写入 HKCU\Software\Microsoft\Windows\CurrentVersion\Run）。
- 隐藏/显示系统桌面图标、显示隐藏文件、自动刷新开关。
- 可调透明度、磨砂强度、图标大小、主题模式，支持自定义背景图（备份到应用目录）。

## 文档索引
- 设置与持久化：`docs/settings.md`
- 文件/文件夹操作（含“复制到...”）：`docs/file_ops.md`
- 图标采集/显示：`docs/icon_display.md`
- 长名称显示与复制：`docs/icon_name.md`
- 经典桌面方案背景：`docs/windows_classic_scheme.md`
- 热区/磁吸/自动隐藏：`docs/auto_hide.md`

## 已知限制
- 目前仅适配 Windows：非 Windows 平台的桌面图标、回收站等能力未适配。
- “自动刷新桌面”开关仍在迭代，刷新逻辑待完善。

## 小工具
- 统计 `lib/` 代码行：`fvm dart run bin/count_lib_loc.dart`
