# 图标提取与绘制

桌面快捷方式/文件的图标在桌面同步、列表刷新和卡片展示中被频繁用到。本说明覆盖采集、转码、缓存与性能防护要点，便于排查图标缺失或卡顿。

## 数据流
- 扫描：`lib/screens/desk_tidy_home_page.dart` 的 `_loadShortcuts()` 扫描用户桌面与公共桌面，过滤隐藏/系统文件（除非开启“显示隐藏项”），跳过 `.lnk` 指向文件夹的快捷方式。
- 提取：每个入口文件调用 `extractIconAsync()`（请求 256px），结果写入 `ShortcutItem.iconData`，UI 复用该内存，避免重复提取。
- 展示：`lib/widgets/shortcut_card.dart` 将已有 `iconData` 直接 `Image.memory`；缺失时用 `extractIconAsync` 兜底。

## 提取顺序（lib/utils/desktop_helper.dart）
`extractIcon(String filePath, {int size = 64})` 优先级：
1) **显式资源**：`SHGetFileInfo(..., SHGFI_ICONLOCATION)` 拿到图标文件路径 + 索引，`PrivateExtractIconsW` 提取指定尺寸 HICON（16–256）。
2) **系统大图标表**：`SHGetImageList(SHIL_JUMBO)` 取 256px 系统大图标（含 PNG-in-ICO）。
3) **Shell 默认**：`SHGetFileInfo(..., SHGFI_ICON|SHGFI_LARGEICON)` 获取 HICON。

## HICON 转 PNG
- `_hiconToPng`：创建顶向下 32bpp DIB，`DrawIconEx` 绘制到内存 DC，转 `img.Image`，经 `_normalizeIcon` 归一化后编码 PNG，释放 HICON/DC。
- `_normalizeIcon`：找非透明像素外接矩形（留 1px padding），目标边长 `size*0.92` 等比缩放居中，避免不同来源图标大小不一。

## 缓存与异步
- **LRU 缓存（64）**：按 IconLocation / 系统索引 / 文件路径 + 尺寸做缓存，失败也记录，重复调用直接命中。
- **异步+并发控制**：`extractIconAsync` 使用 `Isolate.run`，并发上限 3，避免同时创建过多 DC 阻塞 UI；`_loadShortcuts()` 全量通过该路径。

## 性能/排查提示
- 若自动刷新或桌面文件量大，CPU/IO 抖动多来自初次提取；可下调请求尺寸或加入磁盘缓存。
- 若看到重复 FFI 栈，检查是否遗漏了 `iconData` 复用或命中了兜底提取。
- 需要进一步定位时，可在 `extractIcon`、`_hiconToPng` 周围加耗时日志，区分 `.lnk/.exe/.url` 的开销。

## 相关代码
- 提取/缓存/异步：`lib/utils/desktop_helper.dart`（`extractIcon`、`extractIconAsync`、`_normalizeIcon` 等）
- 扫描入口：`lib/screens/desk_tidy_home_page.dart` 的 `_loadShortcuts()`
- UI：`lib/widgets/shortcut_card.dart` 的 `_buildIcon()`
