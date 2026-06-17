program IDEScroll;

uses
  Vcl.Forms,
  Main in 'Main.pas' {frmMain},
  IDEScroll.WheelHook in 'IDEScroll.WheelHook.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'IDEScroll';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
