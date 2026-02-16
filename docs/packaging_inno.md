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
## 优化版打包脚本 ( desk_tidy_pure_release.iss )

该脚本专为同时打包主程序 (`desk_tidy`) 和盒子程序 (`desk_tidy_box`) 设计，并进行了体积优化。

### 核心优化：共享源文件去重 (Shared Source Deduplication)

由于主程序和盒子程序都依赖于 Flutter 引擎文件（如 `flutter_windows.dll`），如果在两个目录分别打包，安装包体积会显著增大。

- **逻辑**：在该脚本中，主程序和盒子程序引用**同一个源路径**下的引擎文件：
  ```pascal
  ; 主程序引用
  Source: "{#MyReleaseBuildDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
  ; 盒子程序重用相同源文件
  Source: "{#MyReleaseBuildDir}\flutter_windows.dll"; DestDir: "{app}\box"; Flags: ignoreversion
  ```
- **打包表现**：Inno Setup 会识别出两个条目指向同一个物理文件，在生成的 `.exe` 中**仅压缩存储一份**数据。
- **安装表现**：安装程序在运行过程中，会将该文件**分别解压并复制**到对应的两个文件夹中，确保两个程序都能正常加载引擎。

### 注意事项
- 编译前需确保主程序和子程序都已经完成 `release` 构建。
- 子程序必须在安装目录下有自己的依赖副本（即使是重复的），因为 Windows 的加载机制要求 DLL 与 EXE 同级。

### 产物命名与 Git 跟踪策略（2026-02-16）
- `installers/desk_tidy_pure_release.iss` 已改为按版本号输出安装包：
  - `OutputBaseFilename=desk_tidy_pure_release_setup_v{#MyAppVersion}`
- 例如 `MyAppVersion=1.2.10` 时，输出文件名为：
  - `desk_tidy_pure_release_setup_v1.2.10.exe`
- `MyAppVersion` 支持命令行覆盖（如 `/DMyAppVersion=1.2.11`），便于发布时不改脚本直接变更版本号。
- 仓库根目录 `.gitignore` 已新增：`/installers/build/`，防止安装包产物进入版本库。
- 若历史上已被跟踪过安装包，需要一次性执行：
  ```powershell
  git rm -r --cached installers/build
  ```
