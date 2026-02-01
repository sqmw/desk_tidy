# `FilePage` 拆分说明（2026-02-01）

## 拆分前的问题
- `lib/screens/file_page.dart` 单文件 ~660 行，混合了：
  - 文件列表刷新与聚合
  - 页面菜单/文件菜单
  - 文件操作（粘贴/删除/重命名/复制/移动/打开方式）
  - UI 构建与键盘快捷键/双击逻辑

## 拆分后的结构
入口文件（对外 import 不变）：
- `lib/screens/file_page.dart`

实现文件：
- `lib/screens/file_page/state.dart`：`FilePage`/`_FilePageState`（字段 + 生命周期 + `build` 分发）
- `lib/screens/file_page/data_loading.dart`：文件列表刷新
- `lib/screens/file_page/menus.dart`：页面菜单、文件右键菜单
- `lib/screens/file_page/actions.dart`：粘贴/删除/重命名/复制/移动/打开方式等动作
- `lib/screens/file_page/ui_build.dart`：UI 构建（列表/交互/快捷键等）
- `lib/screens/file_page/file_icon.dart`：文件图标组件

## 关键点
- extension 内统一使用 `_setState(...)` 更新状态。

