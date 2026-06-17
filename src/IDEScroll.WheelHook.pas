unit IDEScroll.WheelHook;

// Low-level hook that intercepts mouse-wheel scrolling over the Delphi IDE
// form designer (TFormContainerForm).
//   Wheel        -> vertical scroll
//   Ctrl+Wheel   -> horizontal scroll
// Uses a WH_MOUSE_LL global hook, so it does not inject into the IDE process
// and works regardless of the IDE version/bitness.
// Inline variables are avoided for compatibility with older Delphi versions.

interface

uses
  Winapi.Windows,
  Winapi.Messages;

type
  // Log callback type for reporting scroll-translation state.
  TLogEvent = procedure(const AText: string) of object;

  // Singleton hook that translates mouse-wheel events over the form designer
  // container into vertical/horizontal scrolling.
  TWheelHook = class
  strict private
    class var FInstance: TWheelHook;
    class constructor Create;
    class destructor Destroy;
  private
    FActive: Boolean;
    FHookHandle: HHOOK;
    FHorizontalLines: Integer;
    FTargetClass: string;
    FVerticalLines: Integer;

    FOnLog: TLogEvent;
    procedure DoLog(const AText: string);
    function  FindContainer(const APoint: TPoint): HWND;
    procedure PostScroll(const AWindow: HWND; const AVertical: Boolean; const ABackward: Boolean; const ANotches: Integer; const ALines: Integer);
    procedure SetActive(const AValue: Boolean);
  public
    constructor Create;
    destructor Destroy; override;

    function  HandleWheel(const APoint: TPoint; const ADelta: Integer; const ACtrl: Boolean): Boolean;

    property Active: Boolean read FActive write SetActive;
    class property Instance: TWheelHook read FInstance;

    property HorizontalLines: Integer read FHorizontalLines write FHorizontalLines;
    property VerticalLines: Integer read FVerticalLines write FVerticalLines;

    property OnLog: TLogEvent read FOnLog write FOnLog;
  end;

implementation

uses
  System.SysUtils;

type
  // Struct pointed to by the WH_MOUSE_LL callback lParam (not declared in Winapi.Windows).
  PLowLevelMouseInfo = ^TLowLevelMouseInfo;
  TLowLevelMouseInfo = record
    pt: TPoint;
    mouseData: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;

// Form designer container VCL class name, shared across many Delphi/C++Builder versions.
const
  DESIGNER_CLASS = 'TFormContainerForm';
  DEFAULT_SCROLL_LINES = 3;

// WH_MOUSE_LL callback. Invoked in the message-pump context of the installing thread.
function LowLevelMouseProc(nCode: Integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  LInfo: PLowLevelMouseInfo;
  LDelta: SmallInt;
  LCtrl: Boolean;
begin
  if (nCode = HC_ACTION) and (wParam = WM_MOUSEWHEEL) then
  begin
    LInfo := PLowLevelMouseInfo(lParam);
    LDelta := SmallInt(HiWord(LInfo^.mouseData));
    LCtrl := GetAsyncKeyState(VK_CONTROL) < 0;
    if TWheelHook.Instance.HandleWheel(LInfo^.pt, LDelta, LCtrl) then
    begin
      // Consume the original wheel message to block the IDE's default handling.
      Result := 1;
      Exit;
    end;
  end;

  Result := CallNextHookEx(0, nCode, wParam, lParam);
end;

class constructor TWheelHook.Create;
begin
  FInstance := TWheelHook.Create;
end;

class destructor TWheelHook.Destroy;
begin
  FInstance.Free;
end;

constructor TWheelHook.Create;
var
  LLines: UINT;
begin
  inherited Create;
  FActive := False;
  FHookHandle := 0;
  FTargetClass := DESIGNER_CLASS;
  FHorizontalLines := DEFAULT_SCROLL_LINES;

  // Default vertical sensitivity follows the system wheel-scroll line count.
  LLines := DEFAULT_SCROLL_LINES;
  if SystemParametersInfo(SPI_GETWHEELSCROLLLINES, 0, @LLines, 0) then
  begin
    FVerticalLines := Integer(LLines);
  end
  else
  begin
    FVerticalLines := DEFAULT_SCROLL_LINES;
  end;

  // 0 means "page scrolling", so fall back to the default.
  if FVerticalLines <= 0 then
  begin
    FVerticalLines := DEFAULT_SCROLL_LINES;
  end;
end;

destructor TWheelHook.Destroy;
begin
  Active := False;
  inherited Destroy;
end;

procedure TWheelHook.DoLog(const AText: string);
begin
  if Assigned(FOnLog) then
  begin
    FOnLog(AText);
  end;
end;

function TWheelHook.FindContainer(const APoint: TPoint): HWND;
var
  LWindow: HWND;
  LBuffer: array[0..255] of Char;
begin
  Result := 0;

  LWindow := WindowFromPoint(APoint);
  while LWindow <> 0 do
  begin
    GetClassName(LWindow, LBuffer, Length(LBuffer));
    if SameText(LBuffer, FTargetClass) then
    begin
      Result := LWindow;
      Exit;
    end;

    LWindow := GetParent(LWindow);
  end;
end;

function TWheelHook.HandleWheel(const APoint: TPoint; const ADelta: Integer; const ACtrl: Boolean): Boolean;
var
  LContainer: HWND;
  LNotches: Integer;
  LVertical: Boolean;
  LBackward: Boolean;
  LLines: Integer;
begin
  Result := False;
  if not FActive then
  begin
    Exit;
  end;

  LContainer := FindContainer(APoint);
  if LContainer = 0 then
  begin
    Exit;
  end;

  LNotches := Abs(ADelta) div WHEEL_DELTA;
  if LNotches = 0 then
  begin
    LNotches := 1;
  end;

  // Plain wheel -> vertical, Ctrl+wheel -> horizontal.
  LVertical := not ACtrl;

  // Wheel up (ADelta > 0) -> up/left, wheel down -> down/right.
  LBackward := ADelta > 0;

  if LVertical then
  begin
    LLines := FVerticalLines;
  end
  else
  begin
    LLines := FHorizontalLines;
  end;

  // Diagnostic trace (visible in DebugView etc.). The memo log keeps only
  // enable/disable messages to stay readable.
  OutputDebugString(PChar(Format('IDEScroll: vertical=%s, hwnd=$%x, delta=%d, notches=%d, lines=%d',
    [BoolToStr(LVertical, True), LContainer, ADelta, LNotches, LLines])));

  PostScroll(LContainer, LVertical, LBackward, LNotches, LLines);
  Result := True;
end;

procedure TWheelHook.PostScroll(const AWindow: HWND; const AVertical: Boolean; const ABackward: Boolean; const ANotches: Integer; const ALines: Integer);
var
  LMessage: UINT;
  LLineCode: Integer;
  LLines: Integer;
  LCount: Integer;
  I: Integer;
begin
  if AVertical then
  begin
    LMessage := WM_VSCROLL;
    if ABackward then
    begin
      LLineCode := SB_LINEUP;
    end
    else
    begin
      LLineCode := SB_LINEDOWN;
    end;
  end
  else
  begin
    LMessage := WM_HSCROLL;
    if ABackward then
    begin
      LLineCode := SB_LINELEFT;
    end
    else
    begin
      LLineCode := SB_LINERIGHT;
    end;
  end;

  LLines := ALines;
  if LLines < 1 then
  begin
    LLines := 1;
  end;

  LCount := ANotches * LLines;
  for I := 0 to LCount - 1 do
  begin
    PostMessage(AWindow, LMessage, MakeWParam(LLineCode, 0), 0);
  end;

  PostMessage(AWindow, LMessage, MakeWParam(SB_ENDSCROLL, 0), 0);
end;

procedure TWheelHook.SetActive(const AValue: Boolean);
begin
  if FActive = AValue then
  begin
    Exit;
  end;

  if AValue then
  begin
    FHookHandle := SetWindowsHookEx(WH_MOUSE_LL, @LowLevelMouseProc, HInstance, 0);
    if FHookHandle = 0 then
    begin
      raise Exception.CreateFmt('Failed to install the mouse hook (error code %d)', [GetLastError]);
    end;

    FActive := True;
    DoLog('Hook enabled (wheel = vertical, Ctrl+wheel = horizontal)');
  end
  else
  begin
    if FHookHandle <> 0 then
    begin
      UnhookWindowsHookEx(FHookHandle);
      FHookHandle := 0;
    end;

    FActive := False;
    DoLog('Hook disabled');
  end;
end;

end.
