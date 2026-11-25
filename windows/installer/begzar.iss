; Begzar Windows installer (Inno Setup 6+)
; Compiled by scripts/build_windows_release.ps1 with /D defines.

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#ifndef MyAppBuild
  #define MyAppBuild "0"
#endif

#ifndef MyReleaseDir
  #define MyReleaseDir "..\..\build\windows\x64\runner\Release"
#endif

#ifndef MyOutputDir
  #define MyOutputDir "..\..\dist"
#endif

#define MyAppName "Begzar"
#define MyAppExeName "begzar.exe"
#define MyAppPublisher "Begzar"
#define MyAppURL "https://begzar.cloud"

[Setup]
AppId={{A8F3C2E1-7B94-4D6A-9E21-5C0F8B1A2D33}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#MyOutputDir}
OutputBaseFilename=Begzar-{#MyAppVersion}+{#MyAppBuild}-Windows-Setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
; A running Begzar, tray included, is asked to quit first; force ends it when it
; cannot answer, as builds from before the app handled WM_ENDSESSION do not.
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
// Restart Manager cannot close Begzar while the Tunnel helper runs: the helper
// is elevated and Setup is not, so the check for running apps fails with
// permission denied and Setup closes nothing. Setup therefore asks the app to
// quit itself first. The helper's lease closes with the app, which ends it.

const
  WM_ENDSESSION = $0016;
  // The flag Restart Manager itself sends, so the app sees the same request.
  ENDSESSION_CLOSEAPP = $1;
  // The class is shared by every Flutter app; the title is what makes it ours.
  AppWindowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';
  AppWindowTitle = 'BegzarVPN';
  HelperExeName = 'begzar-tun.exe';
  PollIntervalMs = 100;
  // A build that answers WM_ENDSESSION quits in well under a second.
  AppQuitTimeoutMs = 3000;
  // The helper exits within a second of its lease closing.
  HelperExitTimeoutMs = 10000;

function FindWindowW(ClassName, WindowName: String): HWND;
  external 'FindWindowW@user32.dll stdcall';
function GetWindowThreadProcessId(Window: HWND; var ProcessId: DWORD): DWORD;
  external 'GetWindowThreadProcessId@user32.dll stdcall';

function AppWindow: HWND;
begin
  Result := FindWindowW(AppWindowClass, AppWindowTitle);
end;

function WaitForAppWindowToClose: Boolean;
var
  Waited: Integer;
begin
  Waited := 0;
  while (AppWindow <> 0) and (Waited < AppQuitTimeoutMs) do
  begin
    Sleep(PollIntervalMs);
    Waited := Waited + PollIntervalMs;
  end;
  Result := AppWindow = 0;
end;

function IsHelperRunning: Boolean;
var
  ResultCode: Integer;
begin
  // find exits 0 only when tasklist printed the helper's name.
  Result := Exec(ExpandConstant('{cmd}'),
    '/C tasklist /NH /FI "IMAGENAME eq ' + HelperExeName + '" | find /I "' +
    HelperExeName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and
    (ResultCode = 0);
end;

procedure EndAppProcess(Window: HWND);
var
  ProcessId: DWORD;
  ResultCode: Integer;
begin
  ProcessId := 0;
  GetWindowThreadProcessId(Window, ProcessId);
  if ProcessId <> 0 then
    Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /PID ' + IntToStr(ProcessId),
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

procedure WaitForHelperToExit;
var
  Waited: Integer;
begin
  Waited := 0;
  while IsHelperRunning and (Waited < HelperExitTimeoutMs) do
  begin
    Sleep(PollIntervalMs);
    Waited := Waited + PollIntervalMs;
  end;
end;

procedure CloseRunningApp;
var
  Window: HWND;
begin
  Window := AppWindow;
  if Window = 0 then
    Exit;

  PostMessage(Window, WM_ENDSESSION, 1, ENDSESSION_CLOSEAPP);
  // A build from before the app answered WM_ENDSESSION ignores it, so it is
  // ended instead; on its next launch the app repairs the proxy it left on.
  if not WaitForAppWindowToClose then
  begin
    EndAppProcess(Window);
    WaitForAppWindowToClose;
  end;
  WaitForHelperToExit;
end;

// Runs before Setup checks for files in use, so the check finds nothing to
// close and Restart Manager stays a fallback.
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  CloseRunningApp;
  Result := '';
end;
