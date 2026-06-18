unit IDEScroll.MinimapControl;

// 폼 디자이너 미니맵 컨트롤.
//   - 미니맵 배경 = 디자이너에 현재 보이는 영역(뷰포트)을 나타내는 캔버스.
//   - 그 위에 실제 폼을 실제 크기/위치의 창(타이틀바 포함)으로 그린다.
//     폼이 뷰포트보다 크면 캔버스 밖으로 넘쳐 보이고, 작으면 안쪽 박스로 보인다.
//   - 폼 창(박스)을 마우스로 드래그하면 그 위치로 디자이너를 스크롤한다.
//     드래그 중에는 점선 윤곽만 보여주고, 드롭 시 실제로 이동한다.
//   - 우하단에 "by DelMadang" 크레딧 링크(호버 효과 + 클릭 시 브라우저).
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
    FLinkHover: Boolean;
    FLinkRect: TRect;
    FScale: Double;
    FView: TRect;
    function  FormWindowRect(const AClientBox: TRect): TRect;
    procedure ApplyDragScroll(const ABox: TRect; const AFinal: Boolean);
    procedure ClampFormBox(var ABox: TRect);
    procedure DrawCreditLink;
    procedure DrawFormWindow(const AClientBox: TRect);
    procedure OpenCreditLink;
    procedure RecomputeLayout;
    procedure SyncScrollFromContainer;
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

    // 디자인 폼을 다시 캡처하고 가시영역을 갱신한다(무거운 작업).
    procedure UpdateCapture;

    // 가시영역(스크롤 위치)만 다시 읽어 바뀌었으면 다시 그린다(가벼운 작업).
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
  LViewW: Integer;
  LViewH: Integer;
  LScrollX: Integer;
  LScrollY: Integer;
  LCanvasW: Integer;
  LCanvasH: Integer;
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

  // 뷰포트(현재 보이는 영역) 크기/스크롤. 컨테이너 정보가 없으면 폼 전체로 간주.
  LViewW := FView.Right - FView.Left;
  LViewH := FView.Bottom - FView.Top;
  if (LViewW <= 0) or (LViewH <= 0) then
  begin
    LViewW := LFormW;
    LViewH := LFormH;
    LScrollX := 0;
    LScrollY := 0;
  end
  else
  begin
    LScrollX := FView.Left;
    LScrollY := FView.Top;
  end;

  // 캔버스(=뷰포트)를 미니맵 안에 비율 유지로 맞춘다. 타이틀바 공간을 위에 확보.
  LInner := ClientRect;
  LInner.Inflate(-MINIMAP_MARGIN, -MINIMAP_MARGIN);
  LInnerW := LInner.Right - LInner.Left;
  LInnerH := (LInner.Bottom - LInner.Top) - TITLEBAR_H;
  if (LInnerW <= 0) or (LInnerH <= 0) then
  begin
    Exit;
  end;

  FScale := Min(LInnerW / LViewW, LInnerH / LViewH);
  LCanvasW := Round(LViewW * FScale);
  LCanvasH := Round(LViewH * FScale);

  // 캔버스를 (타이틀바 공간 아래) 가운데 정렬.
  FCanvasRect.Left := LInner.Left + (LInnerW - LCanvasW) div 2;
  FCanvasRect.Top := LInner.Top + TITLEBAR_H + (LInnerH - LCanvasH) div 2;
  FCanvasRect.Right := FCanvasRect.Left + LCanvasW;
  FCanvasRect.Bottom := FCanvasRect.Top + LCanvasH;

  // 폼 클라이언트 박스 = 캔버스 기준으로 스크롤만큼 밀린 위치 + 실제 폼 크기.
  FFormBox.Left := FCanvasRect.Left - Round(LScrollX * FScale);
  FFormBox.Top := FCanvasRect.Top - Round(LScrollY * FScale);
  FFormBox.Right := FFormBox.Left + Round(LFormW * FScale);
  FFormBox.Bottom := FFormBox.Top + Round(LFormH * FScale);
end;

procedure TIDEScrollMinimap.ClampFormBox(var ABox: TRect);
var
  LFormW: Integer;
  LFormH: Integer;
  LViewW: Integer;
  LViewH: Integer;
  LMaxScrollX: Integer;
  LMaxScrollY: Integer;
  LMinLeft: Integer;
  LMinTop: Integer;
  LBoxW: Integer;
  LBoxH: Integer;
begin
  if FScale <= 0 then
  begin
    Exit;
  end;

  LFormW := FBitmap.Width;
  LFormH := FBitmap.Height;
  LViewW := FView.Right - FView.Left;
  LViewH := FView.Bottom - FView.Top;
  if (LViewW <= 0) or (LViewH <= 0) then
  begin
    LViewW := LFormW;
    LViewH := LFormH;
  end;

  LBoxW := Round(LFormW * FScale);
  LBoxH := Round(LFormH * FScale);

  // 스크롤 범위 [0, Form-View] 에 대응하는 박스 위치 한계.
  LMaxScrollX := Max(0, LFormW - LViewW);
  LMaxScrollY := Max(0, LFormH - LViewH);
  LMinLeft := FCanvasRect.Left - Round(LMaxScrollX * FScale);
  LMinTop := FCanvasRect.Top - Round(LMaxScrollY * FScale);

  ABox.Left := EnsureRange(ABox.Left, LMinLeft, FCanvasRect.Left);
  ABox.Top := EnsureRange(ABox.Top, LMinTop, FCanvasRect.Top);
  ABox.Right := ABox.Left + LBoxW;
  ABox.Bottom := ABox.Top + LBoxH;
end;

procedure TIDEScrollMinimap.ApplyDragScroll(const ABox: TRect; const AFinal: Boolean);
var
  LFormW: Integer;
  LFormH: Integer;
  LViewW: Integer;
  LViewH: Integer;
  LScrollX: Integer;
  LScrollY: Integer;
begin
  if (FContainer = 0) or (FScale <= 0) then
  begin
    Exit;
  end;

  LFormW := FBitmap.Width;
  LFormH := FBitmap.Height;
  LViewW := FView.Right - FView.Left;
  LViewH := FView.Bottom - FView.Top;
  if (LViewW <= 0) or (LViewH <= 0) then
  begin
    Exit;
  end;

  // 박스 위치 → 스크롤 오프셋(픽셀).
  LScrollX := EnsureRange(Round((FCanvasRect.Left - ABox.Left) / FScale), 0, Max(0, LFormW - LViewW));
  LScrollY := EnsureRange(Round((FCanvasRect.Top - ABox.Top) / FScale), 0, Max(0, LFormH - LViewH));

  if LFormW > LViewW then
  begin
    ScrollWindowTo(FContainer, SB_HORZ, LScrollX, AFinal);
  end;

  if LFormH > LViewH then
  begin
    ScrollWindowTo(FContainer, SB_VERT, LScrollY, AFinal);
  end;

  if AFinal then
  begin
    SyncScrollFromContainer;
    Invalidate;
  end;
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
  // 배경 = 디자이너 영역.
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ThemedColor(clBtnFace);
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

  // 캔버스(보이는 영역) 참조 테두리.
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := ThemedColor(clGrayText);
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
    // 실제 폼을 실제 크기/위치의 창으로 그린다(넘치면 미니맵 경계에서 잘림).
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
  if FDragging or (not FHasDesigner) or (FContainer = 0) then
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
  // 실제 컨테이너 가시영역을 다시 읽어 표시를 동기화한다.
  if FContainer = 0 then
  begin
    Exit;
  end;

  GetVisibleRegion(FFormHandle, FContainer, FView);
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

  // 폼 창 위에서는 손 모양 커서로 드래그 가능함을 안내한다.
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
      ApplyDragScroll(FDragBox, True);
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
