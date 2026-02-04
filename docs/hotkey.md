# 全局热键功能

## 概述

实现了全局快捷键唤醒窗口并聚焦搜索框的功能，用户可以在任何场景下通过快捷键快速打开应用。

## 快捷键

- **主要快捷键**: `Ctrl + Shift + Space`
- **备选快捷键**: `Alt + Shift + Space`

## 实现方案

### 技术选型

最初尝试使用 Windows `RegisterHotKey` API 注册全局热键，但遇到消息轮询问题（Flutter 自己的消息循环会干扰）。

**最终方案**：借鉴热区唤醒的实现方式，使用 `Timer.periodic` + `GetAsyncKeyState` 轮询检查按键状态。

### 核心组件

#### 1. `hotkey_service.dart`

```dart
/// 热键配置
class HotkeyConfig {
  final int vkCtrl;    // 是否需要 Ctrl (0/1)
  final int vkShift;   // 是否需要 Shift (0/1)
  final int vkAlt;     // 是否需要 Alt (0/1)
  final int vkKey;     // 主键虚拟键码
  
  bool isPressed() {
    // 使用 GetAsyncKeyState 检查按键状态
  }
}

/// 热键服务
class HotkeyService {
  Timer? _timer;
  
  void startPolling() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (_) {
      // 轮询检查热键状态，检测按下边沿触发回调
    });
  }
}
```

#### 2. 集成到主页面

在 `desk_tidy_home_page.dart` 中：

```dart
@override
void initState() {
  super.initState();
  _initHotkey();
}

void _initHotkey() {
  final service = HotkeyService.instance;
  service.register(HotkeyConfig.showWindow, callback: (_) => _presentFromHotkey());
  service.register(HotkeyConfig.showWindowAlt, callback: (_) => _presentFromHotkey());
  service.startPolling();
}

Future<void> _presentFromHotkey() async {
  // 先准备内容，避免白屏闪烁
  if (mounted) setState(() => _panelVisible = true);

  // 唤醒窗口
  await windowManager.setAlwaysOnTop(true);
  await windowManager.setSkipTaskbar(true);  // 不显示任务栏图标
  await windowManager.restore();  // 先恢复窗口状态
  await windowManager.show();     // 再显示窗口
  await windowManager.focus();
  
  _dockManager.onPresentFromTray();
  await _syncDesktopIconVisibility();

  // 聚焦搜索框
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }
    _appSearchFocus.requestFocus();
  });
}
```

## 关键实现细节

### 1. 按键状态检查

使用 `GetAsyncKeyState` 检查按键是否按下（返回值的高位为 1 表示按下）：

```dart
const downMask = 0x8000;
final isPressed = (GetAsyncKeyState(VK_CONTROL) & downMask) != 0;
```

### 2. 边沿检测

记录上一次的按键状态，只在从"未按下"到"按下"的边沿触发回调，避免重复触发：

```dart
if (isPressed && !wasPressed) {
  _callback?.call(hotkey);
}
_lastState[hotkey] = isPressed;
```

### 3. 任务栏图标控制

与热区唤醒保持一致，使用 `setSkipTaskbar(true)` 不显示任务栏图标：

```dart
await windowManager.setSkipTaskbar(true);
```

### 4. 轮询间隔

使用 100ms 的轮询间隔，平衡响应速度和性能：

```dart
Timer.periodic(const Duration(milliseconds: 100), (_) => _pollHotkeys());
```

## 排查过程

### 问题 1：Ctrl + Space 被占用

**现象**: 注册失败，error=0  
**原因**: Ctrl+Space 被输入法占用  
**解决**: 改用 Ctrl+Shift+Space

### 问题 2：RegisterHotKey 消息接收不到

**现象**: 注册成功但收不到 WM_HOTKEY 消息  
**原因**: Flutter 有自己的消息循环，PeekMessage 拿不到全局热键消息  
**解决**: 放弃 RegisterHotKey，改用 GetAsyncKeyState 轮询

### 问题 3：显示任务栏图标

**现象**: 热键唤醒时显示任务栏图标  
**原因**: `setSkipTaskbar(false)`  
**解决**: 改为 `setSkipTaskbar(true)`

### 问题 4：窗口唤醒时白屏闪烁

**现象**:
窗口显示之前会先显示一个白色的空白窗口，持续一瞬间，然后才正常显示内容。

**原因**:
1. `windowManager.show()` 在 `windowManager.restore()` 之前调用，导致窗口可能在最小化或未完全恢复状态时就显示。
2. Flutter 渲染延迟，窗口显示时 `_panelVisible` 仍为 false 或 UI 正在构建中。

**解决**:
调整了唤醒方法的执行顺序，确保**内容就绪**且**状态恢复**后再显示窗口：

```dart
// 1. 先准备内容，设置 UI 可见
if (mounted) setState(() => _panelVisible = true);

await windowManager.setAlwaysOnTop(true);
await windowManager.setSkipTaskbar(true);

// 2. 先恢复窗口状态（restore）
await windowManager.restore();

// 3. 最后才显示窗口（show）
await windowManager.show();
```

通过这种"UI就绪 -> 状态恢复 -> 显示窗口"的顺序，彻底消除了闪烁问题。此修复也同时应用到了热区唤醒和托盘唤醒逻辑中。

## 优势

1. **简单可靠**: 不依赖复杂的消息队列处理
2. **与现有逻辑一致**: 和热区唤醒使用相同的轮询模式
3. **无冲突**: 不会与系统或其他应用的快捷键冲突
4. **易扩展**: 可轻松添加更多快捷键组合

## 性能考虑

### CPU 优化（2026-02-04）

由于 `GetAsyncKeyState` + `Timer.periodic` 会持续唤醒进程，Debug 模式下更容易观察到 5%~10% 的 CPU 占用波动。

当前策略调整为：
- **仅在托盘模式（窗口隐藏）时轮询热键**；窗口显示时停止轮询，以降低空闲 CPU。
- 轮询间隔：
  - Release：约 `220ms`
  - Debug：约 `280ms`

> 影响：当窗口处于显示状态时，热键不再负责“再次唤醒/切换”。（仍可通过 UI/托盘交互隐藏/显示）

## 窗口布局配置

快捷键唤醒和热区唤醒使用**完全独立**的窗口配置，互不干扰：

| 唤醒方式 | 默认位置 | 默认大小 | 持久化键前缀 |
|---------|---------|---------|-------------|
| 快捷键 | 居中 | 65% × 75% | `window.hotkey.*` |
| 热区 | 左上角 | 25% × 85% | `window.hotCorner.*` |

### 存储键

**快捷键配置**：
- `window.hotkey.xRatio` / `yRatio` / `wRatio` / `hRatio`

**热区配置**：
- `window.hotCorner.xRatio` / `yRatio` / `wRatio` / `hRatio`

### 工作流程

1. **唤醒时**：根据唤醒方式（快捷键/热区）加载对应配置
2. **拖动/调整后**：保存到对应的配置键
3. **切换方式**：各自恢复自己保存的位置和大小

### 自动隐藏

快捷键唤醒后，窗口会在以下情况自动隐藏：

- **双击打开应用后** - 通过 `ShortcutCard.onLaunched` 回调触发
- **点击窗口外部** - 通过 `WindowDockManager.onMouseClickOutside()` 触发

点击窗口内部不会隐藏，与热区唤醒行为一致。

### 键盘焦点

为确保快捷键唤醒后能够立即键入，使用了 `forceSetForegroundWindow` 函数（位于 `desktop_helper.dart`）。该函数通过 `AttachThreadInput` 技术绕过 Windows 对后台窗口的焦点限制，确保应用获得系统级键盘焦点。

### 搜索快捷键

在搜索框中输入后：
- **↓ / Tab** - 选中下一个搜索结果（会显示高亮边框）
- **↑** - 选中上一个搜索结果
- **Enter** - 打开当前选中的应用（如未选中则打开第一个）

选中的应用会显示2像素宽的主题色边框。搜索内容变化时自动重置选中。
