#define AppName "Slovofon"
#define AppPublisher "Slovofon Team"
#define AppVersion GetEnv("SLOVOFON_APP_VERSION")
#define SourceDir GetEnv("SLOVOFON_SOURCE_DIR")
#define OutputDir GetEnv("SLOVOFON_OUTPUT_DIR")
#define OutputBaseFilename GetEnv("SLOVOFON_OUTPUT_BASE")
#define IconPath GetEnv("SLOVOFON_ICON_PATH")

; The shared release bundle must already include the compiler redistributables.
; Full import validation runs before packaging in the release workflow.
#if !FileExists(SourceDir + "\msvcp140.dll") || !FileExists(SourceDir + "\vcruntime140.dll") || !FileExists(SourceDir + "\vcruntime140_1.dll")
  #error "Missing app-local MSVC runtime. Build the complete Windows release bundle first."
#endif

[Setup]
AppId={{C8CE9579-9F96-40B5-A58C-9726E9F76F89}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://slovofon.duckdns.org
AppSupportURL=https://t.me/slovofon_bot
AppUpdatesURL=https://github.com/Dushnyj/Slovofon/releases
DefaultDirName={autopf}\Slovofon
DefaultGroupName=Slovofon
DisableProgramGroupPage=auto
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile={#IconPath}
UninstallDisplayIcon={app}\Slovofon.exe
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ChangesAssociations=no
ChangesEnvironment=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Slovofon"; Filename: "{app}\Slovofon.exe"
Name: "{autodesktop}\Slovofon"; Filename: "{app}\Slovofon.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Slovofon.exe"; Description: "{cm:LaunchProgram,Slovofon}"; Flags: nowait postinstall skipifsilent
