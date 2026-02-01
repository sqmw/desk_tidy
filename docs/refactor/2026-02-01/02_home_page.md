# Home 页拆分说明（2026-02-01）

## 拆分前的问题
- `lib/screens/desk_tidy_home_page.dart` 超过 2600 行：状态字段、偏好读取、分类管理、快捷方式加载/图标刷新、搜索逻辑、托盘/热区/磁吸、UI 构建混在一起。
- 单文件过大导致：
  - 代码审查困难（难以聚焦“本次改动影响范围”）
  - 功能间耦合隐性增长（改 A 很容易误伤 B）

## 拆分后的结构
入口文件：
- `lib/screens/desk_tidy_home_page.dart`

实现文件：
- `lib/screens/desk_tidy_home/constants.dart`：全局偏好缓存与唤醒模式枚举
- `lib/screens/desk_tidy_home/state.dart`：`DeskTidyHomePage` / `_DeskTidyHomePageState`（字段 + override 生命周期/窗口事件 + build）
- `lib/screens/desk_tidy_home/logic_bootstrap.dart`：启动/偏好/托盘/热键初始化相关逻辑
- `lib/screens/desk_tidy_home/logic_categories_shortcuts.dart`：分类与快捷方式加载/图标水合逻辑
- `lib/screens/desk_tidy_home/logic_search.dart`：搜索索引/键盘导航/隐藏文件菜单等
- `lib/screens/desk_tidy_home/logic_runtime.dart`：热区唤醒、托盘隐藏、桌面图标同步等运行期逻辑
- `lib/screens/desk_tidy_home/ui_builders.dart`：UI 辅助构建方法（TitleBar/SearchBar/Content 等）
- `lib/screens/desk_tidy_home/handlers.dart`：设置变更处理与一些 UI 回调辅助
- `lib/screens/desk_tidy_home/scan_isolate.dart`：目录扫描 isolate 相关结构与函数

## 关键点
- 仍保持外部入口不变：其它页面依旧 `import 'desk_tidy_home_page.dart'`。
- 为避免 extension 中直接调用 `setState` 的 analyzer 警告，`_DeskTidyHomePageState` 增加了 `_setState(VoidCallback fn)` 作为统一入口；拆分后的逻辑文件统一调用 `_setState(...)`。

## 与 `code_lib/lib_all` 的关系
仓库内存在 `test/copy_all_dart_files_test.dart`：会把 `lib/` 下所有 `.dart` 平铺复制到 `code_lib/lib_all/`。
因此本次拆分会新增多份被平铺复制的文件（预期行为），用于归档/对照。

