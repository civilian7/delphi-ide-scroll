unit IDEScroll.MinimapControl;

// 폼 디자이너 미니맵 컨트롤.
//   - 디자인 중인 폼 전체를 축소 렌더(가로세로 비율 유지)
//   - 현재 보이는 영역을 뷰포트 사각형으로 오버레이
//   - 미니맵을 마우스로 드래그하면 디자이너가 해당 위치로 스크롤
// ToolsAPI/도킹을 알지 못하는 순수 VCL 컨트롤이며, 디자이너 접근은
// IDEScroll.DesignerIntrospect 헬퍼에 위임한다.
// 인라인 변수는 구형 Delphi 호환을 위해 사용하지 않는다.

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
    FContainer: HWND;
    FDragging: Boolean;
    FDragViewRect: TRect;
    FDrawRect: TRect;
    FFormCaption: string;
    FFormHandle: HWND;
    FHasDesigner: Boolean;
    FLinkHover: Boolean;
    FLinkRect: TRect;
    FView: TRect;
    function  ComputeDrawRect: TRect;
    function  DragTargetRect(const AX: Integer; const AY: Integer): TRect;
    function  ViewportRect(const ADrawRect: TRect): TRect;
    procedure DrawCreditLink;
    procedure DrawWindowTitleBar(const AClientRect: TRect);
    procedure OpenCreditLink;
    procedure SyncScrollFromContainer;
    procedure ScrollToPoint(const AX: Integer; const AY: Integer; const AFinal: Boolean);
    procedure UpdateLinkHover(const AX: Integer; const AY: Integer);
  protected
    procedure CMMouseLeave(var AMessage: TMessage); message CM_MOUSELEAVE;
    procedure MouseDown(AButton: TMouseButton; AShift: TShiftState; AX: Integer; AY: Integer); override;
    procedure MouseMove(AShift: TShiftState; AX: Integer; AY: Integer); override;
    procedure MouseUp(AButton: TMouseButton; AShift: TShiftState; AX: Integer; AY: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // 디자인 폼을 다시 캡처하고 스크롤 정보를 갱신한다(무거운 작업).
    procedure UpdateCapture;

    // 스크롤 정보만 다시 읽어 뷰포트가 바뀌었으면 다시 그린다(가벼운 작업).
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
  MINIMAP_MARGIN = 2;
  CREDIT_MARGIN = 8;
  TITLEBAR_H = 16;
  CREDIT_TEXT = 'by DelMadang';
  CREDIT_URL = 'https://cafe.naver.com/delmadang';

constructor TIDEScrollMinimap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBitmap := TBitmap.Create;
  FBitmap.PixelFormat := pf24bit;
  FContainer := 0;
  FDragging := False;
  FHasDesigner := False;

  // 더블 버퍼링으로 드래그 시 깜빡임/끊김을 줄인다.
  DoubleBuffered := True;
  ControlStyle := ControlStyle + [csOpaque];
end;

destructor TIDEScrollMinimap.Destroy;
begin
  FBitmap.Free;
  inherited Destroy;
end;

function TIDEScrollMinimap.ComputeDrawRect: TRect;
var
  LClient: TRect;
  LAvailW: Integer;
  LAvailH: Integer;
  LScale: Double;
  LScaleX: Double;
  LScaleY: Double;
  LDrawW: Integer;
  LDrawH: Integer;
begin
  Result := TRect.Empty;
  if (FBitmap.Width <= 0) or (FBitmap.Height <= 0) then
  begin
    Exit;
  end;

  LClient := ClientRect;
  LAvailW := (LClient.Right - LClient.Left) - MINIMAP_MARGIN * 2;
  // 타이틀바 높이만큼 세로 공간을 미리 확보한다.
  LAvailH := (LClient.Bottom - LClient.Top) - MINIMAP_MARGIN * 2 - TITLEBAR_H;
  if (LAvailW <= 0) or (LAvailH <= 0) then
  begin
    Exit;
  end;

  // 가로세로 비율을 유지하며 가용 영역에 맞춘다.
  LScaleX := LAvailW / FBitmap.Width;
  LScaleY := LAvailH / FBitmap.Height;
  if LScaleX < LScaleY then
  begin
    LScale := LScaleX;
  end
  else
  begin
    LScale := LScaleY;
  end;

  // 원본보다 크게 확대하지는 않는다.
  if LScale > 1.0 then
  begin
    LScale := 1.0;
  end;

  LDrawW := Round(FBitmap.Width * LScale);
  LDrawH := Round(FBitmap.Height * LScale);

  // 타이틀바(위) + 클라이언트(아래) 전체를 가운데 정렬한다. Result 는 클라이언트 영역.
  Result.Left := LClient.Left + (LClient.Right - LClient.Left - LDrawW) div 2;
  Result.Top := LClient.Top + (LClient.Bottom - LClient.Top - (LDrawH + TITLEBAR_H)) div 2 + TITLEBAR_H;
  Result.Right := Result.Left + LDrawW;
  Result.Bottom := Result.Top + LDrawH;
end;

function TIDEScrollMinimap.ViewportRect(const ADrawRect: TRect): TRect;
var
  LDrawW: Integer;
  LDrawH: Integer;
  LFormW: Integer;
  LFormH: Integer;
  LLeftFrac: Double;
  LWidthFrac: Double;
  LTopFrac: Double;
  LHeightFrac: Double;
begin
  Result := ADrawRect;

  LDrawW := ADrawRect.Right - ADrawRect.Left;
  LDrawH := ADrawRect.Bottom - ADrawRect.Top;
  LFormW := FBitmap.Width;
  LFormH := FBitmap.Height;
  if (LDrawW <= 0) or (LDrawH <= 0) or (LFormW <= 0) or (LFormH <= 0) then
  begin
    Exit;
  end;

  // 가시영역(폼 픽셀)을 분율로 환산. 폼이 전부 보이면 분율은 1 이 된다.
  LWidthFrac := Min(1.0, (FView.Right - FView.Left) / LFormW);
  LHeightFrac := Min(1.0, (FView.Bottom - FView.Top) / LFormH);
  LLeftFrac := Min(Max(0.0, FView.Left / LFormW), 1.0 - LWidthFrac);
  LTopFrac := Min(Max(0.0, FView.Top / LFormH), 1.0 - LHeightFrac);

  Result.Left := ADrawRect.Left + Round(LLeftFrac * LDrawW);
  Result.Top := ADrawRect.Top + Round(LTopFrac * LDrawH);
  Result.Right := Result.Left + Round(LWidthFrac * LDrawW);
  Result.Bottom := Result.Top + Round(LHeightFrac * LDrawH);
end;

function TIDEScrollMinimap.DragTargetRect(const AX: Integer; const AY: Integer): TRect;
var
  LDrawW: Integer;
  LDrawH: Integer;
  LFormW: Integer;
  LFormH: Integer;
  LCenterFracX: Double;
  LCenterFracY: Double;
  LWidthFrac: Double;
  LHeightFrac: Double;
  LLeftFrac: Double;
  LTopFrac: Double;
begin
  Result := TRect.Empty;
  if FDrawRect.IsEmpty then
  begin
    Exit;
  end;

  LDrawW := FDrawRect.Right - FDrawRect.Left;
  LDrawH := FDrawRect.Bottom - FDrawRect.Top;
  LFormW := FBitmap.Width;
  LFormH := FBitmap.Height;
  if (LDrawW <= 0) or (LDrawH <= 0) or (LFormW <= 0) or (LFormH <= 0) then
  begin
    Exit;
  end;

  // 커서를 뷰포트 중심으로 두는 위치를 계산한다.
  LWidthFrac := Min(1.0, (FView.Right - FView.Left) / LFormW);
  LHeightFrac := Min(1.0, (FView.Bottom - FView.Top) / LFormH);
  LCenterFracX := (AX - FDrawRect.Left) / LDrawW;
  LCenterFracY := (AY - FDrawRect.Top) / LDrawH;
  LLeftFrac := Min(Max(0.0, LCenterFracX - LWidthFrac / 2), 1.0 - LWidthFrac);
  LTopFrac := Min(Max(0.0, LCenterFracY - LHeightFrac / 2), 1.0 - LHeightFrac);

  Result.Left := FDrawRect.Left + Round(LLeftFrac * LDrawW);
  Result.Top := FDrawRect.Top + Round(LTopFrac * LDrawH);
  Result.Right := Result.Left + Round(LWidthFrac * LDrawW);
  Result.Bottom := Result.Top + Round(LHeightFrac * LDrawH);
end;

procedure TIDEScrollMinimap.Paint;
var
  LDrawRect: TRect;
  LViewRect: TRect;
  LText: string;
begin
  Canvas.Brush.Color := ThemedColor(clBtnFace);
  Canvas.FillRect(ClientRect);

  if (not FHasDesigner) or (FBitmap.Width <= 0) or (FBitmap.Height <= 0) then
  begin
    FDrawRect := TRect.Empty;
    LText := '디자이너 없음';
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := ThemedColor(clGrayText);
    Canvas.TextOut(
      (ClientWidth - Canvas.TextWidth(LText)) div 2,
      (ClientHeight - Canvas.TextHeight(LText)) div 2,
      LText);
    Canvas.Brush.Style := bsSolid;
  end
  else
  begin
    LDrawRect := ComputeDrawRect;
    FDrawRect := LDrawRect;
    if not LDrawRect.IsEmpty then
    begin
      // 캡처한 클라이언트 이미지를 그리고, 그 위에 실제 폼 캡션으로 타이틀바를 입혀
      // 실제 창처럼 보이게 한다.
      Canvas.StretchDraw(LDrawRect, FBitmap);
      DrawWindowTitleBar(LDrawRect);

      if FDragging then
      begin
        // 드래그 중에는 이동 목표를 점선 사각형으로만 표시(실제 스크롤은 드롭 시).
        Canvas.Brush.Style := bsClear;
        Canvas.Pen.Color := ThemedColor(clHighlight);
        Canvas.Pen.Width := 1;
        Canvas.Pen.Style := psDot;
        Canvas.Rectangle(FDragViewRect);
        Canvas.Pen.Style := psSolid;
      end
      else
      begin
        // 현재 보이는 영역을 강조 사각형으로 표시한다.
        LViewRect := ViewportRect(LDrawRect);
        Canvas.Brush.Style := bsClear;
        Canvas.Pen.Color := ThemedColor(clHighlight);
        Canvas.Pen.Width := 2;
        Canvas.Pen.Style := psSolid;
        Canvas.Rectangle(LViewRect);
      end;
    end;
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

procedure TIDEScrollMinimap.DrawWindowTitleBar(const AClientRect: TRect);
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
  LTitle := Rect(AClientRect.Left, AClientRect.Top - TITLEBAR_H, AClientRect.Right, AClientRect.Top);

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

  // 타이틀바 + 클라이언트를 감싸는 창 외곽선.
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := ThemedColor(clActiveBorder);
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(LTitle.Left, LTitle.Top, AClientRect.Right, AClientRect.Bottom);
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
    FView := TRect.Empty;
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

  if FContainer <> 0 then
  begin
    GetVisibleRegion(FFormHandle, FContainer, FView);
  end;

  Invalidate;
end;

procedure TIDEScrollMinimap.RefreshViewport;
var
  LNew: TRect;
begin
  if (not FHasDesigner) or (FContainer = 0) then
  begin
    Exit;
  end;

  if not GetVisibleRegion(FFormHandle, FContainer, LNew) then
  begin
    Exit;
  end;

  if LNew <> FView then
  begin
    FView := LNew;
    Invalidate;
  end;
end;

procedure TIDEScrollMinimap.SyncScrollFromContainer;
begin
  // 실제 컨테이너 가시영역을 다시 읽어 뷰포트 표시를 동기화한다.
  if FContainer = 0 then
  begin
    Exit;
  end;

  GetVisibleRegion(FFormHandle, FContainer, FView);
end;

procedure TIDEScrollMinimap.ScrollToPoint(const AX: Integer; const AY: Integer; const AFinal: Boolean);
var
  LDrawW: Integer;
  LDrawH: Integer;
  LFormW: Integer;
  LFormH: Integer;
  LViewW: Integer;
  LViewH: Integer;
  LCenterFracX: Double;
  LCenterFracY: Double;
  LTargetX: Integer;
  LTargetY: Integer;
begin
  if (FContainer = 0) or FDrawRect.IsEmpty then
  begin
    Exit;
  end;

  LDrawW := FDrawRect.Right - FDrawRect.Left;
  LDrawH := FDrawRect.Bottom - FDrawRect.Top;
  LFormW := FBitmap.Width;
  LFormH := FBitmap.Height;
  if (LDrawW <= 0) or (LDrawH <= 0) or (LFormW <= 0) or (LFormH <= 0) then
  begin
    Exit;
  end;

  LViewW := FView.Right - FView.Left;
  LViewH := FView.Bottom - FView.Top;

  // 커서가 가리키는 지점을 가시영역의 중심으로 삼아 스크롤 오프셋(픽셀)을 구한다.
  LCenterFracX := (AX - FDrawRect.Left) / LDrawW;
  LCenterFracY := (AY - FDrawRect.Top) / LDrawH;

  // 폼이 가로로 넘칠 때만 가로 스크롤.
  if LFormW > LViewW then
  begin
    LTargetX := EnsureRange(Round(LCenterFracX * LFormW - LViewW / 2), 0, LFormW - LViewW);
    ScrollWindowTo(FContainer, SB_HORZ, LTargetX, AFinal);
  end;

  // 폼이 세로로 넘칠 때만 세로 스크롤.
  if LFormH > LViewH then
  begin
    LTargetY := EnsureRange(Round(LCenterFracY * LFormH - LViewH / 2), 0, LFormH - LViewH);
    ScrollWindowTo(FContainer, SB_VERT, LTargetY, AFinal);
  end;

  // 컨테이너가 실제로 이동한 위치를 다시 읽어 표시가 튀지 않게 한다.
  SyncScrollFromContainer;
  Invalidate;
end;

procedure TIDEScrollMinimap.MouseDown(AButton: TMouseButton; AShift: TShiftState; AX: Integer; AY: Integer);
begin
  inherited MouseDown(AButton, AShift, AX, AY);

  // 크레딧 링크 클릭은 드래그보다 우선한다.
  if (AButton = mbLeft) and FLinkRect.Contains(Point(AX, AY)) then
  begin
    OpenCreditLink;
    Exit;
  end;

  if (AButton = mbLeft) and FHasDesigner and (not FDrawRect.IsEmpty) then
  begin
    FDragging := True;
    // 드래그 중에는 이동(grab) 커서로 바꾼다.
    Cursor := crSizeAll;
    // 실제 스크롤은 하지 않고 목표 위치를 점선으로만 표시한다.
    FDragViewRect := DragTargetRect(AX, AY);
    Invalidate;
  end;
end;

procedure TIDEScrollMinimap.MouseMove(AShift: TShiftState; AX: Integer; AY: Integer);
begin
  inherited MouseMove(AShift, AX, AY);

  if FDragging then
  begin
    // 점선 목표 사각형만 갱신(실제 스크롤은 드롭 시).
    FDragViewRect := DragTargetRect(AX, AY);
    Invalidate;
    Exit;
  end;

  // 크레딧 링크 호버 효과 갱신.
  UpdateLinkHover(AX, AY);

  // 크레딧 링크나 드래그 가능 영역 위에서는 손 모양 커서로 안내한다.
  if FLinkRect.Contains(Point(AX, AY)) or
     (FHasDesigner and (not FDrawRect.IsEmpty) and FDrawRect.Contains(Point(AX, AY))) then
  begin
    Cursor := crHandPoint;
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
      // 드롭 시점에 실제로 해당 위치로 이동시킨다.
      FDragging := False;
      ScrollToPoint(AX, AY, True);
    end;

    FDragging := False;

    // 커서를 현재 위치에 맞게 되돌린다.
    if FLinkRect.Contains(Point(AX, AY)) or
       (FHasDesigner and (not FDrawRect.IsEmpty) and FDrawRect.Contains(Point(AX, AY))) then
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
