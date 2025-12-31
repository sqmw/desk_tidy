# Windows 经典桌面方案

## 变更历史
- 初始实现尝试通过修改桌面桌面图标隐藏的“属性”实现状态切换，但这种方式在部分机器上会“闪动几下后无效”。  
- 后来观察到 Windows 自带的“右键 → 查看 → 显示桌面图标”才是官方推荐的方式，效果更加稳定，也在每次登录后保持一致。  
- 因此最终推翻原方案，采用“经典方案”后可以直接同步系统设置，并在界面里同步按钮状态，无需控制桌面文件夹权限。

## 实现细节
1. **原生 API**  
   - 通过 `SendMessage` + `WM_COMMAND` 向桌面窗口（`Progman` / `WorkerW`）发送 `0x7402`（`CMD_TOGGLE_DESKTOP_ICONS`），模拟用户点击“显示桌面图标”。  
   - 每次切换后立即读取状态：枚举工程列表窗口、获取 `SysListView32` 控件，然后 `GetWindowLong` / `GetMenuState` 检查当前是否勾选。  
2. **状态同步**  
   - 应用内 `Setting` 页面开关直接调用 `setDesktopIconsVisible(bool)`，这个方法通过上述命令设置 Windows 状态并返回执行结果。  
   - 定时器 `Timer.periodic(900ms)` 轮询 `isDesktopIconsVisible()`，若用户在系统设置里手动切换（非本 app 触发），会立即同步 `_hideDesktopItems`、更新 `AppPreferences`、刷新 UI。  
3. **用户反馈**  
   - 成功/失败会通过 `SnackBar` 提示（例如“桌面图标已隐藏”或“切换失败，请稍后重试”）。  
   - 稳定性最高时，本方案不会闪动，桌面有图标时 app 也会自动展现，隐藏时才会进入托盘。

## 未来计划
- 支持“智能同步”选项：当用户手动在系统里切换后，提示是否由 desk_tidy 统一控制；  
- 提供“快捷方式”按钮（类似 Windows 图标提取）直接在托盘菜单里加一个“刷新桌面图标”项。
