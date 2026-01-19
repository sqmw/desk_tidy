# 快捷键、重命名与 UX 优化

## 功能概述
为提升文件管理效率，本项目在 `AllPage`、`FolderPage` 和 `FilePage` 中统一实现了以下交互功能：

### 1. 键盘快捷键支持
- **复制 (Ctrl + C)**：将选中项的路径存入系统剪贴板。
- **粘贴 (Ctrl + V)**：从剪贴板读取文件路径并拷贝至当前活跃目录。
- **删除 (Delete / Backspace / Numpad Decimal)**：将选中项移动至回收站。
- **重命名 (F2)**：弹出重命名对话框。

### 2. 重命名功能
- 通过右键菜单或 `F2` 键触发。
- 逻辑：获取当前路径 -> 弹出输入框 -> `entity.rename(newPath)` -> 刷新 UI。

### 3. 右键菜单优化
- 调整了菜单顺序，将高频操作（重命名、删除）放在一起，并与复制信息类操作（复制路径等）用分割线分开。
- 增加了快捷键提示（Trailing hints）。

---

## 重点技术实现记录

### 1. 解决 Delete 键检测失败问题 (Numpad Decimal)
**问题描述**：在某些 Windows 键盘（尤其是带有数字键盘的）上，按下传统的 `Delete` 键在 Flutter 中可能被识别为 `LogicalKeyboardKey.numpadDecimal` (ID: 8589935150)。这导致标准的 `.delete` 判定失效。

**解决方案**：
在 `onKeyEvent` 中同时判定多个键码：
```dart
if (event.logicalKey == LogicalKeyboardKey.delete ||
    event.logicalKey == LogicalKeyboardKey.backspace ||
    event.logicalKey == LogicalKeyboardKey.numpadDecimal) {
  _handleDelete();
}
```

### 2. Isolate 中 FFI 调用导致的崩溃问题
**问题描述**：最初尝试将文件列表扫描放入 `Isolate.run` 以防 UI 卡顿。但由于扫描逻辑中包含了 `isHiddenOrSystem`（通过 Win32 FFI 调用），而 **Dart Isolate 不支持在后台线程执行 FFI 调用**，导致程序崩溃或抛出 `Illegal argument`。

**解决方案**：
1. **移除 Isolate 嵌套**：鉴于本地目录扫描速度通常极快，取消了文件获取阶段的 Isolate 包装，回归主线程同步执行。
2. **状态分离**：如果后续必须使用 Isolate，需先在 Isolate 中仅完成基础 `Directory.listSync`，将路径返回主线程后，再由主线程通过 FFI 检查属性。

### 3. 同名文件粘贴处理逻辑
**问题描述**：粘贴文件时若目标目录已存在同名项，原生 `copy` 会报错。

**解决方案**：
在 `copyEntityToDirectory` 中增加了迭代查找逻辑：
- 基础名: `test.txt`
- 重名后尝试: `test (1).txt`, `test (2).txt` ... 直到找到可用名称。
- 实现位于 `lib/utils/desktop_helper.dart`。

### 4. 键盘焦点管理
**问题描述**：快捷键生效的前提是 Widget 必须拥有 Focus。

**解决方案**：
1. 使用 `FocusNode` 并在 `initState` 中 `autofocus: true`。
2. 在列表项的 `onTapDown` 或右键点击时，显式调用 `_focusNode.requestFocus()`，确保焦点始终跟随用户交互。
