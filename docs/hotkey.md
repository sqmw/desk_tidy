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
  // 唤醒窗口
  await windowManager.setAlwaysOnTop(true);
  await windowManager.setSkipTaskbar(true);  // 不显示任务栏图标
  await windowManager.show();
  await windowManager.restore();
  await windowManager.focus();
  
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

## 优势

1. **简单可靠**: 不依赖复杂的消息队列处理
2. **与现有逻辑一致**: 和热区唤醒使用相同的轮询模式
3. **无冲突**: 不会与系统或其他应用的快捷键冲突
4. **易扩展**: 可轻松添加更多快捷键组合

## 性能考虑

- 轮询间隔 100ms，对性能影响微乎其微
- 只在需要时才检查按键状态，不执行复杂操作
- 热键检测失败时不会影响应用其他功能
