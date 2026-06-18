unit IDEScroll.MinimapControl;

// 폼 디자이너 미니맵 컨트롤.
//   - 미니맵 캔버스 = 디자이너의 전체 스크롤 영역(≈ 폼 전체).
//   - 그 위에 폼 콘텐츠(캡처 이미지)를 깔아 폼 전체 모습을 보여준다.
//   - 현재 보이는 영역(뷰포트)을 강조 박스로 표시한다. 이 박스를 드래그/드롭
//     하거나 미니맵 위에서 마우스 휠을 굴리면 디자이너가 그만큼 스크롤된다.
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
    FFormHandle: HWND;
    FHasDesigner: Boolean;
    FLastScroll: TPoint;
    FLinkHover: Boolean;
    FLinkRect: TRect;
    FScale: Double;
    FViewBox: TRect;
    function  ContainerClientSize(out AWidth: Integer; out AHeight: Integer): Boolean;
    function  FormPosInContainer(out APos: TPoint): Boolean;
    procedure ApplyViewBoxScroll(const ABox: TRect);
    procedure ClampViewBox(var ABox: TRect);
    procedure FillTranslucent(const ARect: TRect; const AColor: TColor; const AAlpha: Byte);
    procedure DrawCreditLink;
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

    // 스크롤 위치가 바뀌었으면 다시 그린다(가벼운 작업, 타이머에서 호출).
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
  WHEEL_STEP_PX = 48;
  CREDIT_TEXT = 'by DelMadang';
  CREDIT_URL = 'https://cafe.naver.com/delmadang';
  // 채도를 낮춘 노랑(머스터드) 계열. TColor 는 $00BBGGRR.
  CREDIT_COLOR = TColor($006EAFBE);
  CREDIT_HOVER_COLOR = TColor($0082D2E1);

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

procedure TIDEScrollMinimap.RecomputeLayout;
var
  LInner: TRect;
  LInnerW: Integer;
  LInnerH: Integer;
  LFormW: Integer;
  LFormH: Integer;
  LContW: Integer;
  LContH: Integer;
  LHPos: Integer;
  LHPage: Integer;
  LHMin: Integer;
  LHMax: Integer;
  LVPos: Integer;
  LVPage: Integer;
  LVMin: Integer;
  LVMax: Integer;
  LSurfaceW: Integer;
  LSurfaceH: Integer;
  LScrollX: Integer;
  LScrollY: Integer;
  LFormPos: TPoint;
begin
  FCanvasRect := TRect.Empty;
  FFormBox := TRect.Empty;
  FViewBox := TRect.Empty;
  FScale := 0;

  LFormW := FBitmap.Width;
  LFormH := FBitmap.Height;
  if (LFormW <= 0) or (LFormH <= 0) then
  begin
    Exit;
  end;

  if not ContainerClientSize(LContW, LContH) then
  begin
    LContW := LFormW;
    LContH := LFormH;
  end;

  // 컨테이너 스크롤 정보 → 전체 스크롤 영역(표면) 크기와 현재 스크롤 위치.
  ReadScroll(FContainer, SB_HORZ, LHPos, LHPage, LHMin, LHMax);
  ReadScroll(FContainer, SB_VERT, LVPos, LVPage, LVMin, LVMax);

  if (LHPage > 0) and (LHMax - LHMin + 1 > LHPage) then
  begin
    LSurfaceW := LHMax - LHMin + 1;
    LScrollX := LHPos - LHMin;
  end
  else
  begin
    LSurfaceW := LContW;
    LScrollX := 0;
  end;

  if (LVPage > 0) and (LVMax - LVMin + 1 > LVPage) then
  begin
    LSurfaceH := LVMax - LVMin + 1;
    LScrollY := LVPos - LVMin;
  end
  else
  begin
    LSurfaceH := LContH;
    LScrollY := 0;
  end;

  FLastScroll := Point(LScrollX, LScrollY);

  if not FormPosInContainer(LFormPos) then
  begin
    LFormPos := Point(0, 0);
  end;

  // 캔버스(표면)를 미니맵 안에 비율 유지로 맞춘다.
  LInner := ClientRect;
  LInner.Inflate(-MINIMAP_MARGIN, -MINIMAP_MARGIN);
  LInnerW := LInner.Right - LInner.Left;
  LInnerH := LInner.Bottom - LInner.Top;
  if (LInnerW <= 0) or (LInnerH <= 0) then
  begin
    Exit;
  end;

  FScale := Min(LInnerW / LSurfaceW, LInnerH / LSurfaceH);

  FCanvasRect.Left := LInner.Left + (LInnerW - Round(LSurfaceW * FScale)) div 2;
  FCanvasRect.Top := LInner.Top + (LInnerH - Round(LSurfaceH * FScale)) div 2;
  FCanvasRect.Right := FCanvasRect.Left + Round(LSurfaceW * FScale);
  FCanvasRect.Bottom := FCanvasRect.Top + Round(LSurfaceH * FScale);

  // 폼 콘텐츠 = 표면 위 폼 위치(현재 스크롤 + 컨테이너 내 폼 위치).
  FFormBox.Left := FCanvasRect.Left + Round((LScrollX + LFormPos.X) * FScale);
  FFormBox.Top := FCanvasRect.Top + Round((LScrollY + LFormPos.Y) * FScale);
  FFormBox.Right := FFormBox.Left + Round(LFormW * FScale);
  FFormBox.Bottom := FFormBox.Top + Round(LFormH * FScale);

  // 현재 보이는 영역(뷰포트) = 표면 위 [스크롤, 스크롤+페이지].
  FViewBox.Left := FCanvasRect.Left + Round(LScrollX * FScale);
  FViewBox.Top := FCanvasRect.Top + Round(LScrollY * FScale);
  if LHPage > 0 then
  begin
    FViewBox.Right := FViewBox.Left + Round(LHPage * FScale);
  end
  else
  begin
    FViewBox.Right := FCanvasRect.Right;
  end;

  if LVPage > 0 then
  begin
    FViewBox.Bottom := FViewBox.Top + Round(LVPage * FScale);
  end
  else
  begin
    FViewBox.Bottom := FCanvasRect.Bottom;
  end;
end;

procedure TIDEScrollMinimap.ClampViewBox(var ABox: TRect);
var
  LBoxW: Integer;
  LBoxH: Integer;
begin
  LBoxW := ABox.Right - ABox.Left;
  LBoxH := ABox.Bottom - ABox.Top;

  ABox.Left := EnsureRange(ABox.Left, FCanvasRect.Left, FCanvasRect.Right - LBoxW);
  ABox.Top := EnsureRange(ABox.Top, FCanvasRect.Top, FCanvasRect.Bottom - LBoxH);
  ABox.Right := ABox.Left + LBoxW;
  ABox.Bottom := ABox.Top + LBoxH;
end;

procedure TIDEScrollMinimap.ApplyViewBoxScroll(const ABox: TRect);
var
  LTargetScrollX: Integer;
  LTargetScrollY: Integer;
  LHPos: Integer;
  LHPage: Integer;
  LHMin: Integer;
  LHMax: Integer;
  LVPos: Integer;
  LVPage: Integer;
  LVMin: Integer;
  LVMax: Integer;
begin
  if (FContainer = 0) or (FScale <= 0) then
  begin
    Exit;
  end;

  // 박스의 표면 위치(픽셀) = 목표 스크롤 위치.
  LTargetScrollX := Round((ABox.Left - FCanvasRect.Left) / FScale);
  LTargetScrollY := Round((ABox.Top - FCanvasRect.Top) / FScale);

  ReadScroll(FContainer, SB_HORZ, LHPos, LHPage, LHMin, LHMax);
  if (LHPage > 0) and (LHMax - LHMin + 1 > LHPage) then
  begin
    LTargetScrollX := EnsureRange(LTargetScrollX + LHMin, LHMin, Max(LHMin, LHMax - LHPage + 1));
    ScrollWindowTo(FContainer, SB_HORZ, LTargetScrollX, True);
  end;

  ReadScroll(FContainer, SB_VERT, LVPos, LVPage, LVMin, LVMax);
  if (LVPage > 0) and (LVMax - LVMin + 1 > LVPage) then
  begin
    LTargetScrollY := EnsureRange(LTargetScrollY + LVMin, LVMin, Max(LVMin, LVMax - LVPage + 1));
    ScrollWindowTo(FContainer, SB_VERT, LTargetScrollY, True);
  end;

  Invalidate;
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

procedure TIDEScrollMinimap.Paint;
var
  LText: string;
begin
  // 미니맵 바탕(표면 밖).
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ThemedColor(clBtnShadow);
  Canvas.FillRect(ClientRect);

  RecomputeLayout;

  if (not FHasDesigner) or FCanvasRect.IsEmpty then
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

  // 표면(전체 스크롤 영역 = 폼 영역) 바탕. 미니맵 배경과 다른 색으로 대비.
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ThemedColor(clWindow);
  Canvas.FillRect(FCanvasRect);

  // 폼 콘텐츠.
  Canvas.StretchDraw(FFormBox, FBitmap);
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := ThemedColor(clGrayText);
  Canvas.Rectangle(FFormBox);

  // 표면 경계.
  Canvas.Pen.Color := ThemedColor(clActiveBorder);
  Canvas.Rectangle(FCanvasRect);

  // 현재 보이는 영역(드래그 가능). 반투명 바탕 + 테두리.
  // 드래그 중에는 점선 윤곽으로 목표 위치를 표시.
  Canvas.Brush.Style := bsClear;
  if FDragging then
  begin
    FillTranslucent(FDragBox, ThemedColor(clHighlight), 60);
    Canvas.Pen.Color := ThemedColor(clHighlight);
    Canvas.Pen.Width := 1;
    Canvas.Pen.Style := psDot;
    Canvas.Rectangle(FDragBox);
    Canvas.Pen.Style := psSolid;
  end
  else
  begin
    FillTranslucent(FViewBox, ThemedColor(clHighlight), 60);
    Canvas.Pen.Color := ThemedColor(clHighlight);
    Canvas.Pen.Width := 2;
    Canvas.Rectangle(FViewBox);
  end;

  // 우하단 크레딧 링크는 항상 마지막에 그린다.
  DrawCreditLink;
end;

procedure TIDEScrollMinimap.DrawCreditLink;
var
  LWidth: Integer;
  LHeight: Integer;
begin
  // 호버 시 약간 밝게 + 굵게, 평소엔 채도 낮춘 노랑 + 밑줄.
  if FLinkHover then
  begin
    Canvas.Font.Style := [fsUnderline, fsBold];
    Canvas.Font.Color := CREDIT_HOVER_COLOR;
  end
  else
  begin
    Canvas.Font.Style := [fsUnderline];
    Canvas.Font.Color := CREDIT_COLOR;
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

procedure TIDEScrollMinimap.FillTranslucent(const ARect: TRect; const AColor: TColor; const AAlpha: Byte);
var
  LBitmap: TBitmap;
  LBlend: TBlendFunction;
begin
  if (ARect.Right - ARect.Left <= 0) or (ARect.Bottom - ARect.Top <= 0) then
  begin
    Exit;
  end;

  // 1x1 색 비트맵을 상수 알파로 늘려 칠해 반투명 효과를 낸다.
  LBitmap := TBitmap.Create;
  try
    LBitmap.PixelFormat := pf24bit;
    LBitmap.SetSize(1, 1);
    LBitmap.Canvas.Brush.Color := ColorToRGB(AColor);
    LBitmap.Canvas.FillRect(Rect(0, 0, 1, 1));

    LBlend.BlendOp := AC_SRC_OVER;
    LBlend.BlendFlags := 0;
    LBlend.SourceConstantAlpha := AAlpha;
    LBlend.AlphaFormat := 0;

    Winapi.Windows.AlphaBlend(Canvas.Handle, ARect.Left, ARect.Top,
      ARect.Right - ARect.Left, ARect.Bottom - ARect.Top,
      LBitmap.Canvas.Handle, 0, 0, 1, 1, LBlend);
  finally
    LBitmap.Free;
  end;
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

  // 휠 위로 = 위/왼쪽으로 스크롤. Ctrl 와 함께면 가로(메인 훅과 동일).
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

  if ssCtrl in AShift then
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
    Invalidate;
    Exit;
  end;

  FFormHandle := LForm.Handle;
  FContainer := FindScrollContainer(FFormHandle);

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
  LPos: Integer;
  LPage: Integer;
  LMin: Integer;
  LMax: Integer;
  LScrollX: Integer;
  LScrollY: Integer;
begin
  if FDragging or (not FHasDesigner) or (FContainer = 0) then
  begin
    Exit;
  end;

  // 외부 스크롤로 위치가 바뀌었으면 다시 그린다.
  ReadScroll(FContainer, SB_HORZ, LPos, LPage, LMin, LMax);
  LScrollX := LPos - LMin;
  ReadScroll(FContainer, SB_VERT, LPos, LPage, LMin, LMax);
  LScrollY := LPos - LMin;

  if (LScrollX <> FLastScroll.X) or (LScrollY <> FLastScroll.Y) then
  begin
    FLastScroll := Point(LScrollX, LScrollY);
    Invalidate;
  end;
end;

procedure TIDEScrollMinimap.MouseDown(AButton: TMouseButton; AShift: TShiftState; AX: Integer; AY: Integer);
begin
  inherited MouseDown(AButton, AShift, AX, AY);

  // 크레딧 링크 클릭은 다른 동작보다 우선한다.
  if (AButton = mbLeft) and FLinkRect.Contains(Point(AX, AY)) then
  begin
    OpenCreditLink;
    Exit;
  end;

  if (AButton = mbLeft) and FHasDesigner and (not FViewBox.IsEmpty) then
  begin
    FDragging := True;
    FDragBox := FViewBox;

    // 박스 밖을 누르면 그 지점을 박스 중심으로 옮긴 뒤 드래그 시작.
    if not FViewBox.Contains(Point(AX, AY)) then
    begin
      FDragBox.Offset(
        AX - (FViewBox.Left + FViewBox.Right) div 2,
        AY - (FViewBox.Top + FViewBox.Bottom) div 2);
      ClampViewBox(FDragBox);
    end;

    FDragGrab := Point(AX - FDragBox.Left, AY - FDragBox.Top);
    Cursor := crSizeAll;
    Invalidate;
  end;
end;

procedure TIDEScrollMinimap.MouseMove(AShift: TShiftState; AX: Integer; AY: Integer);
begin
  inherited MouseMove(AShift, AX, AY);

  if FDragging then
  begin
    FDragBox.Offset((AX - FDragGrab.X) - FDragBox.Left, (AY - FDragGrab.Y) - FDragBox.Top);
    ClampViewBox(FDragBox);
    Invalidate;
    Exit;
  end;

  // 크레딧 링크 호버 효과 갱신.
  UpdateLinkHover(AX, AY);

  // 뷰포트 박스 위에서는 이동 커서로 안내한다.
  if FLinkRect.Contains(Point(AX, AY)) then
  begin
    Cursor := crHandPoint;
  end
  else
  if FHasDesigner and (not FViewBox.IsEmpty) and FViewBox.Contains(Point(AX, AY)) then
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
      ApplyViewBoxScroll(FDragBox);
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
