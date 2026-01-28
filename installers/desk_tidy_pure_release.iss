; Desk Tidy Pure Release Installer (Optimized for Size & Upgrade Flow)
; This script packages both desk_tidy and desk_tidy_box using pure Release components.
; Features: 
; 1. Process Detection/Killing (desk_tidy.exe & desk_tidy_box.exe)
; 2. Automatic Uninstallation of previous versions before install.
; 3. Shared source deduplication for smaller installer size.

#define MyAppName "Desk Tidy"
#define MyAppVersion "1.2.7"
#define MyAppPublisher "Antigravity"
#define MyAppExeName "desk_tidy.exe"
#define MyAppId "{{D35K-T1DY-R3L3-A53-RE3R-F1XED}}"

#ifndef MyReleaseBuildDir
  #define MyReleaseBuildDir "f:\language\dart\code\desk_tidy\build\windows\x64\runner\Release"
#endif

#ifndef MyBoxBuildDir
  #define MyBoxBuildDir "f:\language\dart\code\desk_tidy_box\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={#MyAppId}
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
; 关闭应用检测
CloseApplications=yes
RestartApplications=yes

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
Source: "{#MyReleaseBuildDir}\video_player_win_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion

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

[Code]
// 自动卸载旧版本的函数
function GetUninstallString(): String;
var
  sUninstPath: String;
  sUninstString: String;
begin
  sUninstPath := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + '{#MyAppId}' + '_is1';
  sUninstString := '';
  if not RegQueryStringValue(HKLM, sUninstPath, 'UninstallString', sUninstString) then
    RegQueryStringValue(HKCU, sUninstPath, 'UninstallString', sUninstString);
  Result := sUninstString;
end;

function IsUpgrade(): Boolean;
begin
  Result := (GetUninstallString() <> '');
end;

function InitializeSetup(): Boolean;
var
  V: Integer;
  iResultCode: Integer;
  sUninstString: String;
begin
  Result := True;
  
  // 1. 检查并关闭正在运行的进程
  // 使用 taskkill 强制关闭 (保险做法)
  ShellExec('open', 'taskkill.exe', '/f /im desk_tidy.exe /t', '', SW_HIDE, ewWaitUntilTerminated, iResultCode);
  ShellExec('open', 'taskkill.exe', '/f /im desk_tidy_box.exe /t', '', SW_HIDE, ewWaitUntilTerminated, iResultCode);

  // 2. 如果存在旧版本，提示或直接静默卸载
  if IsUpgrade() then
  begin
    sUninstString := GetUninstallString();
    // 移除引号
    StringChangeEx(sUninstString, '"', '', True);
    
    // 静默执行卸载程序
    if MsgBox('检测到已安装旧版本，是否先自动卸载旧版本？', mbConfirmation, MB_YESNO) = IDYES then
    begin
      if not Exec(sUninstString, '/SILENT /VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE, ewWaitUntilTerminated, iResultCode) then
      begin
        MsgBox('卸载旧版本失败，请手动卸载后再试。错误码：' + IntToStr(iResultCode), mbError, MB_OK);
        Result := False;
      end;
    end;
  end;
end;
