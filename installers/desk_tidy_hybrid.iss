; Hybrid Installer: Release app + Debug flutter_windows.dll
; Workaround for Flutter engine rendering bug in Release mode

#ifndef MyAppName
  #define MyAppName "Desk Tidy"
#endif

#ifndef MyAppVersion
  #define MyAppVersion "1.0.3"
#endif

; Use Release build directory for most files
#define MyReleaseBuildDir "..\build\windows\x64\runner\Release"

; Use Debug build directory for flutter_windows.dll only
#define MyDebugBuildDir "..\build\windows\x64\runner\Debug"

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
OutputBaseFilename=desk_tidy_hybrid_setup
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
; Main App - Release build (all files EXCEPT flutter_windows.dll)
Source: "{#MyReleaseBuildDir}\desk_tidy.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseBuildDir}\data\*"; DestDir: "{app}\data"; Flags: recursesubdirs ignoreversion
Source: "{#MyReleaseBuildDir}\screen_retriever_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseBuildDir}\system_tray_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseBuildDir}\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseBuildDir}\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion

; Use Debug flutter_windows.dll (fixes rendering bug)
Source: "{#MyDebugBuildDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion

; Box App - Debug build (isolated)
Source: "{#MyBoxBuildDir}\*"; DestDir: "{app}\box"; Flags: recursesubdirs ignoreversion; Excludes: "*.pdb,*.msix,*.lib,*.exp"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\desk_tidy.exe"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\desk_tidy.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\desk_tidy.exe"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
