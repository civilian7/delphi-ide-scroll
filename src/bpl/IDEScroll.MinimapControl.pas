unit IDEScroll.MinimapControl;

// 폼 디자이너 미니맵 컨트롤.
//   - 미니맵 캔버스 = TFormContainerForm(컨테이너)의 클라이언트 전체.
//   - 그 안에 디자인 중인 폼을 실제 위치/크기의 창(타이틀바 포함)으로 그린다.
//     → 폼이 컨테이너의 어디에 있는지 한눈에 보인다.
//   - 폼 창(박스)을 드래그/드롭하거나 마우스 휠을 굴리면 그 방향으로
//     디자이너를 스크롤한다(폼 위치 이동). 드래그 중에는 점선 윤곽만 표시.
//   - 우하단에 "by DelMadang" 크레딧 링크(호버 + 클릭).
// 색상은 IDE 테마를 따른다. 인라인 변수는 구형 Delphi 호환을 위해 사용하지 않는다.

interface

{$REGION 'uses'}
uses
  Winapi.Windows,
  Winapi.Messages,
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics;
{$ENDREGION}

type
  // 디자이너 미니맵 표시/드래그 컨트롤.
  TIDEScrollMinimap = class(TCustomControl)
  private
    FBitmap: TBitmap;
    FCanvasRect: TRect;
    FContainer: HWND;
    FDragBox: TRect;
    FDragGrab: TPoint;
    FDragging: Boolean;
    FFormBox: TRect;
    FFormCaption: string;
    FFormHandle: HWND;
    FHasDesigner: Boolean;
    FLastFormPos: TPoint;
    FLinkHover: Boolean;
    FLinkRect: TRect;
    FScale: Double;
    function  ContainerClientSize(out AWidth: Integer; out AHeight: Integer): Boolean;
    function  FormPosInContainer(out APos: TPoint): Boolean;
    function  FormWindowRect(const AClientBox: TRect): TRect;
    procedure ApplyDragScroll(const ABox: TRect);
    procedure ClampFormBox(var ABox: TRect);
    procedure DrawCreditLink;
    procedure DrawFormWindow(const AClientBox: TRect);
    procedure OpenCreditLink;
    procedure RecomputeLayout;
    procedure ScrollContainerBy(const ADeltaX: Integer; const ADeltaY: Integer);
    procedure UpdateLinkHover(const AX: Integer; const AY: Integer);
  protected
    procedure CMMouseLeave(var AMessage: TMessage); message CM_MOUSELEAVE;
    function  DoMouseWheel(AShift: TShiftState; AWheelDelta: Integer; AMousePos: TPoint): Boolean; override;
    procedure MouseDown(AButton: TMouseButton; AShift: TShiftState; AX: Integer; AY: Integer); override;
    procedure MouseMove(AShift: TShiftState; AX: Integer; AY: Integer); override;
    procedure MouseUp(AButton: TMouseButton; AShift: TShiftState; AX: Integer; AY: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // 디자인 폼을 다시 캡처한다(무거운 작업).
    procedure UpdateCapture;

    // 폼 위치가 바뀌었으면 다시 그린다(가벼운 작업, 타이머에서 호출).
    procedure RefreshViewport;
  end;

implementation

{$REGION 'uses'}
uses
  Winapi.ShellAPI,
  System.Math,
  IDEScroll.DesignerIntrospect,
  IDEScroll.Theming;
{$ENDREGION}

const
  MINIMAP_MARGIN = 6;
  CREDIT_MARGIN = 8;
  TITLEBAR_H = 16;
  WHEEL_STEP_PX = 48;
  CREDIT_TEXT = 'by DelMadang';
  CREDIT_URL = 'https://cafe.naver.com/delmadang';

constructor TIDEScrollMinimap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBitmap := TBitmap.Create;
  FBitmap.PixelFormat := pf24bit;
  FContainer := 0;
  FFormHandle := 0;
  FDragging := False;
  FHasDesigner := False;
  FScale := 0;

  // 더블 버퍼링으로 드래그 시 깜빡임/끊김을 줄인다.
  DoubleBuffered := True;
  ControlStyle := ControlStyle + [csOpaque];
end;

destructor TIDEScrollMinimap.Destroy;
begin
  FBitmap.Free;
  inherited Destroy;
end;

function TIDEScrollMinimap.ContainerClientSize(out AWidth: Integer; out AHeight: Integer): Boolean;
var
  LRect: TRect;
begin
  AWidth := 0;
  AHeight := 0;
  Result := False;

  if (FContainer = 0) or not Winapi.Windows.GetClientRect(FContainer, LRect) then
  begin
    Exit;
  end;

  AWidth := LRect.Right - LRect.Left;
  AHeight := LRect.Bottom - LRect.Top;
  Result := (AWidth > 0) and (AHeight > 0);
end;

function TIDEScrollMinimap.FormPosInContainer(out APos: TPoint): Boolean;
var
  LContOrigin: TPoint;
  LFormOrigin: TPoint;
begin
  APos := Point(0, 0);
  Result := False;

  if (FContainer = 0) or (FFormHandle = 0) then
  begin
    Exit;
  end;

  LContOrigin := Point(0, 0);
  if not Winapi.Windows.ClientToScreen(FContainer, LContOrigin) then
  begin
    Exit;
  end;

  LFormOrigin := Point(0, 0);
  if not Winapi.Windows.ClientToScreen(FFormHandle, LFormOrigin) then
  begin
    Exit;
  end;

  // 컨테이너 클라이언트 좌표 기준 폼 클라이언트 위치.
  APos.X := LFormOrigin.X - LContOrigin.X;
  APos.Y := LFormOrigin.Y - LContOrigin.Y;
  Result := True;
end;

function TIDEScrollMinimap.FormWindowRect(const AClientBox: TRect): TRect;
begin
  // 타이틀바를 포함한 폼 창 전체 영역(클라이언트 박스 위에 타이틀바).
  Result := Rect(AClientBox.Left, AClientBox.Top - TITLEBAR_H, AClientBox.Right, AClientBox.Bottom);
end;

procedure TIDEScrollMinimap.RecomputeLayout;
var
  LInner: TRect;
  LInnerW: Integer;
  LInnerH: Integer;
  LFormW: Integer;
  LFormH: Integer;
  LContW: Integer;
  LContH: Integer;
  LFormPos: TPoint;
begin
  FCanvasRect := TRect.Empty;
  FFormBox := TRect.Empty;
  FScale := 0;

  LFormW := FBitmap.Width;
  LFormH := FBitmap.Height;
  if (LFormW <= 0) or (LFormH <= 0) then
  begin
    Exit;
  end;

  // 캔버스 = 컨테이너 클라이언트 전체. 정보가 없으면 폼 크기로 대체.
  if not ContainerClientSize(LContW, LContH) then
  begin
    LContW := LFormW;
    LContH := LFormH;
  end;

  if not FormPosInContainer(LFormPos) then
  begin
    LFormPos := Point(0, 0);
  end;

  FLastFormPos := LFormPos;

  // 캔버스를 미니맵 안에 비율 유지로 맞춘다. 타이틀바 공간을 위에 확보.
  LInner := ClientRect;
  LInner.Inflate(-MINIMAP_MARGIN, -MINIMAP_MARGIN);
  LInnerW := LInner.Right - LInner.Left;
  LInnerH := (LInner.Bottom - LInner.Top) - TITLEBAR_H;
  if (LInnerW <= 0) or (LInnerH <= 0) then
  begin
    Exit;
  end;

  FScale := Min(LInnerW / LContW, LInnerH / LContH);

  FCanvasRect.Left := LInner.Left + (LInnerW - Round(LContW * FScale)) div 2;
  FCanvasRect.Top := LInner.Top + TITLEBAR_H + (LInnerH - Round(LContH * FScale)) div 2;
  FCanvasRect.Right := FCanvasRect.Left + Round(LContW * FScale);
  FCanvasRect.Bottom := FCanvasRect.Top + Round(LContH * FScale);

  // 폼 박스 = 컨테이너 안의 실제 폼 위치/크기.
  FFormBox.Left := FCanvasRect.Left + Round(LFormPos.X * FScale);
  FFormBox.Top := FCanvasRect.Top + Round(LFormPos.Y * FScale);
  FFormBox.Right := FFormBox.Left + Round(LFormW * FScale);
  FFormBox.Bottom := FFormBox.Top + Round(LFormH * FScale);
end;

procedure TIDEScrollMinimap.ClampFormBox(var ABox: TRect);
var
  LContW: Integer;
  LContH: Integer;
  LFormW: Integer;
  LFormH: Integer;
  LBoxW: Integer;
  LBoxH: Integer;
  LMinLeft: Integer;
  LMaxLeft: Integer;
  LMinTop: Integer;
  LMaxTop: Integer;
begin
  if FScale <= 0 then
  begin
    Exit;
  end;

  if not ContainerClientSize(LContW, LContH) then
  begin
    Exit;
  end;

  LFormW := FBitmap.Width;
  LFormH := FBitmap.Height;
  LBoxW := Round(LFormW * FScale);
  LBoxH := Round(LFormH * FScale);

  // 폼은 컨테이너 클라이언트 범위 안에서만 위치할 수 있다(스크롤 한계).
  // 가로: 폼이 컨테이너보다 좁으면 좌측 고정, 넓으면 [컨테이너폭-폼폭, 0] 범위.
  if LFormW <= LContW then
  begin
    LMinLeft := FCanvasRect.Left;
    LMaxLeft := FCanvasRect.Left;
  end
  else
  begin
    LMinLeft := FCanvasRect.Left + Round((LContW - LFormW) * FScale);
    LMaxLeft := FCanvasRect.Left;
  end;

  if LFormH <= LContH then
  begin
    LMinTop := FCanvasRect.Top;
    LMaxTop := FCanvasRect.Top;
  end
  else
  begin
    LMinTop := FCanvasRect.Top + Round((LContH - LFormH) * FScale);
    LMaxTop := FCanvasRect.Top;
  end;

  ABox.Left := EnsureRange(ABox.Left, LMinLeft, LMaxLeft);
  ABox.Top := EnsureRange(ABox.Top, LMinTop, LMaxTop);
  ABox.Right := ABox.Left + LBoxW;
  ABox.Bottom := ABox.Top + LBoxH;
end;

procedure TIDEScrollMinimap.ApplyDragScroll(const ABox: TRect);
var
  LCurPos: TPoint;
  LNewFormLeft: Integer;
  LNewFormTop: Integer;
  LDeltaX: Integer;
  LDeltaY: Integer;
begin
  if (FContainer = 0) or (FScale <= 0) then
  begin
    Exit;
  end;

  if not FormPosInContainer(LCurPos) then
  begin
    Exit;
  end;

  // 드롭 박스가 가리키는 폼의 새 컨테이너 위치(클라이언트 픽셀).
  LNewFormLeft := Round((ABox.Left - FCanvasRect.Left) / FScale);
  LNewFormTop := Round((ABox.Top - FCanvasRect.Top) / FScale);

  // 폼이 그 위치로 가려면 스크롤을 (현재위치 - 새위치)만큼 이동해야 한다.
  LDeltaX := LCurPos.X - LNewFormLeft;
  LDeltaY := LCurPos.Y - LNewFormTop;

  ScrollContainerBy(LDeltaX, LDeltaY);
end;

procedure TIDEScrollMinimap.ScrollContainerBy(const ADeltaX: Integer; const ADeltaY: Integer);
var
  LPos: Integer;
  LPage: Integer;
  LMin: Integer;
  LMax: Integer;
  LNewPos: Integer;
begin
  if FContainer = 0 then
  begin
    Exit;
  end;

  if ADeltaX <> 0 then
  begin
    ReadScroll(FContainer, SB_HORZ, LPos, LPage, LMin, LMax);
    LNewPos := EnsureRange(LPos + ADeltaX, LMin, Max(LMin, LMax - LPage + 1));
    ScrollWindowTo(FContainer, SB_HORZ, LNewPos, True);
  end;

  if ADeltaY <> 0 then
  begin
    ReadScroll(FContainer, SB_VERT, LPos, LPage, LMin, LMax);
    LNewPos := EnsureRange(LPos + ADeltaY, LMin, Max(LMin, LMax - LPage + 1));
    ScrollWindowTo(FContainer, SB_VERT, LNewPos, True);
  end;

  Invalidate;
end;

procedure TIDEScrollMinimap.DrawFormWindow(const AClientBox: TRect);
var
  LTitle: TRect;
  LButtonSize: Integer;
  LButtonTop: Integer;
  LRight: Integer;
  LButton: TRect;
  LIndex: Integer;
  LTextRect: TRect;
  LOldHeight: Integer;
begin
  // 클라이언트(캡처 이미지).
  Canvas.StretchDraw(AClientBox, FBitmap);

  LTitle := Rect(AClientBox.Left, AClientBox.Top - TITLEBAR_H, AClientBox.Right, AClientBox.Top);

  // 캡션바 배경.
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ThemedColor(clActiveCaption);
  Canvas.FillRect(LTitle);

  // 우측 창 버튼 3개.
  LButtonSize := TITLEBAR_H - 9;
  if LButtonSize < 4 then
  begin
    LButtonSize := 4;
  end;

  LButtonTop := LTitle.Top + (TITLEBAR_H - LButtonSize) div 2;
  LRight := LTitle.Right - 4;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := ThemedColor(clCaptionText);
  Canvas.Pen.Width := 1;
  for LIndex := 0 to 2 do
  begin
    LButton := Rect(LRight - LButtonSize, LButtonTop, LRight, LButtonTop + LButtonSize);
    if LButton.Left <= LTitle.Left + 2 then
    begin
      Break;
    end;

    Canvas.Rectangle(LButton);
    LRight := LButton.Left - 3;
  end;

  // 폼의 실제 캡션 텍스트(버튼 영역 제외, 말줄임).
  LOldHeight := Canvas.Font.Height;
  Canvas.Font.Height := -(TITLEBAR_H - 5);
  Canvas.Font.Style := [];
  Canvas.Font.Color := ThemedColor(clCaptionText);
  Canvas.Brush.Style := bsClear;
  LTextRect := Rect(LTitle.Left + 4, LTitle.Top, LRight - 2, LTitle.Bottom);
  if (LTextRect.Right > LTextRect.Left) and (FFormCaption <> '') then
  begin
    DrawText(Canvas.Handle, PChar(FFormCaption), Length(FFormCaption), LTextRect,
      DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or DT_NOPREFIX);
  end;

  Canvas.Font.Height := LOldHeight;

  // 창 외곽선(타이틀바 + 클라이언트).
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := ThemedColor(clActiveBorder);
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(LTitle.Left, LTitle.Top, AClientBox.Right, AClientBox.Bottom);
end;

procedure TIDEScrollMinimap.Paint;
var
  LText: string;
  LWindow: TRect;
begin
  // 미니맵 바탕(컨테이너 밖 영역).
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ThemedColor(clBtnShadow);
  Canvas.FillRect(ClientRect);

  RecomputeLayout;

  if (not FHasDesigner) or FFormBox.IsEmpty then
  begin
    LText := '디자이너 없음';
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := ThemedColor(clGrayText);
    Canvas.TextOut(
      (ClientWidth - Canvas.TextWidth(LText)) div 2,
      (ClientHeight - Canvas.TextHeight(LText)) div 2,
      LText);
    Canvas.Brush.Style := bsSolid;
    DrawCreditLink;
    Exit;
  end;

  // 캔버스 = 컨테이너(디자이너 표면) 영역.
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ThemedColor(clBtnFace);
  Canvas.FillRect(FCanvasRect);
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := ThemedColor(clActiveBorder);
  Canvas.Rectangle(FCanvasRect);

  if FDragging then
  begin
    // 드래그 중에는 폼 창의 점선 윤곽만 표시(실제 이동은 드롭 시).
    LWindow := FormWindowRect(FDragBox);
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := ThemedColor(clHighlight);
    Canvas.Pen.Width := 1;
    Canvas.Pen.Style := psDot;
    Canvas.Rectangle(LWindow);
    Canvas.Pen.Style := psSolid;
  end
  else
  begin
    // 컨테이너 안의 실제 위치/크기로 폼을 그린다(넘치면 경계에서 잘림).
    DrawFormWindow(FFormBox);
  end;

  // 우하단 크레딧 링크는 항상 마지막에 그린다.
  DrawCreditLink;
end;

procedure TIDEScrollMinimap.DrawCreditLink;
var
  LWidth: Integer;
  LHeight: Integer;
begin
  // 호버 시 강조색 + 굵게, 평소엔 링크색 + 밑줄.
  if FLinkHover then
  begin
    Canvas.Font.Style := [fsUnderline, fsBold];
    Canvas.Font.Color := ThemedColor(clHighlight);
  end
  else
  begin
    Canvas.Font.Style := [fsUnderline];
    Canvas.Font.Color := ThemedColor(clHotLight);
  end;

  Canvas.Font.Height := 0;
  Canvas.Brush.Style := bsClear;

  LWidth := Canvas.TextWidth(CREDIT_TEXT);
  LHeight := Canvas.TextHeight(CREDIT_TEXT);

  FLinkRect.Right := ClientWidth - CREDIT_MARGIN;
  FLinkRect.Bottom := ClientHeight - CREDIT_MARGIN;
  FLinkRect.Left := FLinkRect.Right - LWidth;
  FLinkRect.Top := FLinkRect.Bottom - LHeight;

  Canvas.TextOut(FLinkRect.Left, FLinkRect.Top, CREDIT_TEXT);

  Canvas.Font.Style := [];
  Canvas.Brush.Style := bsSolid;
end;

procedure TIDEScrollMinimap.OpenCreditLink;
begin
  ShellExecute(0, 'open', CREDIT_URL, nil, nil, SW_SHOWNORMAL);
end;

procedure TIDEScrollMinimap.UpdateLinkHover(const AX: Integer; const AY: Integer);
var
  LHover: Boolean;
begin
  LHover := FLinkRect.Contains(Point(AX, AY));
  if LHover <> FLinkHover then
  begin
    FLinkHover := LHover;
    Invalidate;
  end;
end;

procedure TIDEScrollMinimap.CMMouseLeave(var AMessage: TMessage);
begin
  inherited;

  if FLinkHover then
  begin
    FLinkHover := False;
    Invalidate;
  end;
end;

function TIDEScrollMinimap.DoMouseWheel(AShift: TShiftState; AWheelDelta: Integer; AMousePos: TPoint): Boolean;
var
  LStep: Integer;
begin
  Result := False;
  if (not FHasDesigner) or (FContainer = 0) then
  begin
    Exit;
  end;

  // 휠 위로 = 위/왼쪽으로 스크롤. Shift 와 함께면 가로.
  LStep := -(AWheelDelta div WHEEL_DELTA) * WHEEL_STEP_PX;
  if LStep = 0 then
  begin
    if AWheelDelta > 0 then
    begin
      LStep := -WHEEL_STEP_PX;
    end
    else
    begin
      LStep := WHEEL_STEP_PX;
    end;
  end;

  if ssShift in AShift then
  begin
    ScrollContainerBy(LStep, 0);
  end
  else
  begin
    ScrollContainerBy(0, LStep);
  end;

  Result := True;
end;

procedure TIDEScrollMinimap.UpdateCapture;
var
  LForm: TWinControl;
begin
  if not TryGetDesignedForm(LForm) then
  begin
    FHasDesigner := False;
    FContainer := 0;
    FFormHandle := 0;
    FFormCaption := '';
    Invalidate;
    Exit;
  end;

  FFormHandle := LForm.Handle;
  FContainer := FindScrollContainer(FFormHandle);
  FFormCaption := GetWindowCaption(FFormHandle);

  if not CaptureWindowImage(FFormHandle, FBitmap) then
  begin
    // 캡처 실패 시 직전 비트맵을 유지하되 디자이너 자체는 존재로 간주.
    FHasDesigner := FBitmap.Width > 0;
  end
  else
  begin
    FHasDesigner := True;
  end;

  Invalidate;
end;

procedure TIDEScrollMinimap.RefreshViewport;
var
  LPos: TPoint;
begin
  if FDragging or (not FHasDesigner) or (FContainer = 0) then
  begin
    Exit;
  end;

  // 외부 스크롤로 폼 위치가 바뀌었으면 다시 그린다.
  if FormPosInContainer(LPos) then
  begin
    if (LPos.X <> FLastFormPos.X) or (LPos.Y <> FLastFormPos.Y) then
    begin
      FLastFormPos := LPos;
      Invalidate;
    end;
  end;
end;

procedure TIDEScrollMinimap.MouseDown(AButton: TMouseButton; AShift: TShiftState; AX: Integer; AY: Integer);
var
  LWindow: TRect;
begin
  inherited MouseDown(AButton, AShift, AX, AY);

  // 크레딧 링크 클릭은 다른 동작보다 우선한다.
  if (AButton = mbLeft) and FLinkRect.Contains(Point(AX, AY)) then
  begin
    OpenCreditLink;
    Exit;
  end;

  if (AButton = mbLeft) and FHasDesigner and (not FFormBox.IsEmpty) then
  begin
    LWindow := FormWindowRect(FFormBox);
    if LWindow.Contains(Point(AX, AY)) then
    begin
      FDragging := True;
      FDragGrab := Point(AX - FFormBox.Left, AY - FFormBox.Top);
      FDragBox := FFormBox;
      Cursor := crSizeAll;
      Invalidate;
    end;
  end;
end;

procedure TIDEScrollMinimap.MouseMove(AShift: TShiftState; AX: Integer; AY: Integer);
var
  LWindow: TRect;
begin
  inherited MouseMove(AShift, AX, AY);

  if FDragging then
  begin
    // 커서를 따라 폼 박스를 이동(스크롤 범위로 보정)시킨 점선 윤곽만 갱신.
    FDragBox.Left := AX - FDragGrab.X;
    FDragBox.Top := AY - FDragGrab.Y;
    ClampFormBox(FDragBox);
    Invalidate;
    Exit;
  end;

  // 크레딧 링크 호버 효과 갱신.
  UpdateLinkHover(AX, AY);

  // 폼 창 위에서는 이동 커서로 드래그 가능함을 안내한다.
  LWindow := FormWindowRect(FFormBox);
  if FLinkRect.Contains(Point(AX, AY)) then
  begin
    Cursor := crHandPoint;
  end
  else
  if FHasDesigner and (not FFormBox.IsEmpty) and LWindow.Contains(Point(AX, AY)) then
  begin
    Cursor := crSizeAll;
  end
  else
  begin
    Cursor := crDefault;
  end;
end;

procedure TIDEScrollMinimap.MouseUp(AButton: TMouseButton; AShift: TShiftState; AX: Integer; AY: Integer);
begin
  inherited MouseUp(AButton, AShift, AX, AY);

  if AButton = mbLeft then
  begin
    if FDragging then
    begin
      FDragging := False;
      // 드롭 위치로 실제 스크롤.
      ApplyDragScroll(FDragBox);
    end;

    if FLinkRect.Contains(Point(AX, AY)) then
    begin
      Cursor := crHandPoint;
    end
    else
    begin
      Cursor := crDefault;
    end;
  end;
end;

end.
