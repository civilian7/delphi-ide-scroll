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
    FDrawRect: TRect;
    FHasDesigner: Boolean;
    FHMax: Integer;
    FHMin: Integer;
    FHPage: Integer;
    FHPos: Integer;
    FLinkRect: TRect;
    FVMax: Integer;
    FVMin: Integer;
    FVPage: Integer;
    FVPos: Integer;
    function  ComputeDrawRect: TRect;
    function  ViewportRect(const ADrawRect: TRect): TRect;
    procedure DrawCreditLink;
    procedure DrawViewportWindow(const ARect: TRect);
    procedure OpenCreditLink;
    procedure SyncScrollFromContainer;
    procedure ScrollToPoint(const AX: Integer; const AY: Integer; const AFinal: Boolean);
  protected
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
  IDEScroll.DesignerIntrospect,
  IDEScroll.Theming;
{$ENDREGION}

const
  MINIMAP_MARGIN = 2;
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
  LAvailH := (LClient.Bottom - LClient.Top) - MINIMAP_MARGIN * 2;
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

  Result.Left := LClient.Left + (LClient.Right - LClient.Left - LDrawW) div 2;
  Result.Top := LClient.Top + (LClient.Bottom - LClient.Top - LDrawH) div 2;
  Result.Right := Result.Left + LDrawW;
  Result.Bottom := Result.Top + LDrawH;
end;

function TIDEScrollMinimap.ViewportRect(const ADrawRect: TRect): TRect;
var
  LDrawW: Integer;
  LDrawH: Integer;
  LHRange: Integer;
  LVRange: Integer;
  LLeftFrac: Double;
  LWidthFrac: Double;
  LTopFrac: Double;
  LHeightFrac: Double;
begin
  Result := ADrawRect;

  LDrawW := ADrawRect.Right - ADrawRect.Left;
  LDrawH := ADrawRect.Bottom - ADrawRect.Top;
  if (LDrawW <= 0) or (LDrawH <= 0) then
  begin
    Exit;
  end;

  // 가로 방향 분율 계산.
  LHRange := FHMax - FHMin + 1;
  if (LHRange <= 0) or (FHPage <= 0) or (FHPage >= LHRange) then
  begin
    LLeftFrac := 0;
    LWidthFrac := 1;
  end
  else
  begin
    LLeftFrac := (FHPos - FHMin) / LHRange;
    LWidthFrac := FHPage / LHRange;
  end;

  // 세로 방향 분율 계산.
  LVRange := FVMax - FVMin + 1;
  if (LVRange <= 0) or (FVPage <= 0) or (FVPage >= LVRange) then
  begin
    LTopFrac := 0;
    LHeightFrac := 1;
  end
  else
  begin
    LTopFrac := (FVPos - FVMin) / LVRange;
    LHeightFrac := FVPage / LVRange;
  end;

  Result.Left := ADrawRect.Left + Round(LLeftFrac * LDrawW);
  Result.Top := ADrawRect.Top + Round(LTopFrac * LDrawH);
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
      Canvas.StretchDraw(LDrawRect, FBitmap);

      // 디자인 폼 전체 외곽선.
      Canvas.Brush.Style := bsClear;
      Canvas.Pen.Color := ThemedColor(clGrayText);
      Canvas.Pen.Width := 1;
      Canvas.Rectangle(LDrawRect);

      // 현재 보이는 영역을 캡션바 있는 창 모양으로 표시한다.
      LViewRect := ViewportRect(LDrawRect);
      DrawViewportWindow(LViewRect);
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
  Canvas.Font.Style := [fsUnderline];
  Canvas.Font.Color := ThemedColor(clHotLight);
  Canvas.Brush.Style := bsClear;

  LWidth := Canvas.TextWidth(CREDIT_TEXT);
  LHeight := Canvas.TextHeight(CREDIT_TEXT);

  FLinkRect.Right := ClientWidth - MINIMAP_MARGIN - 1;
  FLinkRect.Bottom := ClientHeight - MINIMAP_MARGIN - 1;
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

procedure TIDEScrollMinimap.DrawViewportWindow(const ARect: TRect);
var
  LCaptionH: Integer;
  LCaptionRect: TRect;
  LButtonSize: Integer;
  LRight: Integer;
  LButton: TRect;
  LIndex: Integer;
begin
  // 너무 작으면 단순 강조 사각형으로 대체한다.
  if (ARect.Right - ARect.Left < 8) or (ARect.Bottom - ARect.Top < 8) then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := ThemedColor(clHighlight);
    Canvas.Pen.Width := 2;
    Canvas.Rectangle(ARect);
    Canvas.Brush.Style := bsSolid;
    Exit;
  end;

  // 창 본문 외곽선(내용이 비치도록 채우지 않음).
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := ThemedColor(clHighlight);
  Canvas.Pen.Width := 2;
  Canvas.Rectangle(ARect);

  // 캡션바 높이는 뷰포트 높이에 비례하되 적당히 제한한다.
  LCaptionH := (ARect.Bottom - ARect.Top) div 6;
  if LCaptionH < 7 then
  begin
    LCaptionH := 7;
  end;

  if LCaptionH > 16 then
  begin
    LCaptionH := 16;
  end;

  if LCaptionH > (ARect.Bottom - ARect.Top) - 3 then
  begin
    LCaptionH := (ARect.Bottom - ARect.Top) - 3;
  end;

  LCaptionRect := Rect(ARect.Left + 1, ARect.Top + 1, ARect.Right - 1, ARect.Top + 1 + LCaptionH);

  // 캡션바 채우기.
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ThemedColor(clHighlight);
  Canvas.FillRect(LCaptionRect);

  // 캡션 우측에 작은 창 버튼 3개를 흉내 낸다.
  LButtonSize := LCaptionH - 4;
  if LButtonSize >= 3 then
  begin
    LRight := LCaptionRect.Right - 3;
    Canvas.Brush.Color := ThemedColor(clBtnFace);
    Canvas.Pen.Color := ThemedColor(clBtnShadow);
    Canvas.Pen.Width := 1;
    for LIndex := 0 to 2 do
    begin
      LButton := Rect(LRight - LButtonSize, LCaptionRect.Top + 2, LRight, LCaptionRect.Top + 2 + LButtonSize);
      if LButton.Left <= LCaptionRect.Left + 2 then
      begin
        Break;
      end;

      Canvas.Rectangle(LButton);
      LRight := LButton.Left - 2;
    end;
  end;

  // 캡션과 본문 경계선.
  Canvas.Pen.Color := ThemedColor(clHighlight);
  Canvas.Pen.Width := 1;
  Canvas.MoveTo(ARect.Left + 1, LCaptionRect.Bottom);
  Canvas.LineTo(ARect.Right - 1, LCaptionRect.Bottom);

  Canvas.Brush.Style := bsSolid;
end;

procedure TIDEScrollMinimap.UpdateCapture;
var
  LForm: TWinControl;
begin
  if not TryGetDesignedForm(LForm) then
  begin
    FHasDesigner := False;
    FContainer := 0;
    Invalidate;
    Exit;
  end;

  FContainer := FindScrollContainer(LForm.Handle);

  if not CaptureWindowImage(LForm.Handle, FBitmap) then
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
    ReadScroll(FContainer, SB_HORZ, FHPos, FHPage, FHMin, FHMax);
    ReadScroll(FContainer, SB_VERT, FVPos, FVPage, FVMin, FVMax);
  end;

  Invalidate;
end;

procedure TIDEScrollMinimap.RefreshViewport;
var
  LHPos: Integer;
  LHPage: Integer;
  LHMin: Integer;
  LHMax: Integer;
  LVPos: Integer;
  LVPage: Integer;
  LVMin: Integer;
  LVMax: Integer;
begin
  if (not FHasDesigner) or (FContainer = 0) then
  begin
    Exit;
  end;

  ReadScroll(FContainer, SB_HORZ, LHPos, LHPage, LHMin, LHMax);
  ReadScroll(FContainer, SB_VERT, LVPos, LVPage, LVMin, LVMax);

  if (LHPos = FHPos) and (LHPage = FHPage) and (LHMin = FHMin) and (LHMax = FHMax) and
     (LVPos = FVPos) and (LVPage = FVPage) and (LVMin = FVMin) and (LVMax = FVMax) then
  begin
    Exit;
  end;

  FHPos := LHPos;
  FHPage := LHPage;
  FHMin := LHMin;
  FHMax := LHMax;
  FVPos := LVPos;
  FVPage := LVPage;
  FVMin := LVMin;
  FVMax := LVMax;

  Invalidate;
end;

procedure TIDEScrollMinimap.SyncScrollFromContainer;
begin
  // 실제 컨테이너 스크롤 위치를 다시 읽어 뷰포트 표시를 동기화한다.
  if FContainer = 0 then
  begin
    Exit;
  end;

  ReadScroll(FContainer, SB_HORZ, FHPos, FHPage, FHMin, FHMax);
  ReadScroll(FContainer, SB_VERT, FVPos, FVPage, FVMin, FVMax);
end;

procedure TIDEScrollMinimap.ScrollToPoint(const AX: Integer; const AY: Integer; const AFinal: Boolean);
var
  LDrawW: Integer;
  LDrawH: Integer;
  LCenterFracX: Double;
  LCenterFracY: Double;
  LHRange: Integer;
  LVRange: Integer;
  LWidthFrac: Double;
  LHeightFrac: Double;
  LLeftFrac: Double;
  LTopFrac: Double;
  LNewHPos: Integer;
  LNewVPos: Integer;
begin
  if (FContainer = 0) or FDrawRect.IsEmpty then
  begin
    Exit;
  end;

  LDrawW := FDrawRect.Right - FDrawRect.Left;
  LDrawH := FDrawRect.Bottom - FDrawRect.Top;
  if (LDrawW <= 0) or (LDrawH <= 0) then
  begin
    Exit;
  end;

  // 커서가 가리키는 지점을 뷰포트 중심으로 삼는다.
  LCenterFracX := (AX - FDrawRect.Left) / LDrawW;
  LCenterFracY := (AY - FDrawRect.Top) / LDrawH;

  LHRange := FHMax - FHMin + 1;
  if (LHRange > 0) and (FHPage > 0) and (FHPage < LHRange) then
  begin
    LWidthFrac := FHPage / LHRange;
    LLeftFrac := LCenterFracX - LWidthFrac / 2;
    if LLeftFrac < 0 then
    begin
      LLeftFrac := 0;
    end;

    if LLeftFrac > 1 - LWidthFrac then
    begin
      LLeftFrac := 1 - LWidthFrac;
    end;

    LNewHPos := FHMin + Round(LLeftFrac * LHRange);
    ScrollWindowTo(FContainer, SB_HORZ, LNewHPos, AFinal);
  end;

  LVRange := FVMax - FVMin + 1;
  if (LVRange > 0) and (FVPage > 0) and (FVPage < LVRange) then
  begin
    LHeightFrac := FVPage / LVRange;
    LTopFrac := LCenterFracY - LHeightFrac / 2;
    if LTopFrac < 0 then
    begin
      LTopFrac := 0;
    end;

    if LTopFrac > 1 - LHeightFrac then
    begin
      LTopFrac := 1 - LHeightFrac;
    end;

    LNewVPos := FVMin + Round(LTopFrac * LVRange);
    ScrollWindowTo(FContainer, SB_VERT, LNewVPos, AFinal);
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
    ScrollToPoint(AX, AY, False);
  end;
end;

procedure TIDEScrollMinimap.MouseMove(AShift: TShiftState; AX: Integer; AY: Integer);
begin
  inherited MouseMove(AShift, AX, AY);

  if FDragging then
  begin
    ScrollToPoint(AX, AY, False);
    Exit;
  end;

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
      // 드래그 종료를 컨테이너에 확정 통지한다.
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
