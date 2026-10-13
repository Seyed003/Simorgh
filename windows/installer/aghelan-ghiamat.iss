; Windows installer (Inno Setup 6). Built by CI:
;   ISCC.exe /DAppVersion=0.2.0 windows\installer\aghelan-ghiamat.iss
; after `flutter build windows --release`.
;
; The app runs as administrator (TUN needs it), so it belongs in Program
; Files: only administrators can change files there. Run from an unzipped
; folder, any program of the user could swap a DLL or the core and have it
; run elevated the next time the app starts.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppName "Aghelan Ghiamat"
#define AppExe "aghelan_ghiamat.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
; Never change: Windows identifies installed versions (updates, uninstall)
; by it.
AppId={{00aeb273-b3a0-4ec3-945a-baff4404f400}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Aghelan Ghiamat
AppPublisherURL=https://github.com/seyed003/aghelan-ghiamat
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
LicenseFile=..\..\LICENSE
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
OutputDir=..\..\build\installer
OutputBaseFilename=aghelan-ghiamat-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; A running app (and its core) is closed before its files are replaced.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

; Configs and settings live in the user's profile and stay after an
; uninstall (a later install finds them again).
