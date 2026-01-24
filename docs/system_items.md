# Windows 系统项目集成 (System Items)

本架构设计允许将 Windows 常用系统项目（如回收站、此电脑）直接集成到应用程序列表中，并提供用户可配置的可见性控制。

## 核心组件

### 1. 模型定义 (`lib/models/system_items.dart`)
定义了 `SystemItemType` 枚举和 `SystemItemInfo` 类。
- **shellCommand**: 使用 Windows Shell 命令（如 `shell:RecycleBinFolder`）实现跨版本兼容的启动。
- **CLSID**: 在加载图标时使用 CLSID（如 `::{645FF040...}`）以确保能正确提取系统原生图标。

### 2. 模型扩展 (`lib/models/shortcut_item.dart`)
在 `ShortcutItem` 中增加了 `isSystemItem` 标识和 `systemItemType` 字段，以便在 UI 层面区分普通快捷方式和系统项目。

### 3. 持久化配置 (`lib/utils/app_preferences.dart`)
增加了 `showRecycleBin` 和 `showThisPC` 配置项，允许用户在设置页面持久化他们的显示偏好。

## 实现细节

### 图标提取
系统项目没有物理文件路径。为了获取高分辨率图标，我们采用了类似 `code_lib` 中常见的方法：
- **手动资源路径**: 在 `SystemItemInfo` 中直接定义资源所在 DLL 及其索引（如 `imageres.dll,-109`）。
- **路径解析**: 增强了 `desktop_helper.dart` 中的解析逻辑，支持 `path,index` 格式。当检测到此类格式时，会自动提取 DLL 中的指定索引图标，绕过文件属性检查，确保 100% 成功加载 Windows 原生图标。

### 启动逻辑
由于这些是虚拟项目，传统的 `Process.run('explorer', [path])` 在处理 `system://` 协议时会失败。
我们在 `ShortcutCard` 中通过拦截 `isSystemItem` 项目，改用 `explorer.exe shell:Command` 的方式唤起。

### 排列顺序
按照用户的反馈，我们**恢复了自然排列顺序**：
- **应用列表**: 系统项目（回收站、此电脑）不再强制固定在开头，而是参与全局的字母顺序排序，与普通快捷方式混合排列。
- **设置页面**: 相关开关已归集到设置页面的“显示/隐藏”类目中，保持界面的逻辑一致性。

## 交互限制
为了保持系统项目的纯净性，系统项目在 UI 中具有以下限制：
- **右键菜单**: 不显示“添加到分类”、“删除”及“复制路径”等选项。
- **拖拽**: 目前不支持将系统项目拖入自定义分类（保持其在“全部”列表中的固定地位）。

## 修改记录
- **2026-01-24**: 
    - 初始版本实现：集成回收站和此电脑。
    - 进阶版：增加控制面板、网络、个人文件夹共五个标准系统项；优化设置页面交互，增加专有管理区块；实现按名称字母顺序自然排列。
