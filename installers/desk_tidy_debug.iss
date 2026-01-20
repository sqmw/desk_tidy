#ifndef MyAppName
  #define MyAppName "Desk Tidy"
#endif

#ifndef MyAppVersion
  ; Override via: iscc installers\desk_tidy_debug.iss /dMyAppVersion=1.0.0
  #define MyAppVersion "1.0.3"
#endif

; DEBUG版本：使用Debug目录
#ifndef MyBuildDir
  #define MyBuildDir "..\build\windows\x64\runner\Debug"
#endif

#ifndef MyBoxBuildDir
  #define MyBoxBuildDir "f:\language\dart\code\desk_tidy_box\build\windows\x64\runner\Debug"
#endif

#ifndef MyOutputDir
  #define MyOutputDir "build\installer"
#endif

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Desk Tidy
AppPublisherURL=https://example.com
DefaultDirName={commonpf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#MyOutputDir}
OutputBaseFilename=desk_tidy_debug_setup
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\desk_tidy.exe
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Main App (Desk Tidy) - Debug Build
Source: "{#MyBuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion; Excludes: "*.pdb,*.msix,*.lib,*.exp"

; Box App (Desk Tidy Box) - Debug Build, Isolated Install
Source: "{#MyBoxBuildDir}\*"; DestDir: "{app}\box"; Flags: recursesubdirs ignoreversion; Excludes: "*.pdb,*.msix,*.lib,*.exp"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\desk_tidy.exe"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\desk_tidy.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\desk_tidy.exe"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
