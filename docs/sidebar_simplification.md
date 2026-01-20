# 侧边栏简化 & 子分类 Tab

## 改动概述
简化了侧边栏导航，移除了独立的"文件夹"和"文件"Tab，改为在"全部"视图内部使用 SegmentedButton 进行分类筛选。

## 改动前
```
侧边栏：[应用] [全部] [文件夹] [文件] [设置]
```

## 改动后
```
侧边栏：[应用] [全部] [设置]
全部视图内：[全部] [文件夹] [文件] ← SegmentedButton
```

## 技术实现

### 1. 侧边栏精简
- **文件**: `lib/screens/desk_tidy_home_page.dart`
- 移除 `NavigationRailDestination` 中的"文件夹"和"文件"
- 调整 `_buildContent()` 的 switch-case：`case 2` 直接返回 `SettingsPage`
- 移除 `file_page.dart` 和 `folder_page.dart` 的 import

### 2. AllPage 子分类
- **文件**: `lib/screens/all_page.dart`
- 新增枚举：`_EntityFilterMode { all, folders, files }`
- 新增状态：`_filterMode`
- 新增 getter：`_filteredEntries` 根据筛选模式过滤列表
- UI：SegmentedButton 放置在路径栏下方

### 3. 筛选逻辑（与原 FilePage/FolderPage 一致）

**文件夹筛选**：
- 只显示 `Directory`
- 排除以 `.` 开头的隐藏文件夹

**文件筛选**：
- 只显示 `File`
- 排除 `.lnk`（快捷方式）
- 排除 `.exe`（可执行程序）
- 排除 `desktop.ini` / `thumbs.db`

## 相关文件
- `lib/screens/desk_tidy_home_page.dart`
- `lib/screens/all_page.dart`
- `lib/screens/folder_page.dart` (保留但不再使用)
- `lib/screens/file_page.dart` (保留但不再使用)
