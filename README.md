# Desk Tidy（Windows 桌面整理）

## 语言选择 (Language Selection)

<details open>
<summary>🀄️ 中文 (默认 / Default)</summary>

桌面快捷入口 + 托盘/热区唤起 + 磁吸自动隐藏，配合磨砂/玻璃视觉样式。

### 快速开始
- 安装依赖：`fvm flutter pub get`
- 运行：`fvm flutter run -d windows`

### 文档
- 功能全览：`docs/overview.md`
- 设置与持久化：`docs/settings.md`
- 文件/文件夹操作：`docs/file_ops.md`
- 图标采集/显示：`docs/icon_display.md`
- 长名称显示与复制：`docs/icon_name.md`
- 热区/磁吸/自动隐藏：`docs/auto_hide.md`
- 经典桌面图标方案：`docs/windows_classic_scheme.md`

### 功能特性

#### 核心功能
- **桌面快捷入口**：自动扫描并显示桌面上的应用快捷方式
- **真实图标显示**：提取并显示原始应用图标
- **托盘/热区唤起**：通过系统托盘或屏幕热区快速唤起应用
- **磁吸自动隐藏**：窗口吸附到屏幕边缘时自动隐藏，鼠标悬停时显示
- **磨砂/玻璃视觉样式**：现代化的玻璃态设计，与桌面背景融合
- **个性化设置**：支持窗口透明度、磨砂强度、图标大小等自定义
- **主题切换**：支持跟随系统、浅色和深色主题
- **桌面图标管理**：可隐藏/显示系统桌面图标

#### 计划推出功能
- **图标风格自定义**：支持自定义图标形状、主题和动画效果
- **快捷方式分类和搜索**：支持按类别组织快捷方式，提供快速搜索功能
- **多显示器支持**：智能适配多显示器环境，支持跨显示器管理

### 已知限制
- 仅适配 Windows，其他平台的桌面/回收站能力未实现。
- “自动刷新桌面”开关仍在迭代，刷新逻辑待完善。

### 小工具
- 统计 `lib/` 代码行：`fvm dart run bin/count_lib_loc.dart`

</details>

<details>
<summary>🇬🇧 English</summary>

Desktop shortcuts + Tray/HotZone activation + Magnetic auto-hide, with frosted/glass visual styles.

### Quick Start
- Install dependencies: `fvm flutter pub get`
- Run: `fvm flutter run -d windows`

### Documentation
- Overview: `docs/overview.md`
- Settings and Persistence: `docs/settings.md`
- File/Folder Operations: `docs/file_ops.md`
- Icon Collection/Display: `docs/icon_display.md`
- Long Name Display and Copy: `docs/icon_name.md`
- HotZone/Magnetic/Auto-hide: `docs/auto_hide.md`
- Windows Classic Scheme: `docs/windows_classic_scheme.md`

### Features

#### Core Features
- **Desktop Shortcuts**: Automatically scan and display desktop application shortcuts
- **Real Icon Display**: Extract and display original application icons
- **Tray/HotZone Activation**: Quickly activate the app via system tray or screen hot zones
- **Magnetic Auto-hide**: Automatically hide when window is snapped to screen edge, show on mouse hover
- **Frosted/Glass Visual Style**: Modern glassmorphism design, blending with desktop background
- **Personalization Settings**: Support for window opacity, frost intensity, icon size, etc.
- **Theme Switching**: Support system, light and dark themes
- **Desktop Icon Management**: Ability to hide/show system desktop icons

#### Planned Features
- **Icon Style Customization**: Support custom icon shapes, themes and animation effects
- **Shortcut Classification and Search**: Support organizing shortcuts by categories and quick search
- **Multi-monitor Support**: Intelligent adaptation to multi-monitor environments, cross-monitor management

### Known Limitations
- Only adapted for Windows, desktop/recycle bin capabilities for other platforms are not implemented.
- The "Auto Refresh Desktop" switch is still being iterated, and the refresh logic needs improvement.

### Tools
- Count lines of code in `lib/`: `fvm dart run bin/count_lib_loc.dart`

</details>
