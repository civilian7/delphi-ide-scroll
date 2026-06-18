unit IDEScroll.IdeHook;

// 디자인 타임 패키지 진입점.
//   - 기존: 로드 시 공용 TWheelHook 을 활성화하고 ini 에서 민감도를 읽는다.
//   - 추가: View 메뉴에 "IDEScroll Minimap" 항목을 넣고, 클릭하면 미니맵
//           도킹 폼을 생성/표시한다. 패키지 언로드 시 메뉴/폼을 정리한다.
// 민감도는 %APPDATA%\IDEScroll\IDEScroll.ini 에서 읽는다(기존과 동일).
// 인라인 변수는 구형 Delphi 호환을 위해 사용하지 않는다.

interface

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
  TIDEScrollIntegration = class
  private
    FDockableForm: INTACustomDockableForm;
    FForm: TCustomForm;
    FMenuItem: TMenuItem;
    function  FindParentMenu: TMenuItem;
    procedure MenuClick(ASender: TObject);
    procedure ShowDockForm;
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  GIntegration: TIDEScrollIntegration;

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
  inherited Create;

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

  // 도킹 폼은 IDE 가 소유하므로 직접 Free 하지 않고 참조만 끊는다.
  FForm := nil;
  FDockableForm := nil;

  inherited Destroy;
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

  if FDockableForm = nil then
  begin
    FDockableForm := TIDEScrollDockableForm.Create;
  end;

  if FForm = nil then
  begin
    FForm := LServices.CreateDockableForm(FDockableForm);
  end;

  if FForm <> nil then
  begin
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
  FreeAndNil(GIntegration);
  TWheelHook.Instance.Active := False;

end.
