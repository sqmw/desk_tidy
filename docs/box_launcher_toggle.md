# 桌面盒子启动开关失效修复

## 问题现象
- 启动应用时能拉起 `desk_tidy_box.exe`。
- 在设置页切换“桌面分类盒子”开关后，盒子进程不响应（不启动/不关闭）。

## 影响范围
- 设置页的“桌面分类盒子”开关。

## 根因
- 设置回调仅保存配置，没有触发实际的进程启动/停止逻辑。

## 修复方案
- 在设置回调中调用 `BoxLauncher.updateBoxes`：
  - `enabled=true` 时确保 `folders/files` 盒子进程启动。
  - `enabled=false` 时停止所有盒子进程。

## 关键改动
- `lib/screens/desk_tidy_home_page.dart`：`onEnableDesktopBoxesChanged` 追加调用 `BoxLauncher.instance.updateBoxes(...)`。

## 验证要点
- 在设置页打开开关：`desk_tidy_box.exe` 进程出现并可用。
- 关闭开关：相关进程被结束。
