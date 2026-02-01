# `SettingsPage` 拆分说明（2026-02-01）

## 拆分前的问题
- `lib/setting/settings_page.dart` 单文件 ~700 行，包含：
  - 更新检查/版本号读取/背景图选择等“动作”
  - 大块 Settings UI 构建
  - UI 辅助组件（如样式选项 chip）

## 拆分后的结构
入口文件（对外 import 不变）：
- `lib/setting/settings_page.dart`

实现文件：
- `lib/setting/settings_page/constants.dart`：`ThemeModeOption`
- `lib/setting/settings_page/state.dart`：`SettingsPage`/`_SettingsPageState`（字段 + 生命周期 + build 分发）
- `lib/setting/settings_page/actions.dart`：背景图选择、读取版本号、检查更新、更新弹窗
- `lib/setting/settings_page/ui_build.dart`：Settings UI 主体构建 + `_buildStyleOptions`
- `lib/setting/settings_page/style_option_chip.dart`：`_StyleOptionChip` 组件

## 关键点
- 把更新检查/版本信息等“副作用逻辑”从 UI 结构中抽离，减少 UI 文件的认知负担。

