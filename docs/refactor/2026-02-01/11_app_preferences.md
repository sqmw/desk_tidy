# `app_preferences` 拆分说明（2026-02-01）

## 拆分前的问题
- `lib/utils/app_preferences.dart` 同时包含：
  - SharedPreferences 读写（大量 key + 保存方法）
  - 背景图备份到 AppSupport 目录
  - 分类 JSON 存取
  - 配置/窗口布局/分类结构体

## 拆分后的结构
入口文件（对外 import 不变）：
- `lib/utils/app_preferences.dart`

实现文件：
- `lib/utils/app_preferences/prefs.dart`：`AppPreferences`（读写、备份、分类存取）
- `lib/utils/app_preferences/models.dart`：`DeskTidyConfig`/`WindowBounds`/`HotkeyWindowLayout`/`StoredCategory`

## 关键点
- 入口文件仍然是 `lib/utils/app_preferences.dart`，调用方无需改 import。
- 先把“模型定义”从“存取逻辑”中分离，降低后续拆解成本（例如把 categories/background 拆成独立 repository）。

