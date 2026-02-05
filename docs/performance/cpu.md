# CPU 优化（Windows）

## 背景

Desk Tidy 在 Windows 上有若干“探测型”功能（热键、热区、桌面图标可见性同步）。如果这些逻辑使用高频 `Timer.periodic` 常驻运行，会导致空闲时 CPU 偶尔冲到 5%~10%（尤其是 Debug）。

本项目的目标是：在不影响核心体验的前提下，让空闲 CPU 尽量接近 0。

## 已做优化（2026-02-04）

### 1) 全局热键轮询仅在托盘模式启用

热键实现使用 `GetAsyncKeyState` 轮询检测组合键。此机制会持续唤醒进程。

策略：
- 窗口隐藏到托盘（`_trayMode=true`）时：启用轮询
- 窗口显示但未聚焦（例如被其他窗口遮挡）时：启用轮询（用于“再次按热键置顶”）
- 窗口显示且聚焦时：停止轮询

轮询间隔：
- Release：`80ms`
- Debug：`80ms`

实现位置：`lib/screens/desk_tidy_home/logic_bootstrap.dart`

### 2) 热区唤醒轮询按需启用 + 降频

策略：
- 仅在“托盘模式”或“窗口吸附态”启用热区轮询，否则直接停止定时器
- 降低轮询频率：
  - Release：`1200ms`
  - Debug：`1500ms`

实现位置：`lib/screens/desk_tidy_home/logic_runtime.dart`

### 3) 桌面图标可见性同步按需启用 + 降频

该同步用于“隐藏桌面图标(Windows)”功能与系统状态保持一致。

策略：
- 仅在功能开启（`_hideDesktopItems=true`）且窗口可见（非托盘、面板可见）时启用
- 降低轮询频率：
  - Release：`8s`
  - Debug：`10s`
- 每次唤醒窗口时仍会主动同步一次，避免错过托盘期间的变化

实现位置：`lib/screens/desk_tidy_home/logic_runtime.dart`

## 手动验证建议

1. 启动应用后隐藏到托盘，观察任务管理器 CPU（应趋近 0，偶有短暂波动属正常）
2. 通过热键/热区唤醒窗口，保持窗口显示，观察 CPU（应显著低于之前版本）
3. 在设置里开启/关闭“隐藏桌面图标(Windows)”，观察桌面图标状态与设置同步是否正常
