# Windows 打包（Inno Setup）

本指南提供 Inno Setup 脚本及打包步骤，用于生成 Windows 安装包。

## 准备
- 安装 Inno Setup（确保 `iscc` 在 PATH 中）。
- 先生成 Windows Release 构建：`fvm flutter build windows --release`  
  输出目录默认：`build/windows/x64/runner/Release`

## 打包
脚本位置：`installers/desk_tidy.iss`

常用命令（在仓库根目录执行）：
```powershell
# 使用 pubspec 版本号（去掉 +build 号，示例 1.0.0）
$ver = "1.0.0"
iscc installers\desk_tidy.iss /dMyAppVersion=$ver
```

可选参数：
- `MyAppVersion`：安装包版本号（默认 1.0.0；Inno 不接受 `+`，需手动去掉 build 元信息）。
- `MyBuildDir`：构建输出目录（默认 `build\windows\x64\runner\Release`）。
- `MyOutputDir`：安装包输出目录（默认 `build\installer`）。

运行后生成文件：
- `build/installer/desk_tidy_setup.exe`

## 脚本要点
- 使用项目图标 `windows/runner/resources/app_icon.ico`。
- 安装内容来自构建输出目录，递归拷贝，排除 `.pdb`。
- 创建开始菜单及可选桌面快捷方式，安装后可选运行。

如需修改发布者名称、URL 或输出文件名，可直接编辑 `installers/desk_tidy.iss` 顶部的宏或 `[Setup]` 段。
