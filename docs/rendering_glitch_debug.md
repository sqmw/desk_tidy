# Flutter Release 渲染异常（界面挤压/透明）深度调查报告

## 问题现象描述
在 `Release` 模式下，通过“热区唤醒”或“快捷键唤醒”应用时，会出现以下现象：
1. **界面被挤压**：UI 似乎被压缩成顶部的一小条或特定的窄区域。
2. **背景异常**：由于 Scaffold 背景透明，未被 UI 覆盖的区域显示为完全透明或带有上一帧的残影。
3. **状态传染**：一旦发生挤压，后续唤醒通常保持挤压状态，直到手动进行“最大化/还原”操作触发真正的 `WM_SIZE`。

> [!NOTE]
> Debug 模式下开启 `debugShowCheckedModeBanner: true` 时，该 Bug 无法重现。这是由于 Debug Banner 的 Overaly 刷新时序意外地触发了布局刷新。

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
这导致父窗口已经显示并拥有新尺寸，但 Flutter 子窗口依然保留着隐藏状态时的旧尺寸（通常很小），从而产生“挤压”现象。

## 最终解决方案：原子化同步 (Atomic Sync)

我们抛弃了所有 Dart 侧的 Workaround，在原生层进行了加固：

### 1. 基类暴露同步接口 (Win32Window)
在 `win32_window.h` 中新增公有方法 `SyncChildContentSize()`，专门用于将子窗口强制对齐父窗口 Client Area。

### 2. 子类显式强制同步 (FlutterWindow)
修改 `flutter_window.cpp` 的 `MessageHandler`：
```cpp
if (message == WM_SIZE || message == WM_SHOWWINDOW || message == WM_WINDOWPOSCHANGED) {
  SyncChildContentSize(); // 无论 Flutter 引擎是否拦截，都必须强制对齐尺寸
}
```

### 3. 增强 Show 方法
重写 `Show()` 方法，确保在窗口变为可见的瞬间，立即执行一次 `SyncChildContentSize()`。

## 结论
该问题并非 Flutter Engine (`flutter_windows.dll`) 的 Bug，而是 Windows Runner 子父窗口尺寸对齐时机不严谨导致的。通过在消息循环中增加“正交”的尺寸同步逻辑，我们成功地在纯 Release 模式下彻底解决了渲染异常。

**现在应用可以：**
- 使用原生的 Release 工程配置进行编译。
- 移除所有 Debug Banner 相关的 Hacking。
- 安装包体积保持最优，且激活界面始终稳定。

## 附录：安装程序 (Inno Setup) 关键配置
由于 Flutter Windows 应用是 64 位的，我们确保了安装程序以 64 位模式运行，以避免安装到 `C:\Program Files (x86)`。

**关键配置项：**
- `ArchitecturesAllowed=x64`
- `ArchitecturesInstallIn64BitMode=x64`

该设置确保应用安装在标准的 `C:\Program Files` 目录下，且注册表与系统路径均对齐 64 位标准。
