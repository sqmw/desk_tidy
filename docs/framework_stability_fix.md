# 框架稳定性与断言异常修复

在文件管理功能的深度集成过程中，我们遇到了几类涉及 Flutter 框架层面的断言异常（Assertion Failure）。这些异常主要集中在 `MouseTracker` 和 `RenderBox` 的布局状态检测上，通常表现为应用在频繁点击、滚动或右键菜单交互时崩溃。

## 核心问题分析

### 1. MouseTracker 状态冲突 (`!_debugDuringDeviceUpdate`)
**异常现象**：`Failed assertion: line 199 pos 12: '!_debugDuringDeviceUpdate': is not true.`
**原因分析**：
该异常发生在 `MouseTracker` 正在处理设备更新（如鼠标移动）时，又同步触发了另一次设备更新。在我们的应用中，这是由于在同步的 `onSecondaryTapDown`（右键点击）直接调用了 `showMenu`，导致 `Overlay` 同步插入并可能立即触发焦点变化或新的布局测试，从而干扰了正在进行的鼠标状态追踪循环。

**补充触发场景（2026-02-03）**：
当鼠标悬停在快捷方式卡片上，切换 Tab（例如从“应用”切到“全部”）会触发大量 `MouseRegion` enter/exit 更新。如果在 `onEnter/onExit` 里同步 `setState` 更新 hover 状态，同样可能打断 `MouseTracker` 的设备更新流程，导致该断言并出现“卡死/红屏”。

### 2. RenderBox 布局异常 (`Cannot hit test a render box that has never been laid out`)
**异常现象**：命中测试（Hit Testing）路径中包含尚未完成布局的组件。
**原因分析**：
- **GlobalObjectKey 过重**：在海量列表项中使用 `GlobalObjectKey` 会显著增加布局负担。当列表快速刷新或过滤时，旧的定位锚点可能在下一帧布局前被命中测试系统尝试访问。
- **同步 UI 更新**：在手势回调中同步触发重大的 UI 结构变动（如打开菜单或切换面板），可能导致当前的命中测试路径指向已失效或未初始化的 RenderBox。

---

## 解决方案

### 1. 异步触发 Context Menu (Future.microtask)
为了确保 Overlay 的弹出不干扰手势处理循环，我们将所有页面（`AllPage`, `FilePage`, `FolderPage`）中的快捷菜单显示逻辑进行了 microtask 封装：

```dart
onSecondaryTapDown: (details) {
  // 使用 microtask 确保离开当前的手势/命中测试堆栈后执行
  Future.microtask(() async {
    if (!mounted) return;
    final result = await showMenu(...);
    // 处理结果...
  });
}
```

**补充（2026-02-04）**：
- 将 `NavigationRail` 右键“隐藏文件/文件夹”菜单也改为 microtask 触发（避免在 Pointer 事件栈内同步插入 Overlay）。
- 将 `PopupMenuButton`（内部同步 `showMenu`）替换为 `IconButton + showMenu + microtask`，避免触发 `MouseTracker` 重入断言。
- `CategoryStrip` 的右键菜单同样改为 microtask 触发。

### 1.1 MouseRegion hover 状态延迟到帧末更新（PostFrame）
将快捷方式卡片 hover 的 `setState` 从 `MouseRegion.onEnter/onExit` 中移出，改为把目标状态缓存后在 `addPostFrameCallback` 里统一更新，避免在 `MouseTracker` 的更新过程中重入触发 UI 变更。

同时，快捷方式卡片的右键菜单也使用 `Future.microtask` 异步触发 `showMenu`，保持与各页面一致的稳定性策略。

### 1.2 移除 Tooltip 相关 Overlay 路径（Windows）
在 Windows 端曾出现：
- `Cannot hit test a render box that has never been laid out.`
- 调用栈包含 `Tooltip → OverlayPortal → _DeferredLayout/_RenderDeferredLayoutBox`

为避免 Tooltip 的 Overlay/DeferredLayout 参与命中测试，当前策略是**不在 UI 中使用**：
- `Tooltip(...)`
- `IconButton.tooltip`
- `PopupMenuButton.tooltip`

如后续需要 tooltip，应优先以“按需显示、异步插入 Overlay、避免 hover 自动触发”的方式重新引入，并先在 Debug 下压测“频繁切换 Tab + 滚动 + 右键菜单”的稳定性。

### 2. 优化列表 Key 管理 (ValueKey)
移除了 `AllPage` 列表项中不必要的 `GlobalObjectKey`，统一改用轻量级的 `ValueKey(entity.path)`。
- **优势**：减少了全局 Key 注册表维护开销，稳定了列表项在动态过滤和排序时的布局语义，消除了 layout-during-hit-test 的隐患。

### 3. 下一代键盘事件 API 迁移 (KeyEvent)
将原有的 `RawKeyboard` 监听完全迁移至现代化的 `HardwareKeyboard` 和 `KeyEvent` API（`KeyDownEvent`, `KeyUpEvent`）。
- **逻辑增强**：统一了对 Ctrl、Delete 等修饰键和功能键的处理逻辑。
- **健壮性**：不仅通过事件流判断按键，还通过 `isLogicalKeyPressed` 进行辅助状态校验，彻底解决了“按键状态不同步”导致的 Services 断言失败。

---

## 验证与稳定性提升
经过上述调整，应用在高频右键、快速滚动以及 Ctrl+C/V 等快捷操作下的稳定性得到了极大提升， terminal 中不再出现 `MouseTracker` 或 `RenderBox` 相关的断言报错。
