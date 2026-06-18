unit IDEScroll.DesignerIntrospect;

// 폼 디자이너 내부 상태를 들여다보는 Win32/ToolsAPI 헬퍼 모음.
//   - 현재 디자인 중인 폼(TWinControl) 핸들 탐색
//   - 폼을 감싼 스크롤 컨테이너(TFormContainerForm) 탐색
//   - PrintWindow 로 폼 전체를 비트맵으로 캡처
//   - 컨테이너의 스크롤 정보 읽기 / 절대 위치로 스크롤
// 이 유닛은 HWND 수준 로직만 담당하며 UI 를 알지 못한다.
// 인라인 변수는 구형 Delphi 호환을 위해 사용하지 않는다.

interface

{$REGION 'uses'}
uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics;
{$ENDREGION}

// 현재 활성 모듈에서 디자인 중인 루트 폼을 찾는다.
function TryGetDesignedForm(out AForm: TWinControl): Boolean;

// AChild 의 부모 사슬을 거슬러 올라가 TFormContainerForm 컨테이너를 찾는다.
function FindScrollContainer(const AChild: HWND): HWND;

// AWnd 창 전체(스크롤로 가려진 영역 포함)를 ABitmap 으로 캡처한다.
function CaptureWindowImage(const AWnd: HWND; const ABitmap: TBitmap): Boolean;

// AWnd 의 ABar(SB_HORZ/SB_VERT) 스크롤 정보를 읽는다.
procedure ReadScroll(const AWnd: HWND; const ABar: Integer; out APos: Integer; out APage: Integer; out AMin: Integer; out AMax: Integer);

// AWnd 의 ABar 스크롤을 APos 절대 위치로 이동시킨다.
// AFinal=False 면 드래그 중 연속 스크롤(SB_THUMBTRACK), True 면 확정(SB_THUMBPOSITION + 종료).
procedure ScrollWindowTo(const AWnd: HWND; const ABar: Integer; const APos: Integer; const AFinal: Boolean);

implementation

{$REGION 'uses'}
uses
  ToolsAPI;
{$ENDREGION}

const
  DESIGNER_CONTAINER_CLASS = 'TFormContainerForm';
  // PrintWindow 가 가려진 영역까지 전체 렌더하도록 하는 플래그(Winapi 에 미선언 가능성 대비).
  PW_RENDERFULLCONTENT_FLAG = $00000002;

// 일부 RTL 버전에 Winapi.Windows 로 노출되지 않아 직접 임포트한다.
function PrintWindow(AWnd: HWND; ADC: HDC; AFlags: UINT): BOOL; stdcall; external user32 name 'PrintWindow';

function TryGetDesignedForm(out AForm: TWinControl): Boolean;
var
  LModuleServices: IOTAModuleServices;
  LModule: IOTAModule;
  LEditor: IOTAEditor;
  LFormEditor: IOTAFormEditor;
  LRoot: IOTAComponent;
  LComponent: TComponent;
  LIndex: Integer;
begin
  Result := False;
  AForm := nil;

  if not Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
  begin
    Exit;
  end;

  LModule := LModuleServices.CurrentModule;
  if LModule = nil then
  begin
    Exit;
  end;

  for LIndex := 0 to LModule.GetModuleFileCount - 1 do
  begin
    LEditor := LModule.GetModuleFileEditor(LIndex);
    if Supports(LEditor, IOTAFormEditor, LFormEditor) then
    begin
      LRoot := LFormEditor.GetRootComponent;
      if LRoot <> nil then
      begin
        // 네이티브(VCL) 디자이너에서 컴포넌트 핸들은 실제 TComponent 포인터다.
        LComponent := TComponent(LRoot.GetComponentHandle);
        if LComponent is TWinControl then
        begin
          AForm := TWinControl(LComponent);
          Result := True;
          Exit;
        end;
      end;
    end;
  end;
end;

function FindScrollContainer(const AChild: HWND): HWND;
var
  LWindow: HWND;
  LBuffer: array[0..255] of Char;
begin
  Result := 0;

  LWindow := AChild;
  while LWindow <> 0 do
  begin
    GetClassName(LWindow, LBuffer, Length(LBuffer));
    if SameText(LBuffer, DESIGNER_CONTAINER_CLASS) then
    begin
      Result := LWindow;
      Exit;
    end;

    LWindow := GetParent(LWindow);
  end;
end;

function CaptureWindowImage(const AWnd: HWND; const ABitmap: TBitmap): Boolean;
var
  LRect: TRect;
  LWidth: Integer;
  LHeight: Integer;
begin
  Result := False;

  if (AWnd = 0) or not IsWindow(AWnd) then
  begin
    Exit;
  end;

  if not GetWindowRect(AWnd, LRect) then
  begin
    Exit;
  end;

  LWidth := LRect.Right - LRect.Left;
  LHeight := LRect.Bottom - LRect.Top;
  if (LWidth <= 0) or (LHeight <= 0) then
  begin
    Exit;
  end;

  ABitmap.PixelFormat := pf24bit;
  ABitmap.SetSize(LWidth, LHeight);

  // PW_RENDERFULLCONTENT 로 디자이너에 가려진 부분까지 그린다.
  Result := PrintWindow(AWnd, ABitmap.Canvas.Handle, PW_RENDERFULLCONTENT_FLAG);
end;

procedure ReadScroll(const AWnd: HWND; const ABar: Integer; out APos: Integer; out APage: Integer; out AMin: Integer; out AMax: Integer);
var
  LInfo: TScrollInfo;
begin
  APos := 0;
  APage := 0;
  AMin := 0;
  AMax := 0;

  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.cbSize := SizeOf(LInfo);
  LInfo.fMask := SIF_ALL;

  if GetScrollInfo(AWnd, ABar, LInfo) then
  begin
    APos := LInfo.nPos;
    APage := Integer(LInfo.nPage);
    AMin := LInfo.nMin;
    AMax := LInfo.nMax;
  end;
end;

procedure ScrollWindowTo(const AWnd: HWND; const ABar: Integer; const APos: Integer; const AFinal: Boolean);
var
  LMessage: UINT;
  LPos: Integer;
begin
  if ABar = SB_HORZ then
  begin
    LMessage := WM_HSCROLL;
  end
  else
  begin
    LMessage := WM_VSCROLL;
  end;

  // 스크롤 알림의 위치 값은 16비트(HiWord)로 전달된다.
  LPos := APos;
  if LPos < 0 then
  begin
    LPos := 0;
  end;

  if LPos > $FFFF then
  begin
    LPos := $FFFF;
  end;

  if AFinal then
  begin
    // 드래그 종료: 위치 확정 후 스크롤 종료를 알린다.
    SendMessage(AWnd, LMessage, MakeWParam(SB_THUMBPOSITION, LPos), 0);
    SendMessage(AWnd, LMessage, MakeWParam(SB_ENDSCROLL, 0), 0);
  end
  else
  begin
    // 드래그 중: 연속 추적으로 부드럽게 스크롤한다.
    SendMessage(AWnd, LMessage, MakeWParam(SB_THUMBTRACK, LPos), 0);
  end;
end;

end.
