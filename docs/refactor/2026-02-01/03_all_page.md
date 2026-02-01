# `AllPage` 拆分说明（2026-02-01）

## 拆分前的问题
- `lib/screens/all_page.dart` 单文件 ~1200 行，包含：
  - 目录加载/聚合视图（desktop roots）
  - 搜索/排序/筛选
  - 右键菜单与页面菜单
  - 文件操作（复制/移动/粘贴/删除/重命名/打开方式）
  - 大段 UI 构建（含键盘快捷键、双击逻辑、详情面板）
- 单文件职责过多，不利于 review 与后续按 SOLID 做进一步解耦。

## 拆分后的结构
入口文件（对外 import 不变）：
- `lib/screens/all_page.dart`

实现文件（按职责拆分）：
- `lib/screens/all_page/constants.dart`：筛选/排序枚举
- `lib/screens/all_page/models.dart`：选中项描述 `_EntitySelectionInfo`
- `lib/screens/all_page/state.dart`：`AllPage`/`_AllPageState`（字段 + 生命周期 + `build` 仅做分发）
- `lib/screens/all_page/filter_sort.dart`：筛选/搜索/排序逻辑（`_filteredItems` 等）
- `lib/screens/all_page/data_loading.dart`：刷新/加载/聚合视图/图标 future 缓存
- `lib/screens/all_page/navigation.dart`：目录导航（home/up/open）
- `lib/screens/all_page/menus.dart`：实体右键菜单、页面菜单
- `lib/screens/all_page/actions.dart`：复制/移动/粘贴/删除/重命名/打开方式等动作
- `lib/screens/all_page/ui_build.dart`：UI 构建（主体布局、详情栏等）
- `lib/screens/all_page/entity_icon.dart`：图标渲染组件 `_EntityIcon`

## 关键点
- 仍保持外部入口不变：其它页面继续 `import '../screens/all_page.dart';`。
- `ui_build.dart`/`menus.dart` 等拆分文件里不直接调用 `setState`（避免 analyzer 对 extension 调用 protected 成员的告警），统一通过 `state.dart` 中的 `_setState(VoidCallback)` 更新状态。

