# 告警清理与托盘唤醒模式修正（2026-02-01）

## 背景
在“巨型文件拆分”完成后，`fvm flutter analyze` 仍有少量 `warning` 级别告警，影响代码整洁度与 review 体验。

本次处理原则：
- **不引入额外依赖**
- **不改变核心行为/性能**
- 优先修复“明显不合理/不一致”的状态更新

## 变更点

### 1) 移除未使用的比较函数
- 文件：`lib/screens/desk_tidy_home/categories/utils.dart`
- 删除 `_shortcutsEqual(...)`（未被引用的私有方法），消除 `unused_element` 告警。

### 2) 托盘唤醒时记录正确的唤醒来源
- 文件：`lib/screens/desk_tidy_home/logic_runtime.dart`
  - `_presentFromTrayPopup()` 中设置 `_lastActivationMode = _ActivationMode.tray`
- 文件：`lib/screens/desk_tidy_home/logic_bootstrap.dart`
  - 托盘回调 `onShowRequested` 在非 `_trayMode` 分支同样设置 `_lastActivationMode = _ActivationMode.tray`

原因：
- `_lastActivationMode` 会影响窗口布局保存策略（热键/热区/通用），托盘唤醒不应误用上一次的 `hotkey/hotCorner`。
- 同时消除枚举值 `tray` 的 `unused_field` 告警。

## 验证方式
- `fvm flutter analyze`：上述两个 `warning` 不再出现（其余 `info` 级提示可按需逐步清理）。
