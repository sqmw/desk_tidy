# 首次进入「应用列表」加载慢：原因与优化记录

## 现象
- 首次打开 Home 页（应用网格）时，出现明显等待（加载圈时间长 / UI 不够流畅）。

## 根因（本项目）
应用列表来源主要由两部分构成：
1. **桌面**：用户桌面 + 公共桌面
2. **开始菜单**：用户开始菜单 + 公共开始菜单

历史实现中，虽然目录扫描已经使用 `compute()` 放到 isolate，但在 UI isolate 仍然做了大量同步工作：
- 对每个 `.lnk` 调用 `getShortcutTarget()` 解析目标（COM/ShellLink）
- 再通过 `Directory.existsSync()` 判断是否为“文件夹快捷方式”（用于过滤）

当开始菜单里的 `.lnk` 数量很多时，上述解析会显著拖慢首次加载。

## 优化策略（2026-02）
目标：**减少 UI isolate 的 COM/IO 同步工作量**，把“必须做的重活”尽量挪到后台 isolate，或直接跳过不必要的解析。

### 1) UI isolate 不再批量解析开始菜单 `.lnk`
- `.lnk` 的 target 解析（COM/ShellLink）仍然需要，用于「按 target 去重」。
- 关键变化是：**解析放到 `compute()` 的后台 isolate 内执行**，避免 UI isolate 被同步 COM 调用拖慢。
- 同时通过名称关键字（如 uninstall / setup / help 等）过滤大部分无意义条目。
- 关键字匹配改为英文“按单词边界”匹配，避免误杀 `Installer` 这类正常入口（例如 `Visual Studio Installer.lnk`）。

### 2) 仅对「桌面来源」的 `.lnk` 做 target 解析（用于过滤文件夹快捷方式）
- 桌面上“文件夹快捷方式”更常见，且用户体验上需要剔除。
- 桌面条目数量通常较少，因此允许在 isolate 内做 `getShortcutTarget()` + `Directory.existsSync()` 过滤。

### 3) 扫描粒度调整
- 桌面根目录扫描改为 **非递归**（与之前桌面扫描逻辑一致），避免误扫大量子目录带来的 IO 开销。
- 开始菜单保持递归（开始菜单本身就存在多层分组）。

## 相关代码
- `lib/screens/desk_tidy_home/scan_isolate.dart`
- `lib/screens/desk_tidy_home/categories/shortcut_loading.dart`
- `lib/screens/desk_tidy_home/logic_refresh.dart`

## 手动验证建议
1. Debug 模式运行后，首次打开 Home 页观察加载时间。
2. 在开始菜单条目较多的机器上，对比优化前后“首次加载等待时间”和滚动流畅度。
3. 确认桌面上的“文件夹快捷方式”不会出现在应用网格中。
