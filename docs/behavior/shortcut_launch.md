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

## 启动感知优化（2026-02-16）

### 目标
- 热键唤起状态下，双击/回车启动应用时不再等待 `openWithDefault` 返回才隐藏窗口。
- 对齐 macOS Launchpad 体验：先立即收起启动台，再让用户感知到“应用正在启动”。

### 行为调整
- 热键模式启动应用时改为：
  1. 先进入后台异步启动流程并标记 `launching`
  2. 渲染一帧图标 loading 后执行 `_dismissToTray`（不阻塞）
- 非热键模式仍保持原有“等待启动结果后再提示失败”的交互。

### 启动反馈
- 新增服务：`lib/services/launch_feedback_service.dart`
- 启动反馈为“双通道”：
  1. **卡片图标 loading 转圈**：启动开始后将当前快捷方式标记为 `launching`，在图标右下角显示圆形进度指示器。
  2. **任务栏无弹窗指示器（热键场景）**：创建最小化且不激活的任务栏指示图标（不显示可见弹窗），并同时启用：
     - `FlashWindowEx` 闪烁提示
     - `ITaskbarList3.SetProgressState(TBPF_INDETERMINATE)` 不确定进度动画（任务栏持续动态反馈）
- 任务栏指示器触发时机调整为“先显示反馈，再执行 `openWithDefault`”，避免被 `ShellExecute` 阻塞导致用户看不到启动中的反馈。
- 任务栏指示器图标源改为“应用本体优先”：优先取 `targetPath/.exe`，若 `launchPath` 为 `.lnk` 则额外解析其真实目标并优先使用，避免出现快捷方式箭头样式导致前后图标不一致。
- 任务栏 overlay 图标改为高对比度旋转帧（深色圆底 + 高亮尾迹），并拆分为独立工厂文件，便于后续继续调视觉参数。
- 任务栏占位图标新增“本体轻弹跳”帧动画（12 帧循环），用于强化“正在启动中”的可感知性；overlay 转圈作为补充提示继续保留。
- 若能解析到目标 `.exe`，服务会等待该程序主窗口出现（最长约 20 秒）后再清除 loading；否则保留至少 450ms 的最小反馈时长，避免闪烁。
- 热键场景会同时启用任务栏指示器；普通场景仅保留卡片 loading 转圈。

### 失败反馈（热键模式）
- 因窗口会先隐藏，失败提示改为优先托盘气泡（`showTrayBalloon`）。
- 若托盘气泡不可用，则回退为应用内 `OperationManager.quickTask`。

### 本次涉及文件
- `lib/services/launch_feedback_service.dart`
- `lib/services/launch_feedback/taskbar_launch_indicator.dart`
- `lib/services/launch_feedback/taskbar_overlay_spinner_icon_factory.dart`
- `lib/services/launch_feedback/taskbar_progress_controller.dart`
- `lib/services/launch_feedback/taskbar_window_icon_animation_factory.dart`
- `lib/services/launch_feedback/window_locator.dart`
- `lib/screens/desk_tidy_home/handlers/shortcut_launch.dart`
- `lib/screens/desk_tidy_home/handlers/application_content.dart`
- `lib/screens/desk_tidy_home/state.dart`
- `lib/widgets/shortcut_card/state.dart`
- `lib/widgets/shortcut_card/ui_build.dart`
- `lib/screens/desk_tidy_home_page.dart`
