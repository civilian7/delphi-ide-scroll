unit IDEScroll.IdeHook;

// Design-time package glue: activates the shared TWheelHook when the package is
// loaded into the IDE and deactivates it on unload. No UI; sensitivity is read
// from %APPDATA%\IDEScroll\IDEScroll.ini (created with defaults on first run).

interface

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.IOUtils,
  System.IniFiles,
  IDEScroll.WheelHook;

const
  CONFIG_SECTION = 'Scroll';
  CONFIG_VERTICAL = 'VerticalLines';
  CONFIG_HORIZONTAL = 'HorizontalLines';

function ConfigFileName: string;
var
  LDir: string;
begin
  // %APPDATA%\IDEScroll\IDEScroll.ini
  LDir := TPath.Combine(GetEnvironmentVariable('APPDATA'), 'IDEScroll');
  Result := TPath.Combine(LDir, 'IDEScroll.ini');
end;

procedure LoadConfig;
var
  LIni: TIniFile;
  LDir: string;
begin
  LDir := ExtractFileDir(ConfigFileName);
  if not TDirectory.Exists(LDir) then
  begin
    TDirectory.CreateDirectory(LDir);
  end;

  LIni := TIniFile.Create(ConfigFileName);
  try
    TWheelHook.Instance.VerticalLines := LIni.ReadInteger(CONFIG_SECTION, CONFIG_VERTICAL, TWheelHook.Instance.VerticalLines);
    TWheelHook.Instance.HorizontalLines := LIni.ReadInteger(CONFIG_SECTION, CONFIG_HORIZONTAL, TWheelHook.Instance.HorizontalLines);

    // Write current values back so the user has a file to edit.
    LIni.WriteInteger(CONFIG_SECTION, CONFIG_VERTICAL, TWheelHook.Instance.VerticalLines);
    LIni.WriteInteger(CONFIG_SECTION, CONFIG_HORIZONTAL, TWheelHook.Instance.HorizontalLines);
  finally
    LIni.Free;
  end;
end;

initialization
  LoadConfig;
  TWheelHook.Instance.Active := True;

finalization
  TWheelHook.Instance.Active := False;

end.
