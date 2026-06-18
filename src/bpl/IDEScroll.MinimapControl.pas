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
    FVMax: Integer;
    FVMin: Integer;
    FVPage: Integer;
    FVPos: Integer;
    function  ComputeDrawRect: TRect;
    function  ViewportRect(const ADrawRect: TRect): TRect;
    procedure ScrollToPoint(const AX: Integer; const AY: Integer);
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
  IDEScroll.DesignerIntrospect;
{$ENDREGION}

const
  MINIMAP_MARGIN = 6;

constructor TIDEScrollMinimap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBitmap := TBitmap.Create;
  FBitmap.PixelFormat := pf24bit;
  FContainer := 0;
  FDragging := False;
  FHasDesigner := False;
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
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(ClientRect);

  if (not FHasDesigner) or (FBitmap.Width <= 0) or (FBitmap.Height <= 0) then
  begin
    LText := '디자이너 없음';
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := clGrayText;
    Canvas.TextOut(
      (ClientWidth - Canvas.TextWidth(LText)) div 2,
      (ClientHeight - Canvas.TextHeight(LText)) div 2,
      LText);
    Canvas.Brush.Style := bsSolid;
    Exit;
  end;

  LDrawRect := ComputeDrawRect;
  if LDrawRect.IsEmpty then
  begin
    Exit;
  end;

  FDrawRect := LDrawRect;
  Canvas.StretchDraw(LDrawRect, FBitmap);

  // 디자인 폼 전체 외곽선.
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := clGray;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(LDrawRect);

  // 현재 보이는 영역 뷰포트.
  LViewRect := ViewportRect(LDrawRect);
  Canvas.Pen.Color := clHighlight;
  Canvas.Pen.Width := 2;
  Canvas.Rectangle(LViewRect);
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

procedure TIDEScrollMinimap.ScrollToPoint(const AX: Integer; const AY: Integer);
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
    ScrollWindowTo(FContainer, SB_HORZ, LNewHPos);
    FHPos := LNewHPos;
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
    ScrollWindowTo(FContainer, SB_VERT, LNewVPos);
    FVPos := LNewVPos;
  end;

  Invalidate;
end;

procedure TIDEScrollMinimap.MouseDown(AButton: TMouseButton; AShift: TShiftState; AX: Integer; AY: Integer);
begin
  inherited MouseDown(AButton, AShift, AX, AY);

  if (AButton = mbLeft) and FHasDesigner and (not FDrawRect.IsEmpty) then
  begin
    FDragging := True;
    ScrollToPoint(AX, AY);
  end;
end;

procedure TIDEScrollMinimap.MouseMove(AShift: TShiftState; AX: Integer; AY: Integer);
begin
  inherited MouseMove(AShift, AX, AY);

  if FDragging then
  begin
    ScrollToPoint(AX, AY);
  end;
end;

procedure TIDEScrollMinimap.MouseUp(AButton: TMouseButton; AShift: TShiftState; AX: Integer; AY: Integer);
begin
  inherited MouseUp(AButton, AShift, AX, AY);

  if AButton = mbLeft then
  begin
    FDragging := False;
  end;
end;

end.
