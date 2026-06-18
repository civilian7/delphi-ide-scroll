unit IDEScroll.DockForm;

// ToolsAPI 도킹 가능 폼 정의. INTACustomDockableForm 을 구현해
// IDE 가 호스트 폼을 만들고 그 안에 TIDEScrollFrame 을 끼우게 한다.
// 인라인 변수는 구형 Delphi 호환을 위해 사용하지 않는다.

interface

{$REGION 'uses'}
uses
  System.IniFiles,
  Vcl.Forms,
  Vcl.ActnList,
  Vcl.ImgList,
  Vcl.Menus,
  Vcl.ComCtrls,
  DesignIntf,
  ToolsAPI;
{$ENDREGION}

type
  // IDEScroll 미니맵 도킹 폼 명세.
  TIDEScrollDockableForm = class(TInterfacedObject, INTACustomDockableForm)
  public
    function  GetCaption: string;
    function  GetIdentifier: string;
    function  GetFrameClass: TCustomFrameClass;
    procedure FrameCreated(AFrame: TCustomFrame);
    function  GetMenuActionList: TCustomActionList;
    function  GetMenuImageList: TCustomImageList;
    procedure CustomizePopupMenu(PopupMenu: TPopupMenu);
    function  GetToolbarActionList: TCustomActionList;
    function  GetToolbarImageList: TCustomImageList;
    procedure CustomizeToolBar(ToolBar: TToolBar);
    procedure SaveWindowState(Desktop: TCustomIniFile; const Section: string; IsProject: Boolean);
    procedure LoadWindowState(Desktop: TCustomIniFile; const Section: string);
    function  GetEditState: TEditState;
    function  EditAction(Action: TEditAction): Boolean;
  end;

const
  IDESCROLL_FORM_IDENT = 'IDEScrollMinimapForm';

implementation

{$REGION 'uses'}
uses
  IDEScroll.DockFrame;
{$ENDREGION}

function TIDEScrollDockableForm.GetCaption: string;
begin
  Result := 'IDEScroll Minimap';
end;

function TIDEScrollDockableForm.GetIdentifier: string;
begin
  Result := IDESCROLL_FORM_IDENT;
end;

function TIDEScrollDockableForm.GetFrameClass: TCustomFrameClass;
begin
  Result := TIDEScrollFrame;
end;

procedure TIDEScrollDockableForm.FrameCreated(AFrame: TCustomFrame);
begin
  // 프레임 초기화는 TIDEScrollFrame 생성자에서 수행한다.
end;

function TIDEScrollDockableForm.GetMenuActionList: TCustomActionList;
begin
  Result := nil;
end;

function TIDEScrollDockableForm.GetMenuImageList: TCustomImageList;
begin
  Result := nil;
end;

procedure TIDEScrollDockableForm.CustomizePopupMenu(PopupMenu: TPopupMenu);
begin
  // 사용자 정의 팝업 메뉴 없음.
end;

function TIDEScrollDockableForm.GetToolbarActionList: TCustomActionList;
begin
  Result := nil;
end;

function TIDEScrollDockableForm.GetToolbarImageList: TCustomImageList;
begin
  Result := nil;
end;

procedure TIDEScrollDockableForm.CustomizeToolBar(ToolBar: TToolBar);
begin
  // 사용자 정의 툴바 없음.
end;

procedure TIDEScrollDockableForm.SaveWindowState(Desktop: TCustomIniFile; const Section: string; IsProject: Boolean);
begin
  // 저장할 추가 상태 없음(도킹 위치는 IDE 가 관리).
end;

procedure TIDEScrollDockableForm.LoadWindowState(Desktop: TCustomIniFile; const Section: string);
begin
  // 복원할 추가 상태 없음.
end;

function TIDEScrollDockableForm.GetEditState: TEditState;
begin
  Result := [];
end;

function TIDEScrollDockableForm.EditAction(Action: TEditAction): Boolean;
begin
  Result := False;
end;

end.
