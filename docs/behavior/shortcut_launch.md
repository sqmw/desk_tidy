# 快捷方式启动策略（损坏检测 + 工作目录）

## 背景
- 问题 1：当目标程序被删除，只剩 `.lnk` 时，应用直接启动会失败，缺少“是否删除快捷方式”的确认流程。  
- 问题 2：部分程序（如 OBS）通过开始菜单可启动，但在 Desk Tidy 中启动报 `Failed to find locale/en-US.ini`，根因是直接启动了目标 `.exe`，未走快捷方式里的启动上下文（Start-In/命令行）。

## 本次改动

### 1. 统一启动入口
- 新增首页启动处理：`lib/screens/desk_tidy_home/handlers/shortcut_launch.dart`。  
- 所有应用页启动行为（双击、右键“打开”、搜索回车）统一走 `_openShortcutFromHome`。

### 2. 损坏快捷方式检测与删除确认
- 条件：`source` 为 `.lnk` 且 `targetPath` 存在但目标文件/目录不存在。  
- 行为：弹窗提示“快捷方式已失效”，用户可“取消”或“删除”。  
- 删除执行：发送到回收站，并刷新快捷方式列表。

### 3. 启动路径策略
- `.lnk` / `.appref-ms`：优先启动快捷方式文件本身（`shortcut.path`），不直接启动 `targetPath`。  
- 其他：按 `targetPath -> path` 回退。

### 4. 底层启动实现
- `openWithDefault` 改为优先使用 Windows `ShellExecute(open)`。  
- 对 `.exe` 显式传入程序所在目录作为 `lpDirectory`，避免相对资源加载失败。  
- `ShellExecute` 失败时回退到 `cmd /c start`。

## 影响范围
- `lib/screens/desk_tidy_home/handlers/shortcut_launch.dart`
- `lib/screens/desk_tidy_home/logic_search.dart`
- `lib/screens/desk_tidy_home/handlers/application_content.dart`
- `lib/widgets/shortcut_card/state.dart`
- `lib/widgets/shortcut_card/ui_build.dart`
- `lib/widgets/shortcut_card/menu.dart`
- `lib/utils/desktop_helper/paths_and_shell.dart`
