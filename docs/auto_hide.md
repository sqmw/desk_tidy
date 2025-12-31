# 热区 / 磁吸 / 自动隐藏

## 用户需求
1. 鼠标拖动窗口过程中绝不吸附、也不自动隐藏；  
2. 拖拽松手后，若窗口左上角进入“磁吸区域”，就对齐左上角并自动隐藏；  
3. 进入热区、或点击托盘时要优雅地完成出现/消失动画；  
4. 鼠标离开窗口后至少延迟 ~260ms 才最小化（防止微调立刻消失）。

## 当前方案
1. **热区定义**  
   - `hotCornerZone` 位于屏幕左上角，宽为 `屏幕宽 / 4`，高固定 6~24px，确保只有在特殊操作（靠近顶部非常低的位置）时才触发。  
   - 仅在 `Ctrl` 按下且鼠标在此区域时，才从系统托盘唤起应用（防止全屏应用误触）。  
2. **磁吸区与吸附条件**  
   - `snapZone` 更宽：`屏幕宽 / 6` × `屏幕高 / 3`，或越界 `x < 0 或 y < 0` 也算吸附。  
   - `onWindowMoved` 时全部被认定为“拖拽”，通过 200ms 的 debounce，只有 200ms 不动才认为拖拽结束并检查是否应该吸附。  
   - 吸附时设置 `_suppressMoveTrackingUntil`，在动画期间不再把自身 `setPosition` 误判为拖动。
3. **自动隐藏**  
   - `_startAutoHideWatcher()` 每 90ms 检查：只有 `_cornerDocked` 且窗口不处于 _trayMode/_presenting/_dismissing/_dragging 时才继续；  
   - 若鼠标不在窗口内，立刻启动 260ms 延迟任务（`_hideDelay`），期间若鼠标重新进入或状态变化会通过 `_dismissToken` 取消。  
   - 隐藏执行 `_dismissToTray(fromHotCorner: true)`，表现与点击右上角关闭按钮一致，带有淡入淡出动画。
4. **原生判定**  
   - `isCursorOverWindowHandle()` 结合 `WindowFromPoint`、`GetAncestor`、`IsChild` 等 Win32 接口判断，避免 DPI 误差导致的误判。  
   - `findMainFlutterWindowHandle()` 通过 `EnumWindows` 与当前 PID + `FLUTTER_RUNNER_WIN32_WINDOW` 类名确认真正 HWND，从而能在高 DPI 下依然正确定位窗口。

## 体验优化
- 鼠标离开后保留 `_hideDelay` 的缓冲，即使光标经过边缘也不会立刻掉到托盘；  
- 出现/消失的动画由 `AnimatedSlide` + `AnimatedOpacity` 控制，点击托盘（无论上次是否是热区关闭）都能保证窗口与屏幕左上角对齐；  
- 未来可增加设置项调整热区高度、延迟时间、是否需要 Ctrl。
