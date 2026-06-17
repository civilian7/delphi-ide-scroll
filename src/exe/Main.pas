unit Main;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.IniFiles,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.Samples.Spin,
  IDEScroll.WheelHook;

type
  TfrmMain = class(TForm)
    btnToggle: TButton;
    lblVertical: TLabel;
    spnVertical: TSpinEdit;
    lblHorizontal: TLabel;
    spnHorizontal: TSpinEdit;
    memLog: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnToggleClick(Sender: TObject);
    procedure spnVerticalChange(Sender: TObject);
    procedure spnHorizontalChange(Sender: TObject);
  private
    function  ConfigFileName: string;
    procedure HandleLog(const AText: string);
    procedure LoadConfig;
    procedure SaveConfig;
    procedure UpdateButton;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

const
  CONFIG_SECTION = 'Scroll';
  CONFIG_VERTICAL = 'VerticalLines';
  CONFIG_HORIZONTAL = 'HorizontalLines';

procedure TfrmMain.btnToggleClick(Sender: TObject);
begin
  try
    TWheelHook.Instance.Active := not TWheelHook.Instance.Active;
  except
    on E: Exception do
    begin
      HandleLog(Format('Error: %s', [E.Message]));
    end;
  end;

  UpdateButton;
end;

function TfrmMain.ConfigFileName: string;
begin
  // IDEScroll.ini in the same folder as the executable.
  Result := TPath.ChangeExtension(ParamStr(0), '.ini');
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Caption := 'IDEScroll - Form Designer Wheel Scroll';
  lblVertical.Caption := 'Vertical';
  lblHorizontal.Caption := 'Horizontal';

  TWheelHook.Instance.OnLog := HandleLog;
  LoadConfig;
  UpdateButton;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  SaveConfig;
  TWheelHook.Instance.Active := False;
  TWheelHook.Instance.OnLog := nil;
end;

procedure TfrmMain.HandleLog(const AText: string);
begin
  // The hook callback runs on the main thread's message pump, so touching the UI is safe.
  memLog.Lines.Add(Format('[%s] %s', [FormatDateTime('hh:nn:ss', Now), AText]));
end;

procedure TfrmMain.LoadConfig;
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(ConfigFileName);
  try
    spnVertical.Value := LIni.ReadInteger(CONFIG_SECTION, CONFIG_VERTICAL, TWheelHook.Instance.VerticalLines);
    spnHorizontal.Value := LIni.ReadInteger(CONFIG_SECTION, CONFIG_HORIZONTAL, TWheelHook.Instance.HorizontalLines);
  finally
    LIni.Free;
  end;

  // Setting Value fires OnChange which also updates the hook, but it may not
  // fire for an unchanged value, so apply it explicitly.
  TWheelHook.Instance.VerticalLines := spnVertical.Value;
  TWheelHook.Instance.HorizontalLines := spnHorizontal.Value;
end;

procedure TfrmMain.SaveConfig;
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(ConfigFileName);
  try
    LIni.WriteInteger(CONFIG_SECTION, CONFIG_VERTICAL, spnVertical.Value);
    LIni.WriteInteger(CONFIG_SECTION, CONFIG_HORIZONTAL, spnHorizontal.Value);
  finally
    LIni.Free;
  end;
end;

procedure TfrmMain.spnHorizontalChange(Sender: TObject);
begin
  TWheelHook.Instance.HorizontalLines := spnHorizontal.Value;
end;

procedure TfrmMain.spnVerticalChange(Sender: TObject);
begin
  TWheelHook.Instance.VerticalLines := spnVertical.Value;
end;

procedure TfrmMain.UpdateButton;
begin
  // Default = True, so Enter triggers it (standard Windows behavior).
  if TWheelHook.Instance.Active then
  begin
    btnToggle.Caption := 'Stop hooking';
  end
  else
  begin
    btnToggle.Caption := 'Start hooking (Enter)';
  end;
end;

end.
