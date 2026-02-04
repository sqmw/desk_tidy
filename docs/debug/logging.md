# 调试日志（Windows）

## 为什么“控制台没有日志”
Desk Tidy 的 Windows 可执行文件是 GUI 应用，直接双击运行时通常不会附带控制台窗口，因此 `print()` / `debugPrint()` 不一定能在你当前的终端里看到。

## 日志文件位置
程序启动后会写入日志到应用数据目录：
- `%AppData%/com.example/desk_tidy/logs/desk_tidy.log`

> 该路径来自 `getApplicationSupportDirectory()`，在 Windows 上通常对应 Roaming 目录。
> 日志为缓冲写入，程序运行中会每 2 秒自动刷新到文件。

## 记录内容
- 未捕获异常（`FlutterError` / `PlatformDispatcher` / zone error）
- 关键运行信息（后续会逐步补齐到高频路径，便于定位 CPU/内存问题）
- 周期性能日志（RSS / ImageCache）

## 性能日志开关
- 默认：Debug 自动开启
- Release 需要设置环境变量：`DESK_TIDY_PERF_LOG=1`

## 图标提取线程策略（稳定性开关）
- 默认 **开启** 图标提取 isolate（更流畅）。
- 如出现稳定性问题，可在设置页“高级”中关闭（长按版本号显示）。
- 环境变量 `DESK_TIDY_ICON_ISOLATES` 优先级最高：
  - `DESK_TIDY_ICON_ISOLATES=1` 强制开启
  - `DESK_TIDY_ICON_ISOLATES=0` 强制关闭

## Tooltip 崩溃规避
- Windows 端出现过 `_RenderDeferredLayoutBox` 相关的命中测试断言（常见于 `Tooltip → OverlayPortal`）。
- 当前策略：**UI 内不再使用 `Tooltip(...)` / `IconButton.tooltip` / `PopupMenuButton.tooltip`**，避免引入 Tooltip 的 Overlay/DeferredLayout 路径。

## 使用建议
- Debug 下内存/CPU 波动会更大，优先用 `--profile` 或 `--release` 复现并对比。
- 复现问题后，把 `desk_tidy.log` 末尾相关片段发我即可继续定位。
- 需保证 `WidgetsFlutterBinding.ensureInitialized()` 与 `runApp()` 处于同一 Zone，否则会出现 `Zone mismatch` 报错。
