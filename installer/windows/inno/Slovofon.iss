#define AppName "Slovofon"
#define AppPublisher "Slovofon Team"
#define AppVersion GetEnv("SLOVOFON_APP_VERSION")
#define SourceDir GetEnv("SLOVOFON_SOURCE_DIR")
#define OutputDir GetEnv("SLOVOFON_OUTPUT_DIR")
#define OutputBaseFilename GetEnv("SLOVOFON_OUTPUT_BASE")
#define IconPath GetEnv("SLOVOFON_ICON_PATH")
#if VER < EncodeVer(6, 6, 0)
  #error "Slovofon Setup requires Inno Setup 6.6 or newer (DPI-aware light/dark wizard)."
#endif

; The shared release bundle must already include the compiler redistributables.
; Full import validation runs before packaging in the release workflow.
#if !FileExists(SourceDir + "\msvcp140.dll") || !FileExists(SourceDir + "\vcruntime140.dll") || !FileExists(SourceDir + "\vcruntime140_1.dll")
  #error "Missing app-local MSVC runtime. Build the complete Windows release bundle first."
#endif

[Setup]
#ifdef SLOVOFON_QA_PREVIEW
AppId={{20E99330-EF3A-46D3-BD7C-D4DE682B52C0}
#else
AppId={{C8CE9579-9F96-40B5-A58C-9726E9F76F89}
#endif
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/Dushnyj/Slovofon
AppSupportURL=https://github.com/Dushnyj/Slovofon/issues
AppUpdatesURL=https://github.com/Dushnyj/Slovofon/releases
DefaultDirName={autopf}\Slovofon
DefaultGroupName=Slovofon
DisableProgramGroupPage=auto
DisableDirPage=no
DisableWelcomePage=no
UsePreviousAppDir=yes
UsePreviousTasks=yes
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile={#IconPath}
UninstallDisplayIcon={app}\Slovofon.exe
UninstallDisplayName={#AppName}
Uninstallable=yes
VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription=Slovofon Setup
VersionInfoCopyright=Copyright (c) Slovofon Team
Compression=lzma2/ultra64
SolidCompression=yes
#if defined(SLOVOFON_QA_PREVIEW) && defined(SLOVOFON_QA_LIGHT)
WizardStyle=modern light windows11
#else
WizardStyle=modern dynamic windows11
#endif
WizardSizePercent=120,120
WizardImageFile=..\assets\inno-sidebar.png
WizardImageFileDynamicDark=..\assets\inno-sidebar.png
WizardSmallImageFile=..\assets\app-icon.png
WizardSmallImageFileDynamicDark=..\assets\app-icon.png
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline dialog
CloseApplications=yes
CloseApplicationsFilter=*.exe,*.dll
RestartApplications=no
ChangesAssociations=no
ChangesEnvironment=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[LangOptions]
DialogFontName=Segoe UI
DialogFontSize=10
WelcomeFontName=Segoe UI
WelcomeFontSize=18

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "*.pdb"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Slovofon"; Filename: "{app}\Slovofon.exe"; WorkingDir: "{app}"; AppUserModelID: "Slovofon.App"
Name: "{autodesktop}\Slovofon"; Filename: "{app}\Slovofon.exe"; WorkingDir: "{app}"; AppUserModelID: "Slovofon.App"; Tasks: desktopicon

[Run]
Filename: "{app}\Slovofon.exe"; Description: "{cm:LaunchProgram,Slovofon}"; Flags: nowait postinstall skipifsilent runasoriginaluser unchecked

[Messages]
english.WizardSelectTasks=Shortcuts
english.SelectTasksDesc=Choose how to open Slovofon.
english.SelectTasksLabel2=A Start menu shortcut is included. You can also create a desktop shortcut.
russian.WizardSelectTasks=Ярлыки
russian.SelectTasksDesc=Выберите, как открывать Словофон.
russian.SelectTasksLabel2=Ярлык в меню «Пуск» будет создан. При желании добавьте ярлык на рабочий стол.
russian.PrivilegesRequiredOverrideText1=Программу %1 можно установить для всех пользователей (потребуются права администратора) или только для вас.
russian.PrivilegesRequiredOverrideText2=Программу %1 можно установить только для вас или для всех пользователей (потребуются права администратора).
english.WelcomeLabel1=Install Slovofon
english.WelcomeLabel2=Choose where to install Slovofon and which shortcuts to create.%n%nYour books, settings and listening progress are kept when updating or uninstalling.%n%nVersion {#AppVersion}  |  Windows 10 / 11
russian.WelcomeLabel1=Установка Словофона
russian.WelcomeLabel2=Выберите папку установки и нужные ярлыки.%n%nПри обновлении и удалении программы ваши книги, настройки и прогресс прослушивания сохраняются.%n%nВерсия {#AppVersion}  |  Windows 10 / 11
english.FinishedLabel=Slovofon is installed. Open it from the Start menu.%n%nTo uninstall, open Windows Settings > Apps > Installed apps (Apps & features in Windows 10). Your books and progress will be kept.
russian.FinishedLabel=Словофон установлен. Откройте его из меню «Пуск».%n%nДля удаления: Параметры Windows → Приложения → Установленные приложения (в Windows 10 — «Приложения и возможности»). Книги и прогресс сохранятся.
english.ConfirmUninstall=Remove %1 from this computer?%n%nOnly the application and its shortcuts will be removed. Your downloaded books, settings, history, bookmarks and listening progress will be kept.
russian.ConfirmUninstall=Удалить %1 с этого компьютера?%n%nБудут удалены только программа и её ярлыки. Скачанные книги, настройки, история, закладки и прогресс прослушивания сохранятся.

[CustomMessages]
english.CreateDesktopIcon=Create a &desktop shortcut
russian.CreateDesktopIcon=Создать &ярлык на рабочем столе
english.AdditionalIcons=Shortcuts:
russian.AdditionalIcons=Ярлыки:
english.ScopeAll=Installation mode: all users
russian.ScopeAll=Режим установки: для всех пользователей
english.ScopeMe=Installation mode: only for me
russian.ScopeMe=Режим установки: только для меня
english.MsiConflict=Slovofon was installed with an MSI package. Update it using the MSI file from the official GitHub Releases, not this Setup EXE. To switch formats, first uninstall the existing app in Windows Settings. Your books and progress are kept.
russian.MsiConflict=Словофон установлен из MSI. Для обновления используйте MSI-файл из официальных GitHub Releases, а не этот Setup EXE. Чтобы сменить формат, сначала удалите установленную программу через параметры Windows. Книги и прогресс сохранятся.
english.ScopeConflict=Slovofon is already installed in the other installation mode. Run Setup in the same mode (only for me / all users) to update it. To change the mode, first uninstall the existing app in Windows Settings. Your books and progress are kept.
russian.ScopeConflict=Словофон уже установлен в другом режиме. Для обновления запустите установщик в том же режиме («Только для меня» / «Для всех пользователей»). Чтобы изменить режим, сначала удалите программу через параметры Windows. Книги и прогресс сохранятся.
english.NewerVersion=A newer version of Slovofon (%1) is already installed. Installing {#AppVersion} over it is blocked to protect your data. Use the same or a newer version.
russian.NewerVersion=Уже установлена более новая версия Словофона (%1). Установка {#AppVersion} поверх неё заблокирована для защиты данных. Используйте такую же или более новую версию.
english.InvalidVersion=The installed Slovofon version could not be verified. Setup will not overwrite it. Check the installed version in Windows Settings first.
russian.InvalidVersion=Не удалось проверить версию установленного Словофона. Установщик не будет перезаписывать её. Сначала проверьте установленную версию в параметрах Windows.
english.DataKept=Books, settings and listening progress will be kept.
russian.DataKept=Книги, настройки и прогресс прослушивания сохранятся.

[Code]
const
  UninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{C8CE9579-9F96-40B5-A58C-9726E9F76F89}_is1';

function CheckInstalledVersion(const Version: String): String;
var
  Installed, Incoming: Int64;
begin
  Result := '';
  if not StrToVersion(Version, Installed) then
    Result := CustomMessage('InvalidVersion')
  else if not StrToVersion('{#AppVersion}', Incoming) then
    Result := CustomMessage('InvalidVersion')
  else if ComparePackedVersion(Installed, Incoming) > 0 then
    Result := FmtMessage(CustomMessage('NewerVersion'), [Version]);
end;

function GetInstallConflict: String;
var
  CurrentRoot, OtherRoot: Integer;
  InstalledVersion, InstallerType: String;
begin
  Result := '';
  { The stable UpgradeCode also finds MSI releases made before the marker existed. }
  if IsMsiProductInstalled('{9C9D9F71-5A2B-4F6D-8C58-9D4C8D2F8B8C}', 0) or
    (RegQueryStringValue(HKLM64, 'Software\Slovofon\Installer', 'Type', InstallerType) and
      (InstallerType = 'msi')) then begin
    Result := CustomMessage('MsiConflict');
    Exit;
  end;
  if IsAdminInstallMode then begin
    CurrentRoot := HKLM64;
    OtherRoot := HKCU64;
  end else begin
    CurrentRoot := HKCU64;
    OtherRoot := HKLM64;
  end;
  if RegKeyExists(OtherRoot, UninstallKey) then begin
    Result := CustomMessage('ScopeConflict');
    Exit;
  end;
  if RegQueryStringValue(CurrentRoot, UninstallKey, 'DisplayVersion', InstalledVersion) then
    Result := CheckInstalledVersion(InstalledVersion);
end;

function InitializeSetup: Boolean;
var
  Conflict: String;
begin
  Conflict := GetInstallConflict;
  Result := Conflict = '';
  if not Result then
    SuppressibleMsgBox(Conflict, mbError, MB_OK, IDOK);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ExistingVersion: String;
  LastDot: Integer;
begin
  #ifdef SLOVOFON_QA_PREVIEW
  Result := 'QA preview only. Installation is disabled; no application or user data will be changed.';
  Exit;
  #endif
  { Repeat after folder selection: custom directories must not bypass downgrade protection. }
  Result := GetInstallConflict;
  if Result <> '' then Exit;
  if GetVersionNumbersString(ExpandConstant('{app}\Slovofon.exe'), ExistingVersion) then begin
    { Flutter adds buildNumber as the fourth field; compare public MAJOR.MINOR.PATCH. }
    LastDot := Length(ExistingVersion);
    while (LastDot > 0) and (ExistingVersion[LastDot] <> '.') do LastDot := LastDot - 1;
    Result := CheckInstalledVersion(Copy(ExistingVersion, 1, LastDot - 1));
  end;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo,
  MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  if IsAdminInstallMode then Result := CustomMessage('ScopeAll')
  else Result := CustomMessage('ScopeMe');
  Result := Result + NewLine + NewLine + MemoDirInfo + NewLine + NewLine + MemoGroupInfo;
  if MemoTasksInfo <> '' then Result := Result + NewLine + NewLine + MemoTasksInfo;
  Result := Result + NewLine + NewLine + CustomMessage('DataKept');
end;
