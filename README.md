# Desk Tidy（Windows 桌面整理）

桌面快捷入口 + 托盘/热区唤起 + 磁吸自动隐藏，配合磨砂/玻璃视觉样式。

## 快速开始
- 安装依赖：`fvm flutter pub get`
- 运行：`fvm flutter run -d windows`

## 文档
- 功能全览：`docs/overview.md`
- 设置与持久化：`docs/settings.md`
- 文件/文件夹操作：`docs/file_ops.md`
- 图标采集/显示：`docs/icon_display.md`
- 长名称显示与复制：`docs/icon_name.md`
- 热区/磁吸/自动隐藏：`docs/auto_hide.md`
- 经典桌面图标方案：`docs/windows_classic_scheme.md`

## 已知限制
- 仅适配 Windows，其他平台的桌面/回收站能力未实现。
- “自动刷新桌面”开关仍在迭代，刷新逻辑待完善。

## 小工具
- 统计 `lib/` 代码行：`fvm dart run bin/count_lib_loc.dart`
