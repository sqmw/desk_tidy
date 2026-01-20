; Desk Tidy Pure Release Installer (Optimized for Size)
; This script packages both desk_tidy and desk_tidy_box using pure Release components.
; Identical files (like flutter_windows.dll) use shared sources to minimize installer size.

#define MyAppName "Desk Tidy"
#define MyAppVersion "1.2.0"
#define MyAppPublisher "Antigravity"
#define MyAppExeName "desk_tidy.exe"

#ifndef MyReleaseBuildDir
  #define MyReleaseBuildDir "f:\language\dart\code\desk_tidy\build\windows\x64\runner\Release"
#endif

#ifndef MyBoxBuildDir
  #define MyBoxBuildDir "f:\language\dart\code\desk_tidy_box\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{D35K-T1DY-R3L3-A53-RE3R-F1XED}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=build\installer
OutputBaseFilename=desk_tidy_pure_release_setup
SetupIconFile=f:\language\dart\code\desk_tidy\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; 强制 64 位模式
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; --- Main App (Root) ---
Source: "{#MyReleaseBuildDir}\desk_tidy.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseBuildDir}\data\*"; DestDir: "{app}\data"; Flags: recursesubdirs ignoreversion
; Engine & Common Plugins for Main App
Source: "{#MyReleaseBuildDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseBuildDir}\screen_retriever_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseBuildDir}\system_tray_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseBuildDir}\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseBuildDir}\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion

; --- Box App (Subfolder) ---
Source: "{#MyBoxBuildDir}\desk_tidy_box.exe"; DestDir: "{app}\box"; Flags: ignoreversion
Source: "{#MyBoxBuildDir}\data\*"; DestDir: "{app}\box\data"; Flags: recursesubdirs ignoreversion
; Reuse shared source files to minimize installer size (Inno Setup deduplicates same source)
Source: "{#MyReleaseBuildDir}\flutter_windows.dll"; DestDir: "{app}\box"; Flags: ignoreversion
Source: "{#MyBoxBuildDir}\screen_retriever_plugin.dll"; DestDir: "{app}\box"; Flags: ignoreversion
Source: "{#MyBoxBuildDir}\window_manager_plugin.dll"; DestDir: "{app}\box"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{group}\Desk Tidy Box"; Filename: "{app}\box\desk_tidy_box.exe"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
