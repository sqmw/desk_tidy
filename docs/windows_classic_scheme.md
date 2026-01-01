# Windows 经典桌面方案

## 变更历史
- 初版尝试修改桌面图标隐藏的“属性”实现状态切换，但部分机器会闪一下后无效。  
- 观察到 Windows 自带的“右键 → 查看 → 显示桌面图标”更稳定，并可在每次登录后保持一致。  
- 最终改为调用系统命令并同步界面状态，无需修改桌面文件夹权限。  

## 实现细节
1. **原生 API**  
   - 通过 `SendMessage` + `WM_COMMAND` 向桌面窗口（`Progman` / `WorkerW`）发送 `0x7402`（`CMD_TOGGLE_DESKTOP_ICONS`），模拟用户点击“显示桌面图标”。  
   - 每次切换后立即枚举窗口，定位 `SysListView32` 控件，再用 `GetMenuState` 检查当前是否勾选。  
2. **状态同步**  
   - 设置页开关直接调用 `setDesktopIconsVisible(bool)`，通过上述命令同步 Windows 状态并返回执行结果。  
   - 定时器 `Timer.periodic(900ms)` 轮询 `isDesktopIconsVisible()`：若用户在系统里手动切换，会立刻同步 `_hideDesktopItems`、更新 `AppPreferences`，并刷新 UI。  
3. **用户反馈**  
   - 成功/失败通过 `SnackBar` 提示，例如“桌面图标已隐藏”或“切换失败，请稍后重试”。  
   - 稳定时不会闪屏；桌面有图标时 app 也会自动展示，隐藏时进入托盘。  
