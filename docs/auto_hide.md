# 热区 / 磁吸 / 自动隐藏

## 需求
1. 拖动窗口过程中不吸附、不自动隐藏。
2. 拖放后若左上角进入“磁吸区域”，就对齐左上并自动隐藏到托盘。
3. 进入热区或点击托盘时要有平滑的出现/消失动画。
4. 鼠标离开窗口后至少延迟 ~260ms 再最小化，避免微调时立刻消失。

## 实现
### 热区唤起
- 热区位于屏幕左上，宽 `screenWidth / 4`、高 6~24px，仅在按住 Ctrl 且鼠标位于热区时才从托盘唤醒，避免全屏或移动时误触。
- 唤醒时短暂设置窗口 TopMost，防止被全屏应用遮挡，随后恢复原状态。
- 托盘菜单唤起走同一流程，确保第一下就能拿到窗口句柄。

### 磁吸与吸附条件
- 磁吸区更宽：`screenWidth / 6` × `screenHeight / 3`，越界（x < 0 或 y < 0）也视为需要靠边。
- `onWindowMoved` 期间视为拖拽，通过 200ms debounce 判断释放时机再检测是否吸附。
- 吸附时会暂时抑制 move 事件判定，防止动画中的 `setPosition` 再次触发拖拽逻辑。

### 自动隐藏
- 仅在已靠边（`_cornerDocked`）且非托盘/展示/动画/拖拽状态时才开启轮询 watcher（90ms）。
- 鼠标离开窗口后启动 260ms 延迟任务，期间若鼠标回到窗口或状态变化则取消；否则执行 `_dismissToTray(fromHotCorner: true)`，带淡入淡出动画。

### 原生判定
- `isCursorOverWindowHandle()` 结合 `WindowFromPoint`、`GetAncestor`、`IsChild` 判定鼠标是否在窗口内，规避 DPI 差异导致的误判。
- `findMainFlutterWindowHandle()` 通过 `EnumWindows` + PID + `FLUTTER_RUNNER_WIN32_WINDOW` 类名获取真实 HWND，确保高 DPI 下定位准确。

### 体验
- 离开后保留 `_hideDelay` 的缓冲，不会轻微移出即立刻消失。
- 出现/隐藏使用 `AnimatedSlide` + `AnimatedOpacity`，与托盘关闭按钮一致。
- 后续可抽象热区高度、延迟、是否需要 Ctrl 为可配置。

### 特殊场景处理
- **设置页面保护**：当用户停留在设置页面（Index 4）时，**禁用所有自动隐藏逻辑**。
  - **原因**：设置页面属于沉浸式配置场景，用户可能需要频繁切换窗口（如选择背景图片、查阅资料），或者进行长时间的微调操作。
  - **实现**：在 `onWindowBlur` 和自动隐藏定时器中检查当前 `selectedIndex`，如果是设置页则直接返回。
  - **效果**：即使窗口失去焦点（如点击了外部或切换了应用），只要 DeskTidy 停留在设置页，窗口就会保持显示，直到用户主动关闭或切换页面。
