unit IDEScroll.DockFrame;

// 도킹 폼에 호스팅되는 프레임. 미니맵 컨트롤 하나를 전체 영역에 배치하고,
//   - 디바운스 타이머: 디자인 변경 통지가 오면 잠시 후 한 번만 재캡처(폭주 방지)
//   - 뷰포트 타이머:   주기적으로 스크롤 위치만 가볍게 갱신
// 두 타이머와 디자인 통지자의 수명을 관리한다.
// 인라인 변수는 구형 Delphi 호환을 위해 사용하지 않는다.

interface

{$REGION 'uses'}
uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  DesignIntf,
  IDEScroll.MinimapControl,
  IDEScroll.DesignNotifier;
{$ENDREGION}

type
  // 미니맵을 담는 도킹 프레임.
  TIDEScrollFrame = class(TFrame)
  private
    FCaptureTimer: TTimer;
    FMinimap: TIDEScrollMinimap;
    FNotifier: IDesignNotification;
    FViewTimer: TTimer;
    procedure CaptureTimerTick(ASender: TObject);
    procedure HandleDesignChange;
    procedure ScheduleCapture;
    procedure ViewTimerTick(ASender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$REGION 'uses'}
uses
  Winapi.Windows;
{$ENDREGION}

{$R *.dfm}

const
  CAPTURE_DEBOUNCE_MS = 150;
  VIEWPORT_POLL_MS = 200;

constructor TIDEScrollFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FMinimap := TIDEScrollMinimap.Create(Self);
  FMinimap.Parent := Self;
  FMinimap.Align := alClient;

  // 디자인 변경 통지를 모아 디바운스로 재캡처를 예약한다.
  FCaptureTimer := TTimer.Create(Self);
  FCaptureTimer.Enabled := False;
  FCaptureTimer.Interval := CAPTURE_DEBOUNCE_MS;
  FCaptureTimer.OnTimer := CaptureTimerTick;

  // 스크롤 위치 변화를 주기적으로 가볍게 반영한다.
  FViewTimer := TTimer.Create(Self);
  FViewTimer.Enabled := True;
  FViewTimer.Interval := VIEWPORT_POLL_MS;
  FViewTimer.OnTimer := ViewTimerTick;

  FNotifier := TIDEScrollDesignNotifier.Create(HandleDesignChange);
  RegisterDesignNotification(FNotifier);

  // 폼이 열린 시점에 이미 디자이너가 떠 있을 수 있으니 초기 캡처를 예약한다.
  ScheduleCapture;
end;

destructor TIDEScrollFrame.Destroy;
begin
  if FNotifier <> nil then
  begin
    UnregisterDesignNotification(FNotifier);
    FNotifier := nil;
  end;

  inherited Destroy;
end;

procedure TIDEScrollFrame.ScheduleCapture;
begin
  // 타이머를 재시작해 마지막 변경 이후 일정 시간 뒤 한 번만 캡처한다.
  FCaptureTimer.Enabled := False;
  FCaptureTimer.Enabled := True;
end;

procedure TIDEScrollFrame.HandleDesignChange;
begin
  ScheduleCapture;
end;

procedure TIDEScrollFrame.CaptureTimerTick(ASender: TObject);
begin
  FCaptureTimer.Enabled := False;
  FMinimap.UpdateCapture;
end;

procedure TIDEScrollFrame.ViewTimerTick(ASender: TObject);
begin
  FMinimap.RefreshViewport;
end;

end.
