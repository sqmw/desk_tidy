
# 设置与持久化说明

## 持久化位置与方式
- 使用 Flutter `shared_preferences` 存储：默认写入 Windows 用户配置目录（Roaming）下的应用私有文件。
- 键名与默认值：
  - `ui.transparency`：0.2（背景不透明度 = 1 - transparency）
  - `ui.frostStrength`：0.82
  - `ui.iconSize`：32
  - `behavior.showHidden`：false
  - `behavior.hideDesktopItems`：false
  - `behavior.autoRefresh`：false
  - `behavior.autoLaunch`：true（开机自启默认开启）
  - `ui.themeMode`：ThemeMode.dark
  - `ui.backgroundPath`：自定义背景路径（持久化为文件路径）
  - 窗口位置大小：`window.x` / `window.y` / `window.w` / `window.h`
- 背景图持久化：选择图片后，会复制一份到 `%AppData%/desk_tidy/background.*`（使用 `getApplicationSupportDirectory`），避免原图被移动/删除导致丢失。

## 开机自启
- 开关位置：设置页 “开机自动启动 (Windows)”。
- 默认值：开启（true）。
- 实现方式：向 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` 写入/删除 `DeskTidy` 值，指向当前可执行文件路径。
- 失败处理：切换失败会回滚开关状态并提示。

## 设置页各项内容
- 外观：窗口透明度、磨砂强度、图标大小、自定义背景图片（可清除）。
- 主题：跟随系统 / 浅色 / 深色。
- 行为：
  - 隐藏桌面图标（调用系统开关，不修改文件属性）
  - 显示隐藏文件/文件夹
  - 自动刷新桌面
  - 开机自动启动 (Windows)

## 相关代码入口
- 设置界面：`lib/setting/settings_page.dart`
- 持久化逻辑：`lib/utils/app_preferences.dart`
- 开机自启（注册表读写）：`lib/utils/desktop_helper.dart` 中 `setAutoLaunchEnabled`
