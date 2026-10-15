[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL=https://github.com/Zolmid/FlClash/releases/latest
DefaultDirName={{INSTALL_DIR_NAME}}
DisableProgramGroupPage=yes
CloseApplications=no
RestartApplications=no
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
UninstallDisplayIcon={app}\{{EXECUTABLE_NAME}}
WizardStyle=modern
PrivilegesRequired={{PRIVILEGES_REQUIRED}}
ArchitecturesAllowed={{ARCH}}
ArchitecturesInstallIn64BitMode={{ARCH}}

[Code]
var
  UpdateProcessHandle: THandle;

function OpenProcess(DesiredAccess: LongWord; InheritHandle: Boolean;
  ProcessId: LongWord): THandle;
  external 'OpenProcess@kernel32.dll stdcall';
function WaitForSingleObject(Handle: THandle; Milliseconds: LongWord): LongWord;
  external 'WaitForSingleObject@kernel32.dll stdcall';
function CloseHandle(Handle: THandle): Boolean;
  external 'CloseHandle@kernel32.dll stdcall';
function QueryFullProcessImageName(Handle: THandle; Flags: LongWord;
  FileName: String; var Size: LongWord): Boolean;
  external 'QueryFullProcessImageNameW@kernel32.dll stdcall';

function CreateReadyFile(FileName: String; DesiredAccess, ShareMode,
  SecurityAttributes, CreationDisposition, FlagsAndAttributes: LongWord;
  TemplateFile: THandle): THandle;
  external 'CreateFileW@kernel32.dll stdcall';
function WriteReadyFile(Handle: THandle; Buffer: AnsiString;
  BytesToWrite: LongWord; var BytesWritten: LongWord;
  Overlapped: LongWord): Boolean;
  external 'WriteFile@kernel32.dll stdcall';

procedure KillProcesses;
var
  Processes: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  Processes := ['FlClash.exe', 'FlClashCore.exe', 'FlClashHelperService.exe'];

  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    Exec('taskkill', '/f /im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure UnregisterHelperService;
var
  HelperPath: String;
  ResultCode: Integer;
begin
  HelperPath := ExpandConstant('{app}\\FlClashHelperService.exe');
  if FileExists(HelperPath) then
  begin
    Exec(HelperPath, 'uninstall', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure ClearStaleProxy(AsOriginalUser: Boolean);
var
  AppPath: String;
  ResultCode: Integer;
begin
  AppPath := ExpandConstant('{app}\\{{EXECUTABLE_NAME}}');
  if FileExists(AppPath) then
  begin
    if AsOriginalUser then
      ExecAsOriginalUser(AppPath, '--clear-stale-proxy', '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
    else
      Exec(AppPath, '--clear-stale-proxy', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

function PointsIntoApp(Value: String): Boolean;
begin
  Result := Pos(Lowercase(AddBackslash(ExpandConstant('{app}'))), Lowercase(Value)) > 0;
end;

// The value name is appName and the schemes are protocolSchemes, both in
// lib/common.
procedure RemoveUserRegistrations;
var
  Schemes: TArrayOfString;
  Value: String;
  i: Integer;
begin
  if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', '{{APP_NAME}}', Value) and PointsIntoApp(Value) then
  begin
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', '{{APP_NAME}}');
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run', '{{APP_NAME}}');
  end;

  Schemes := ['clash', 'clashmeta', 'flclash'];
  for i := 0 to GetArrayLength(Schemes)-1 do
  begin
    if RegQueryStringValue(HKCU, 'Software\Classes\' + Schemes[i] + '\shell\open\command', '', Value) and PointsIntoApp(Value) then
    begin
      RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\' + Schemes[i]);
    end;
  end;
end;

function IsAppUpdate: Boolean;
begin
  Result := ExpandConstant('{param:UPDATE|0}') = '1';
end;

function SignalUpdateReady: Boolean;
var
  ReadyFile, TemporaryReadyFile, Nonce, ProcessIdText, ProcessPath: String;
  ProcessId, PathSize, BytesWritten: LongWord;
  ReadyHandle: THandle;
  i: Integer;
begin
  Result := False;
  ReadyFile := ExpandConstant('{param:UPDATEREADY|}');
  Nonce := ExpandConstant('{param:UPDATENONCE|}');
  ProcessIdText := ExpandConstant('{param:UPDATEPID|}');
  if (ReadyFile = '') or
     (CompareText(ReadyFile, ExpandConstant('{srcexe}') + '.' + Nonce + '.ready') <> 0) or
     FileExists(ReadyFile) or FileExists(ReadyFile + '.ack') or
     (Length(Nonce) <> 64) then
    Exit;
  for i := 1 to Length(Nonce) do
    if Pos(Lowercase(Nonce[i]), '0123456789abcdef') = 0 then
      Exit;
  ProcessId := StrToIntDef(ProcessIdText, 0);
  if ProcessId = 0 then
    Exit;
  UpdateProcessHandle := OpenProcess($00101000, False, ProcessId);
  if UpdateProcessHandle = 0 then
    Exit;
  PathSize := 32768;
  ProcessPath := StringOfChar(#0, PathSize);
  if not QueryFullProcessImageName(UpdateProcessHandle, 0, ProcessPath, PathSize) then
    Exit;
  SetLength(ProcessPath, PathSize);
  if CompareText(ProcessPath, ExpandConstant('{app}\{{EXECUTABLE_NAME}}')) <> 0 then
    Exit;
  TemporaryReadyFile := ReadyFile + '.tmp';
  ReadyHandle := CreateReadyFile(TemporaryReadyFile, $40000000, 0, 0, 1, $80, 0);
  if ReadyHandle = THandle(-1) then
    Exit;
  try
    Result := WriteReadyFile(ReadyHandle, AnsiString(Nonce), Length(Nonce),
      BytesWritten, 0) and (BytesWritten = Length(Nonce));
  finally
    CloseHandle(ReadyHandle);
  end;
  if Result then
    Result := RenameFile(TemporaryReadyFile, ReadyFile);
  if not Result then
    DeleteFile(TemporaryReadyFile);
end;

function WaitForParentAcknowledgement: Boolean;
var
  AcknowledgementFile, Nonce: String;
  Contents: AnsiString;
  i: Integer;
begin
  Result := False;
  AcknowledgementFile := ExpandConstant('{param:UPDATEREADY|}') + '.ack';
  Nonce := ExpandConstant('{param:UPDATENONCE|}');
  for i := 1 to 150 do
  begin
    if FileExists(AcknowledgementFile) then
    begin
      if LoadStringFromFile(AcknowledgementFile, Contents) then
        Result := String(Contents) = Nonce;
      Exit;
    end;
    if WaitForSingleObject(UpdateProcessHandle, 0) <> 258 then
      Exit;
    Sleep(200);
  end;
end;

function WaitForAppExit: Boolean;
begin
  Result := WaitForSingleObject(UpdateProcessHandle, 60000) = 0;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if IsAppUpdate then
  begin
    UpdateProcessHandle := 0;
    try
      if not SignalUpdateReady then
      begin
        Result := 'Unable to acknowledge the update request after elevation.';
        Exit;
      end;
      if not WaitForParentAcknowledgement then
      begin
        Result := 'The application did not confirm this update request.';
        Exit;
      end;
      if not WaitForAppExit then
      begin
        Result := 'FlClash did not exit. Close it before retrying the update.';
        Exit;
      end;
    finally
      if UpdateProcessHandle <> 0 then
        CloseHandle(UpdateProcessHandle);
      UpdateProcessHandle := 0;
    end;
  end;
  UnregisterHelperService;
  if not IsAppUpdate then
    KillProcesses;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    ClearStaleProxy(True);
  end;
end;

function InitializeUninstall(): Boolean;
begin
  UnregisterHelperService;
  ClearStaleProxy(False);
  KillProcesses;
  ClearStaleProxy(False);
  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    RemoveUserRegistrations;
  end;
end;

[Languages]
{% for locale in LOCALES %}
{% if locale.lang == 'en' %}Name: "english"; MessagesFile: "compiler:Default.isl"{% endif %}
{% if locale.lang == 'hy' %}Name: "armenian"; MessagesFile: "compiler:Languages\\Armenian.isl"{% endif %}
{% if locale.lang == 'bg' %}Name: "bulgarian"; MessagesFile: "compiler:Languages\\Bulgarian.isl"{% endif %}
{% if locale.lang == 'ca' %}Name: "catalan"; MessagesFile: "compiler:Languages\\Catalan.isl"{% endif %}
{% if locale.lang == 'zh' %}
Name: "chineseSimplified"; MessagesFile: {% if locale.file %}"{{ locale.file }}"{% else %}"compiler:Languages\\ChineseSimplified.isl"{% endif %}
{% endif %}
{% if locale.lang == 'zh_TW' %}Name: "chineseTraditional"; MessagesFile: "{{ locale.file }}"{% endif %}
{% if locale.lang == 'co' %}Name: "corsican"; MessagesFile: "compiler:Languages\\Corsican.isl"{% endif %}
{% if locale.lang == 'cs' %}Name: "czech"; MessagesFile: "compiler:Languages\\Czech.isl"{% endif %}
{% if locale.lang == 'da' %}Name: "danish"; MessagesFile: "compiler:Languages\\Danish.isl"{% endif %}
{% if locale.lang == 'nl' %}Name: "dutch"; MessagesFile: "compiler:Languages\\Dutch.isl"{% endif %}
{% if locale.lang == 'fi' %}Name: "finnish"; MessagesFile: "compiler:Languages\\Finnish.isl"{% endif %}
{% if locale.lang == 'fr' %}Name: "french"; MessagesFile: "compiler:Languages\\French.isl"{% endif %}
{% if locale.lang == 'de' %}Name: "german"; MessagesFile: "compiler:Languages\\German.isl"{% endif %}
{% if locale.lang == 'he' %}Name: "hebrew"; MessagesFile: "compiler:Languages\\Hebrew.isl"{% endif %}
{% if locale.lang == 'is' %}Name: "icelandic"; MessagesFile: "compiler:Languages\\Icelandic.isl"{% endif %}
{% if locale.lang == 'it' %}Name: "italian"; MessagesFile: "compiler:Languages\\Italian.isl"{% endif %}
{% if locale.lang == 'ja' %}Name: "japanese"; MessagesFile: "compiler:Languages\\Japanese.isl"{% endif %}
{% if locale.lang == 'no' %}Name: "norwegian"; MessagesFile: "compiler:Languages\\Norwegian.isl"{% endif %}
{% if locale.lang == 'pl' %}Name: "polish"; MessagesFile: "compiler:Languages\\Polish.isl"{% endif %}
{% if locale.lang == 'pt' %}Name: "portuguese"; MessagesFile: "compiler:Languages\\Portuguese.isl"{% endif %}
{% if locale.lang == 'ru' %}Name: "russian"; MessagesFile: "compiler:Languages\\Russian.isl"{% endif %}
{% if locale.lang == 'sk' %}Name: "slovak"; MessagesFile: "compiler:Languages\\Slovak.isl"{% endif %}
{% if locale.lang == 'sl' %}Name: "slovenian"; MessagesFile: "compiler:Languages\\Slovenian.isl"{% endif %}
{% if locale.lang == 'es' %}Name: "spanish"; MessagesFile: "compiler:Languages\\Spanish.isl"{% endif %}
{% if locale.lang == 'tr' %}Name: "turkish"; MessagesFile: "compiler:Languages\\Turkish.isl"{% endif %}
{% if locale.lang == 'uk' %}Name: "ukrainian"; MessagesFile: "compiler:Languages\\Ukrainian.isl"{% endif %}
{% endfor %}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}
[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon
[Run]
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: {% if PRIVILEGES_REQUIRED == 'admin' %}runascurrentuser{% endif %} nowait postinstall skipifsilent
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Flags: runasoriginaluser nowait; Check: IsAppUpdate
