# `ShortcutCard` 拆分说明（2026-02-01）

## 拆分前的问题
- `lib/widgets/shortcut_card.dart` 单文件 ~550 行，混合了：
  - 选中/hover 状态与 label overlay
  - 右键菜单与剪贴板/打开方式等动作
  - 大块 UI 构建（图标、文本、交互）

## 拆分后的结构
入口文件（对外 import 不变）：
- `lib/widgets/shortcut_card.dart`

实现文件：
- `lib/widgets/shortcut_card/state.dart`：`ShortcutCard`/`_ShortcutCardState`（字段 + 生命周期 + build 分发）
- `lib/widgets/shortcut_card/selection_overlay.dart`：选中态与焦点联动
- `lib/widgets/shortcut_card/label_overlay.dart`：label overlay 计算与展示
- `lib/widgets/shortcut_card/menu.dart`：右键菜单与复制到剪贴板
- `lib/widgets/shortcut_card/ui_build.dart`：UI 主体构建 + `_buildIcon`

## 关键点
- 统一 `_setState(VoidCallback)` 入口，便于在拆分后的扩展文件里更新状态而不引入 analyzer 的 protected member 告警。

