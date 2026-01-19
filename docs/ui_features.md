# UI 交互与体验优化

本文档记录了应用中关于用户界面交互和体验的优化实现。

## 1. 分类栏滚轮优化

### 需求背景
默认情况下，水平滚动列表（如 `ReorderableListView`）在使用鼠标滚轮时，通常需要按住 `Shift` 键才能进行水平滚动。用户反馈这与直觉不符，希望直接使用鼠标滚轮就能横向滚动列表。

### 实现方案

将 `CategoryStrip` 改造为 `StatefulWidget`，并使用 `Listener` 组件监听 `onPointerSignal` 事件，捕获鼠标滚轮动作并手动控制滚动位置。

#### 关键代码

```dart
// 监听指针信号
Listener(
  onPointerSignal: _handlePointerSignal,
  child: // ... ReorderableListView
)

// 处理滚动逻辑
void _handlePointerSignal(PointerSignalEvent event) {
  if (event is PointerScrollEvent) {
    // 获取垂直滚动量并应用到水平滚动控制器
    final delta = event.scrollDelta.dy;
    final newOffset = (_scrollController.offset + delta)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    
    // 直接跳转到新位置，实现流畅滚动
    _scrollController.jumpTo(newOffset);
  }
}
```

### 优化效果
- 用户不再需要按住 Shift 键。
- 滚轮的垂直操作直观地映射为列表的水平移动。

## 2. 窗口吸附体验优化

### 需求背景
应用具有"窗口停靠"（Window Docking）功能，当窗口靠近屏幕边缘时会自动吸附到侧边隐藏。用户反馈吸附区域（Snap Zone）过大，导致窗口在屏幕中间操作时松开鼠标也会意外触发吸附。

### 实现方案

在 `window_dock_logic.dart` 中调整 `snapZone` 的计算逻辑，大幅缩小触发区域。

#### 参数调整

| 参数 | 原始值 (比例) | 优化后值 (比例) | 最大值限制 |
|------|--------------|----------------|------------|
| 水平触发宽度 | Screen Width / 6 | Screen Width / 12 | 200px |
| 垂直触发高度 | Screen Height / 3 | Screen Height / 8 | 150px |

#### 关键代码

```dart
static Rect snapZone(Size screenSize) {
  // 缩小吸附区域，避免误触发
  // 使用 clampSize 限制最大像素值，防止在大屏幕上区域过大
  final left = clampSize(screenSize.width / 12, 32, 200); 
  final top = clampSize(screenSize.height / 8, 32, 150);
  return Rect.fromLTWH(0, 0, left, top);
}
```

### 优化效果
- 只有将窗口拖动到非常靠近屏幕左上角时才会触发吸附。
- 有效防止了日常拖动窗口时的误操作。

## 3. "全部"页面列表与详情的分栏优化

### 需求背景
在之前的版本中，"全部"页面的详情展示位于列表上方或重合，不仅遮挡视线，也导致列表项的操作路径变长。用户希望在快速浏览文件列表时，能同步在侧边看到选中项的详细属性。

### 实现方案

重构 `all_page.dart` 的 UI 布局，从单一列表结构改为 **Split View** (分条视图)。

- **左侧 (Expanded)**: 保持文件磁贴列表，增强核心浏览区域。
- **右侧 (Flexible/SizedBox)**: 新增详情面板，固定显示选中项的路径、统计信息等。
- **默认选中**: 当 `_refresh` 加载数据后，若列表不为空且未选择任何项，自动选中第一个条目（DTO 首位），确保右侧详情栏不会出现大片留白。

#### 关键布局代码

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // 左侧：列表
    Expanded(child: _buildFileList()),
    // 分割线
    const VerticalDivider(width: 1),
    // 右侧：详情面板
    SizedBox(width: 250, child: _buildSelectionDetail()),
  ],
)
```

### 优化效果
- **效率提升**: 用户浏览列表时，详情自动刷新，减少了点击和关闭弹窗的往复操作。
- **排版专业**: 借鉴了现代桌面文件管理器（如 macOS Finders 详情预览）的设计理念，使界面更具生产力感。
