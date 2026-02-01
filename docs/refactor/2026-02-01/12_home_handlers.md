# Home：handlers 拆分说明（2026-02-01）

## 拆分前的问题
- `lib/screens/desk_tidy_home/handlers.dart` 同时包含：
  - 系统桌面图标显示/隐藏回调
  - 主题切换回调
  - 搜索栏与计数 chip 构建
  - 应用页主体 UI 构建（GridView/编辑态/空态/布局计算）
- UI 结构与动作回调耦合，单文件偏大。

## 拆分后的结构
入口文件（对外 import 不变）：
- `lib/screens/desk_tidy_home_page.dart`

新增模块：
- `lib/screens/desk_tidy_home/handlers/system_and_theme.dart`：系统桌面图标、主题切换相关 handler
- `lib/screens/desk_tidy_home/handlers/search_widgets.dart`：搜索栏与计数 chip 构建
- `lib/screens/desk_tidy_home/handlers/application_content.dart`：应用页主体内容构建 + `_estimateTextHeight`

## 关键点
- 新文件位于 `desk_tidy_home/handlers/` 子目录，因此 `part of` 使用 `../../desk_tidy_home_page.dart`。
- 对外行为不变：仍由 `_buildApplicationContent()` 等方法提供 UI，拆分仅改变代码归属位置。

