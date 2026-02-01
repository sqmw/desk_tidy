# Home：分类/快捷方式逻辑拆分（2026-02-01）

## 拆分前的问题
- `lib/screens/desk_tidy_home/logic_categories_shortcuts.dart` 集中包含：
  - 分类持久化
  - 快捷方式扫描/构建
  - 图标异步水合（大量 Future）
  - 分类编辑/菜单/排序/工具函数
- 单文件职责过多，不利于继续演进（例如把扫描、索引、图标加载进一步抽到 service）。

## 拆分后的结构
入口文件（对外 import 不变）：
- `lib/screens/desk_tidy_home_page.dart`

新增模块：
- `lib/screens/desk_tidy_home/categories/persistence.dart`：分类读取/保存
- `lib/screens/desk_tidy_home/categories/shortcut_loading.dart`：快捷方式扫描/构建与同步分类
- `lib/screens/desk_tidy_home/categories/icon_hydration.dart`：图标异步水合
- `lib/screens/desk_tidy_home/categories/category_crud.dart`：分类 CRUD + 内联编辑
- `lib/screens/desk_tidy_home/categories/category_menu.dart`：快捷方式分类菜单 + 分类重排
- `lib/screens/desk_tidy_home/categories/utils.dart`：路径/列表比较等工具

## 关键点
- 这些文件位于 `desk_tidy_home/categories/` 子目录，因此 `part of` 使用 `../../desk_tidy_home_page.dart`（避免解析到错误路径）。
- 仍保持原有 `_loadShortcuts()` 等方法名不变，仅拆分实现位置。

