# 单例启动保障

Desk Tidy 采用两层防护确保用户只会有一个可见窗口和一个托盘图标：

1. **文件锁**：`lib/utils/single_instance.dart` 在 `%LOCALAPPDATA%/desk_tidy_single_instance.lock` 上尝试上独占锁。如果锁已被其它实例持有，当前进程立即向第一个实例发 `activate` 消息，并退出。
2. **端口唤醒**：第一个实例监听本地 `43991` 端口，收到 `activate` 消息后会唤起主窗口（`windowManager.show/restore/focus`）。这个通道也用于拖起第一实例后再次启动的激活。

### 触发流程
- 用户双击桌面图标启动，第一个进程拿到锁，继续初始化窗口/托盘并启动 `ServerSocket`。
- 再次双击图标时，新进程拿锁失败，调用 `_sendActivate()` 通过 socket 通知第一个实例，然后退出。第一个实例收到消息后通过 `_dockManager`（或 tray helper）切换可见状态而不是再开窗口。

### 出错排查
- 如果仍能看到多个托盘图标：
  1. 确保 `%LOCALAPPDATA%` 可写（或在 `single_instance.dart` 中改为其它可写路径）。  
  2. 通过 `tasklist | findstr desk_tidy` 检查是否真的有多个 `desk_tidy.exe`；有的话说明某处无效退出或异常。
  3. 临时把 `setLockPath` 改成 `Directory.systemTemp`，确认锁定逻辑正常后再切回 `LOCALAPPDATA`。

### 测试
- 关闭所有 Desk Tidy 实例后，先运行 `flutter run -d windows` 或双击可执行，保证托盘/窗口出现。
- 再次双击或 `flutter run`，确认第二个进程退出且第一进程被唤起（托盘图标不增加）。

