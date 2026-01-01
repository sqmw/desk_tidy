
# 文件/文件夹操作与复制

## 入口
- “全部”/“文件夹”/“文件”视图右键菜单包含：
  - 打开 / 使用其他应用打开 / 移动到…
  - 删除（回收站）
  - 复制名称 / 复制路径 / 复制所在文件夹
  - **复制到…**（递归复制文件夹，文件直接拷贝）

## 复制实现
- 选择目标目录后，调用 `copyEntityToDirectory(source, targetDir)`：
  - 若目标存在同名项或目标与源相同，直接失败提示。
  - 文件夹复制为递归深拷贝；文件直接 `copy`。
  - 阻止“目标在源内部”的情况，避免无限递归。
  - 成功/失败均弹出 Snackbar 提示。
- 链接：实现位于 `lib/utils/desktop_helper.dart`，菜单触发位于
  - `lib/screens/all_page.dart`
  - `lib/screens/folder_page.dart`
  - `lib/screens/file_page.dart`

## 其他操作
- 移动：右键“移动到…”使用目录选择器后执行 `rename`。
- 删除：调用 `moveToRecycleBin` 发送到回收站。
- 打开：双击或右键“打开”，可选择“使用其他应用打开”挑选可执行文件。
