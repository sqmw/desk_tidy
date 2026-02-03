# 内存占用与泄漏排查（Windows / Flutter）

## 先说结论：Debug 400MB 不一定是“内存泄漏”
Flutter Desktop 在 Debug 模式下包含：
- Dart VM/JIT + Observatory/Service isolate 开销
- 更保守的缓存策略与调试信息
- 图片解码与 Skia/Impeller 的内部缓存

因此 **400MB 常见且不等于溢出**。判断是否泄漏，关键看“是否随操作持续上升且无法回落”。

## 项目中已知的内存风险点与处理
### 0) Flutter 解码图片缓存（ImageCache）
滚动图标网格会不断解码新图标（`ui.Image`），即使 UI 上不再显示，缓存也可能保留一段时间。

处理：设置全局 `ImageCache` 上限，避免进程内存无界增长。
- 代码：`lib/main.dart`

### 1) 文件页图标 Future 缓存（历史上可能无界增长）
`FilePage` 的 `_FileIcon` 会按文件路径缓存 `Future<Uint8List?>`。若用户浏览了大量不同目录/文件，缓存可能持续增长。

处理：改为 **LRU + 容量上限**，避免 Debug 长时间会话内存不断抬升。
- 代码：`lib/screens/file_page/file_icon.dart`

### 1.1 “全部/文件夹”页图标 Future 缓存
`AllPage` / `FolderPage` 在滚动时也会为已见过的实体缓存图标 Future。目录项很多时，滚动可能导致缓存持续扩大。

处理：同样改为 **LRU + 容量上限**。
- 代码：`lib/screens/all_page/state.dart`、`lib/screens/folder_page/state.dart`

### 2) 图标图片解码缓存（ui.Image 体积大）
即使 PNG 字节不大，解码后的 `ui.Image` 可能按 RGBA 存储（例如 256×256×4 ≈ 256KB/张），大量图标会显著占用内存。

处理：对 `Image.memory` 增加 `cacheWidth/cacheHeight`，按实际显示尺寸（×DPR）解码，减少解码后占用。
- 代码：`lib/widgets/beautified_icon.dart`

## 如何确认是否泄漏（推荐流程）
1. 用 Profile 模式观察（更接近真实）
   - `flutter run -d windows --profile`
2. 打开 DevTools → Memory
   - 记录初始 Heap
   - 重复执行“切 Tab/搜索/打开详情/返回”等操作 20~50 次
   - 观察是否出现“持续上涨且 GC 后不回落”的趋势
3. 重点关注对象类型
   - `Uint8List`：图标/缩略图字节
   - `ui.Image` / `Picture`：解码后的图片与渲染缓存
4. 排查原生资源泄漏（Windows）
   - 观察进程 **GDI Objects**/Handle 数量是否随操作单调上升
   - 若 GDI 持续上涨，通常是 `HICON/HBITMAP/DC` 未释放导致
