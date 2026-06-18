unit IDEScroll.IdeHook;

// 디자인 타임 패키지 진입점.
//   - 기존: 로드 시 공용 TWheelHook 을 활성화하고 ini 에서 민감도를 읽는다.
//   - 추가: View 메뉴에 "IDEScroll Minimap" 항목을 넣고, 클릭하면 미니맵
//           도킹 폼을 생성/표시한다. 패키지 언로드 시 메뉴/폼을 정리한다.
// 민감도는 %APPDATA%\IDEScroll\IDEScroll.ini 에서 읽는다(기존과 동일).
// 인라인 변수는 구형 Delphi 호환을 위해 사용하지 않는다.

interface

// 디자인 패키지 등록 진입점. IDE 가 호출하며, 여기서 도킹 폼을 등록해
// 데스크톱 상태(마지막 도킹 위치)에 참여하도록 한다.
procedure Register;

implementation

{$REGION 'uses'}
uses
  Winapi.Windows,
  System.SysUtils,
  System.IOUtils,
  System.IniFiles,
  System.Classes,
  Vcl.Forms,
  Vcl.Menus,
  ToolsAPI,
  IDEScroll.WheelHook,
  IDEScroll.DockFrame,
  IDEScroll.DockForm;
{$ENDREGION}

const
  CONFIG_SECTION = 'Scroll';
  CONFIG_VERTICAL = 'VerticalLines';
  CONFIG_HORIZONTAL = 'HorizontalLines';

  VIEW_MENU_NAME = 'ViewsMenu';
  TOOLS_MENU_NAME = 'ToolsMenu';
  MENU_ITEM_NAME = 'IDEScrollMinimapMenuItem';

type
  // 메뉴/도킹 폼 등 IDE 통합 요소의 수명을 관리한다.
  // TComponent 를 상속해 도킹 폼이 외부에서 해제되면 FreeNotification 으로
  // FForm 을 자동으로 nil 처리한다(이중 해제/댕글링 방지).
  TIDEScrollIntegration = class(TComponent)
  private
    FForm: TCustomForm;
    FMenuItem: TMenuItem;
    function  FindParentMenu: TMenuItem;
    procedure MenuClick(ASender: TObject);
    procedure ShowDockForm;
  protected
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
  end;

var
  GIntegration: TIDEScrollIntegration;
  // 도킹 폼 명세는 등록(Register)과 표시(ShowDockForm)에서 동일 인스턴스를 공유해야
  // IDE 가 데스크톱 복원 시 같은 폼으로 인식한다.
  GDockableForm: INTACustomDockableForm;

procedure EnsureDockableForm;
begin
  if GDockableForm = nil then
  begin
    GDockableForm := TIDEScrollDockableForm.Create;
  end;
end;

// 이미 떠 있는 미니맵 도킹 폼(예: 데스크톱 복원으로 IDE 가 다시 만든 것)을 찾는다.
function FindDockFormInstance: TCustomForm;
var
  LFormIndex: Integer;
  LCompIndex: Integer;
  LForm: TCustomForm;
begin
  Result := nil;

  for LFormIndex := 0 to Screen.CustomFormCount - 1 do
  begin
    LForm := Screen.CustomForms[LFormIndex];
    for LCompIndex := 0 to LForm.ComponentCount - 1 do
    begin
      if LForm.Components[LCompIndex] is TIDEScrollFrame then
      begin
        Result := LForm;
        Exit;
      end;
    end;
  end;
end;

procedure Register;
var
  LServices: INTAServices;
begin
  EnsureDockableForm;

  // 패키지 등록 시점에 도킹 폼을 등록해야 IDE 시작 시 데스크톱 상태가 복원된다.
  if Supports(BorlandIDEServices, INTAServices, LServices) then
  begin
    LServices.RegisterDockableForm(GDockableForm);
  end;
end;

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

    // 사용자가 편집할 파일이 생기도록 현재 값을 다시 기록한다.
    LIni.WriteInteger(CONFIG_SECTION, CONFIG_VERTICAL, TWheelHook.Instance.VerticalLines);
    LIni.WriteInteger(CONFIG_SECTION, CONFIG_HORIZONTAL, TWheelHook.Instance.HorizontalLines);
  finally
    LIni.Free;
  end;
end;

{ TIDEScrollIntegration }

constructor TIDEScrollIntegration.Create;
var
  LParent: TMenuItem;
begin
  inherited Create(nil);

  LParent := FindParentMenu;
  if LParent <> nil then
  begin
    FMenuItem := TMenuItem.Create(nil);
    FMenuItem.Name := MENU_ITEM_NAME;
    FMenuItem.Caption := 'IDEScroll Minimap';
    FMenuItem.OnClick := MenuClick;
    LParent.Add(FMenuItem);
  end;
end;

destructor TIDEScrollIntegration.Destroy;
begin
  if FMenuItem <> nil then
  begin
    if FMenuItem.Parent <> nil then
    begin
      FMenuItem.Parent.Remove(FMenuItem);
    end;

    FreeAndNil(FMenuItem);
  end;

  // 패키지 언로드/언인스톨 시 도킹 폼(프레임)을 반드시 직접 해제해야 한다.
  // 그렇지 않으면 IDE 가 언로드된 BPL 의 프레임 소멸자/등록 통지자를 나중에
  // 호출하다가 크래시한다. 폼을 해제하면 프레임 소멸자가 통지자를 해제한다.
  if FForm <> nil then
  begin
    FreeAndNil(FForm);
  end;

  inherited Destroy;
end;

procedure TIDEScrollIntegration.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);

  // 도킹 폼이 외부에서 해제되면 댕글링 포인터를 남기지 않는다.
  if (AOperation = opRemove) and (AComponent = FForm) then
  begin
    FForm := nil;
  end;
end;

function TIDEScrollIntegration.FindParentMenu: TMenuItem;
var
  LServices: INTAServices;
  LMainMenu: TMainMenu;
  LIndex: Integer;
begin
  Result := nil;

  if not Supports(BorlandIDEServices, INTAServices, LServices) then
  begin
    Exit;
  end;

  LMainMenu := LServices.MainMenu;
  if LMainMenu = nil then
  begin
    Exit;
  end;

  // 우선 View 메뉴를 찾고, 없으면 Tools 메뉴로 대체한다.
  for LIndex := 0 to LMainMenu.Items.Count - 1 do
  begin
    if SameText(LMainMenu.Items[LIndex].Name, VIEW_MENU_NAME) then
    begin
      Result := LMainMenu.Items[LIndex];
      Exit;
    end;
  end;

  for LIndex := 0 to LMainMenu.Items.Count - 1 do
  begin
    if SameText(LMainMenu.Items[LIndex].Name, TOOLS_MENU_NAME) then
    begin
      Result := LMainMenu.Items[LIndex];
      Exit;
    end;
  end;
end;

procedure TIDEScrollIntegration.ShowDockForm;
var
  LServices: INTAServices;
begin
  if not Supports(BorlandIDEServices, INTAServices, LServices) then
  begin
    Exit;
  end;

  EnsureDockableForm;

  if FForm = nil then
  begin
    // 데스크톱 복원 등으로 IDE 가 이미 만들어 둔 인스턴스가 있으면 재사용한다.
    FForm := FindDockFormInstance;
  end;

  if FForm = nil then
  begin
    FForm := LServices.CreateDockableForm(GDockableForm);
  end;

  if FForm <> nil then
  begin
    // 폼이 외부에서 해제되면 Notification 으로 FForm 을 nil 처리하도록 등록.
    FForm.FreeNotification(Self);
    FForm.Show;
  end;
end;

procedure TIDEScrollIntegration.MenuClick(ASender: TObject);
begin
  ShowDockForm;
end;

initialization
  LoadConfig;
  TWheelHook.Instance.Active := True;

  try
    GIntegration := TIDEScrollIntegration.Create;
  except
    // ToolsAPI 통합 실패가 휠 훅 동작을 막지 않도록 삼키되 추적은 남긴다.
    on E: Exception do
    begin
      OutputDebugString(PChar('IDEScroll: integration setup failed - ' + E.ClassName + ': ' + E.Message));
    end;
  end;

finalization
  // 등록한 도킹 폼을 해제 전에 먼저 등록 해제한다.
  if GDockableForm <> nil then
  begin
    if Assigned(BorlandIDEServices) and Supports(BorlandIDEServices, INTAServices) then
    begin
      (BorlandIDEServices as INTAServices).UnregisterDockableForm(GDockableForm);
    end;
  end;

  FreeAndNil(GIntegration);
  GDockableForm := nil;
  TWheelHook.Instance.Active := False;

end.
