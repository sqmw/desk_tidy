# Flutter Release 渲染异常（界面挤压/透明）深度调查报告

## 问题现象描述
在 `Release` 模式下，通过"热区唤醒"或"快捷键唤醒"应用时，会出现以下现象：
1. **界面被挤压**：UI 似乎被压缩成顶部的一小条或特定的窄区域。
2. **背景异常**：由于 Scaffold 背景透明，未被 UI 覆盖的区域显示为完全透明或带有上一帧的残影。
3. **状态传染**：一旦发生挤压，后续唤醒通常保持挤压状态，直到手动进行"最大化/还原"操作触发真正的 `WM_SIZE`。

> [!NOTE]
> Debug 模式下该 Bug 无法重现。这是由于 Debug 模式的时序差异意外地触发了布局刷新。

## 根因定位：子窗口尺寸同步失败

### 1. 技术背景 (Win32 Runner)
Flutter 在 Windows 上运行在一个父子窗口架构中：
- **父窗口 (Parent HWND)**：由 `Win32Window` 类管理，处理系统窗口消息。
- **子窗口 (Child HWND)**：由 Flutter Engine（通过 `FlutterViewController`）创建并持有，负责实际的画面渲染。

父窗口必须在接收到尺寸变更消息时，手动调用 `MoveWindow` 将子窗口铺满其 `Client Area`。

### 2. 消息拦截 (Message Shadowing) 导致的同步失效
在我们的 Runner 代码中：
- `Win32Window` 基类定义了 `WM_SIZE` 处理逻辑。
- `FlutterWindow` 子类重写了 `MessageHandler`，并优先将消息交给 `flutter_controller_->HandleTopLevelWindowProc`。

**致命归因**：
在 `Release` 模式的高效分发路径下，Flutter Engine 可能会处理并拦截掉某些关键的 `WM_SIZE` 或 `WM_WINDOWPOSCHANGED` 消息。如果子类的 `MessageHandler` 因为 Flutter 已经处理了该消息而提前返回，基类 `Win32Window` 里的 `MoveWindow` 逻辑就不会执行。

## 最终解决方案：组合拳（C++ 被动监听 + Dart 主动触发）

> [!IMPORTANT]
> 单独依赖 C++ 端的被动消息监听**不够可靠**，必须配合 Dart 侧的主动尺寸变更来强制触发同步。

### 1. C++ 端：基类暴露同步接口 (Win32Window)
在 `win32_window.h` 中新增公有方法 `SyncChildContentSize()`，专门用于将子窗口强制对齐父窗口 Client Area。

### 2. C++ 端：子类显式强制同步 (FlutterWindow)
修改 `flutter_window.cpp` 的 `MessageHandler`：
```cpp
if (message == WM_SIZE || message == WM_SHOWWINDOW || message == WM_WINDOWPOSCHANGED) {
  SyncChildContentSize(); // 无论 Flutter 引擎是否拦截，都必须强制对齐尺寸
}
```

### 3. Dart 端：震动 resize 触发 WM_SIZE（关键！）
在 `_presentFromHotkey` 和 `_presentFromHotCorner` 函数中，`show()` 之后立即执行：
```dart
// [Fix] Force a tiny resize to trigger WM_SIZE and sync child HWND in Release mode
final currentSize = await windowManager.getSize();
await windowManager.setSize(Size(currentSize.width + 1, currentSize.height));
await windowManager.setSize(currentSize);
```

**原理**：通过 1 像素的尺寸往返跳变，强制产生 `WM_SIZE` 消息，从而触发 C++ 端的 `SyncChildContentSize()`。

## 涉及文件

| 文件 | 变更内容 |
|------|----------|
| `windows/runner/win32_window.h` | 新增 `SyncChildContentSize()` 声明 |
| `windows/runner/win32_window.cpp` | 实现 `SyncChildContentSize()`，在 `WM_SIZE` 等消息中调用 |
| `windows/runner/flutter_window.cpp` | 在消息分发后显式调用 `SyncChildContentSize()` |
| `lib/screens/desk_tidy_home_page.dart` | 在 `_presentFromHotkey` 和 `_presentFromHotCorner` 中添加震动 resize |

## 结论
该问题并非 Flutter Engine (`flutter_windows.dll`) 的 Bug，而是 Windows Runner 子父窗口尺寸对齐时机不严谨导致的。通过 **C++ 被动监听 + Dart 主动触发** 的组合拳，我们成功地在纯 Release 模式下彻底解决了渲染异常。

## 附录：安装程序 (Inno Setup) 关键配置
由于 Flutter Windows 应用是 64 位的，我们确保了安装程序以 64 位模式运行：

```ini
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
```

该设置确保应用安装在标准的 `C:\Program Files` 目录下。
