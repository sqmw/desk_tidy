# 图标提取与绘制

本文记录桌面快捷方式/文件图标的获取、转码与展示路径，便于日后排查图标缺失或性能问题。

## 数据流概览
- 入口：`lib/screens/desk_tidy_home_page.dart` 的 `_loadShortcuts()` 扫描桌面（含公共桌面），过滤隐藏/系统文件（除非开启“显示隐藏项”），跳过 `.lnk` 指向文件夹的快捷方式。
- 每个入口文件调用 `extractIcon()` 请求 256px PNG，并将结果写入 `ShortcutItem.iconData`，UI 复用该内存块，避免重复提取。
- UI：`lib/widgets/shortcut_card.dart` 将 `iconData` 直接作为 `Image.memory` 渲染；若缺失则在卡片内部再次调用 `extractIcon()` 做兜底。

## 提取顺序（lib/utils/desktop_helper.dart）
`extractIcon(String filePath, {int size = 64})` 的优先级：
1) **显式资源定位**：`SHGetFileInfo(..., SHGFI_ICONLOCATION)` 获取实际的图标文件路径与索引，然后用 `PrivateExtractIconsW` 提取指定大小的 HICON（尺寸被钳制在 16–256 之间）。  
2) **系统大图标表**：如果上一步失败，使用 `SHGetImageList(SHIL_JUMBO)` 取系统的 256px 图标（覆盖 PNG-in-ICO）。  
3) **Shell 默认图标**：最后退回 `SHGetFileInfo(..., SHGFI_ICON|SHGFI_LARGEICON)` 拿到 HICON。

## HICON 转 PNG 的具体步骤
- 函数：`_hiconToPng(int icon, {required int size})`
- 操作：
  - 创建顶向下 32bpp 的 DIB，使用 `DrawIconEx` 将 HICON 绘制到内存 DC，得到 BGRA 像素。
  - 通过 `image` 包构造 `img.Image`，之后调用 `_normalizeIcon()` 做归一化。
  - 将归一化结果编码为 PNG 字节返回，并负责释放 HICON/DC/内存。

### 归一化规则（`_normalizeIcon`）
- 计算非透明像素的外接矩形，留 1px padding。
- 目标边长为 `size * 0.92`，等比缩放裁剪区域，放入原尺寸的透明画布中央，避免不同来源图标出现“忽大忽小”。

## 性能与排查建议
- **耗时点**：`PrivateExtractIconsW` + `DrawIconEx` 仅在 `_loadShortcuts()` 时对每个快捷方式跑一遍；若自动刷新或文件量大，CPU/IO 抖动可能来自这里。
- **尺寸成本**：当前请求 256px PNG 并常驻内存；如果出现卡顿或内存占用高，可测试下调请求尺寸或加缓存层（例如按路径持久化 PNG 或按尺寸分级缓存）。
- **兜底调用**：`ShortcutCard` 在缺失 `iconData` 时会再次调用 `extractIcon()`；若看到重复 FFI 栈，可以检查加载流程是否提前填充了 `iconData`。
- **定位慢点**：可在 `extractIcon()`、`_hiconToPng()` 周围加统计，观察不同类型文件（.lnk/.exe/.url）耗时；Shell API 失败会回退到下一级，频繁失败意味着路径或权限异常。

## 相关代码定位
- 图标提取：`lib/utils/desktop_helper.dart` 中的 `extractIcon`、`_getIconLocation`、`_extractJumboIconPng`、`_hiconToPng`、`_normalizeIcon`
- 加载入口：`lib/screens/desk_tidy_home_page.dart` 的 `_loadShortcuts()`
- UI 展示：`lib/widgets/shortcut_card.dart` 的 `_buildIcon()`
