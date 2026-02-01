# `icon_extract_sync` 拆分说明（2026-02-01）

## 拆分前的问题
- `lib/utils/desktop_helper/icon_extract_sync.dart` 包含同步图标提取的整条链路：
  - 高分辨率 icon/jumbo icon 获取
  - system icon index 计算
  - HICON 提取/编码
  - bitmap → png 转换
- 单文件过长且多种职责混合（Win32 细节、编码转换、缓存配合）。

## 拆分后的结构
入口文件（对外 import 不变）：
- `lib/utils/desktop_helper.dart`

新增模块：
- `lib/utils/desktop_helper/icon_extract/extract_icon.dart`：`extractIcon` 主流程
- `lib/utils/desktop_helper/icon_extract/jumbo_icon.dart`：jumbo icon 获取
- `lib/utils/desktop_helper/icon_extract/system_icon_index.dart`：system icon index/attributes
- `lib/utils/desktop_helper/icon_extract/hicon_extract.dart`：从 icon location 提取 HICON
- `lib/utils/desktop_helper/icon_extract/hicon_encode.dart`：HICON 编码为 PNG
- `lib/utils/desktop_helper/icon_extract/bitmap_png.dart`：bitmap → PNG 转换

## 关键点
- 新文件位于二级目录 `desktop_helper/icon_extract/`，`part of` 使用 `../../desktop_helper.dart`。
- 对外 API（例如 `extractIconAsync`）不变；本次仅拆分同步路径实现，降低单文件复杂度，便于后续更细粒度的性能/可靠性优化。

