#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef AppArch
  #define AppArch "x64"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "HLControl-v" + AppVersion + "-windows-" + AppArch + "-setup"
#endif

[Setup]
AppId={{D37E84B1-026B-4D88-82CE-7BD969EAE59B}
AppName=HLControl
AppVersion={#AppVersion}
AppPublisher=Flopster101
AppPublisherURL=https://github.com/Flopster101/HLControl
AppSupportURL=https://github.com/Flopster101/HLControl/issues
AppUpdatesURL=https://github.com/Flopster101/HLControl/releases
DefaultDirName={autopf}\HLControl
DefaultGroupName=HLControl
AllowNoIcons=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
ArchitecturesAllowed={#AppArch == "arm64" ? "arm64" : "x64compatible"}
ArchitecturesInstallIn64BitMode={#AppArch == "arm64" ? "arm64" : "x64compatible"}
CloseApplications=force
RestartApplications=yes
UninstallDisplayIcon={app}\hlcontrol.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Start HLControl in system tray on Windows login"; GroupDescription: "Startup Options:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\HLControl"; Filename: "{app}\hlcontrol.exe"
Name: "{autodesktop}\HLControl"; Filename: "{app}\hlcontrol.exe"; Tasks: desktopicon
Name: "{userstartup}\HLControl"; Filename: "{app}\hlcontrol.exe"; Parameters: "--tray"; Tasks: autostart

[Run]
Filename: "{app}\hlcontrol.exe"; Description: "{cm:LaunchProgram,HLControl}"; Flags: nowait postinstall skipifsilent
