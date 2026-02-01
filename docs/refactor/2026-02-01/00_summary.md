# 大文件拆分重构（2026-02-01）

## 背景
`lib` 中存在多个超过 2000 行的文件，阅读与维护成本高，且职责混杂（UI + IO + Win32 + 缓存 + 异步队列）。

本次重构的目标是：**不改变对外 API/行为** 的前提下，把“巨型文件”按职责拆为多个小文件，降低单文件复杂度，方便后续继续按 SOLID/设计模式深化。

## 本次变更点（总览）
- `lib/utils/desktop_helper.dart`：改为库入口文件，具体实现按职责拆到 `lib/utils/desktop_helper/` 下多个 `part` 文件。
- `lib/screens/desk_tidy_home_page.dart`：改为库入口文件，Home 页按模块拆到 `lib/screens/desk_tidy_home/` 下多个 `part` 文件。

## 为什么使用 `part` 拆分
- 保持原有 `import '../utils/desktop_helper.dart'`、`import 'desk_tidy_home_page.dart'` **完全不变**（对外 API 兼容）。
- 允许拆分后仍共享同一 library 的私有成员（`_xxx`），减少一次性“公开化/破坏封装”的风险。

## 进一步建议（后续迭代）
- 将 `part` 拆分逐步过渡为“Feature/Service/Repository”结构（例如 `lib/features/home/...`），并用接口抽象（DIP）替代对具体实现的依赖。
- 为 Win32/FFI 的边界增加更明确的 Facade（外观模式）与 Adapter（适配器模式），减少 UI 层对平台细节的直接调用。

## 关联文档
- `docs/refactor/2026-02-01/01_desktop_helper.md`
- `docs/refactor/2026-02-01/02_home_page.md`
- `docs/refactor/2026-02-01/03_all_page.md`
- `docs/refactor/2026-02-01/04_folder_page.md`
- `docs/refactor/2026-02-01/05_file_page.md`
- `docs/refactor/2026-02-01/06_settings_page.md`
- `docs/refactor/2026-02-01/07_fuzzy_matcher.md`
- `docs/refactor/2026-02-01/08_shortcut_card.md`
- `docs/refactor/2026-02-01/09_home_categories_shortcuts.md`
- `docs/refactor/2026-02-01/10_icon_extract_sync.md`
- `docs/refactor/2026-02-01/11_app_preferences.md`
- `docs/refactor/2026-02-01/12_home_handlers.md`
