#ifndef MyAppName
  #define MyAppName "Desk Tidy"
#endif

#ifndef MyAppVersion
  // Override via: iscc installers\desk_tidy.iss /dMyAppVersion=1.0.0
  #define MyAppVersion "1.0.3"
#endif

#ifndef MyBuildDir
  // Override via: iscc installers\desk_tidy.iss /dMyBuildDir=..\\build\\windows\\x64\\runner\\Release
  #define MyBuildDir "..\\build\\windows\\x64\\runner\\Release"
#endif

#ifndef MyOutputDir
  #define MyOutputDir "build\\installer"
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
OutputBaseFilename=desk_tidy_setup
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
; Build output (ensure flutter build windows --release ran first)
Source: "{#MyBuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion; Excludes: "*.pdb,*.msix"

[Icons]
Name: "{group}\\{#MyAppName}"; Filename: "{app}\\desk_tidy.exe"
Name: "{commondesktop}\\{#MyAppName}"; Filename: "{app}\\desk_tidy.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\\desk_tidy.exe"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
