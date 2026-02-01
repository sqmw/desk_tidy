# `FolderPage` 拆分说明（2026-02-01）

## 拆分前的问题
- `lib/screens/folder_page.dart` 单文件 ~780 行，混合了：
  - 目录读取与刷新
  - 右键菜单/页面菜单
  - 文件操作（粘贴/新建/复制/移动/删除/重命名/打开方式）
  - UI 构建与键盘快捷键/双击逻辑

## 拆分后的结构
入口文件（对外 import 不变）：
- `lib/screens/folder_page.dart`

实现文件：
- `lib/screens/folder_page/state.dart`：`FolderPage`/`_FolderPageState`（字段 + 生命周期 + `build` 分发）
- `lib/screens/folder_page/data_loading.dart`：刷新/读取/图标 future 缓存
- `lib/screens/folder_page/navigation.dart`：目录导航
- `lib/screens/folder_page/menus.dart`：实体右键菜单、页面菜单
- `lib/screens/folder_page/actions.dart`：复制/移动/粘贴/删除/重命名/打开方式等动作
- `lib/screens/folder_page/ui_build.dart`：UI 构建（列表/交互/快捷键等）
- `lib/screens/folder_page/entity_icon.dart`：目录/快捷方式图标组件

## 关键点
- 逻辑拆分文件里统一调用 `_setState(...)` 更新状态，避免在 extension 内直接调用 `setState` 触发 analyzer 告警。

