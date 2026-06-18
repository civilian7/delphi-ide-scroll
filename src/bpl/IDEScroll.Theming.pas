unit IDEScroll.Theming;

// IDE 테마 연동 헬퍼.
//   - ThemedColor: 표준 시스템 색을 현재 IDE 테마에 맞는 색으로 변환
//   - ApplyThemeTo: 컴포넌트에 현재 테마 적용
//   - TIDEScrollThemeNotifier: 테마 변경 시 콜백을 호출하는 통지자
// 테마 서비스를 쓸 수 없으면 표준 색으로 안전하게 폴백한다.
// 인라인 변수는 구형 Delphi 호환을 위해 사용하지 않는다.

interface

{$REGION 'uses'}
uses
  System.Classes,
  Vcl.Graphics,
  ToolsAPI;
{$ENDREGION}

type
  // 테마 변경 시 호출되는 콜백 타입.
  TThemeChangeEvent = procedure of object;

  // IDE 테마 변경 전/후를 통지받아 콜백을 호출한다.
  TIDEScrollThemeNotifier = class(TInterfacedObject, IOTANotifier, INTAIDEThemingServicesNotifier)
  private
    FOnChanged: TThemeChangeEvent;
  public
    constructor Create(const AOnChanged: TThemeChangeEvent);

    // IOTANotifier
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;

    // INTAIDEThemingServicesNotifier
    procedure ChangingTheme;
    procedure ChangedTheme;
  end;

// 현재 IDE 테마에서 표준 시스템 색에 대응하는 색을 돌려준다.
function ThemedColor(const ASystemColor: TColor): TColor;

// AComponent 에 현재 IDE 테마를 적용한다(가능한 경우).
procedure ApplyThemeTo(const AComponent: TComponent);

// 테마 변경 통지자를 등록한다. 실패 시 -1 을 돌려준다.
function RegisterThemeNotifier(const ANotifier: INTAIDEThemingServicesNotifier): Integer;

// RegisterThemeNotifier 로 받은 인덱스를 해제한다.
procedure UnregisterThemeNotifier(const AIndex: Integer);

implementation

{$REGION 'uses'}
uses
  System.SysUtils,
  Vcl.Themes;
{$ENDREGION}

function ThemingServices: IOTAIDEThemingServices;
begin
  if not Supports(BorlandIDEServices, IOTAIDEThemingServices, Result) then
  begin
    Result := nil;
  end;
end;

function ThemedColor(const ASystemColor: TColor): TColor;
var
  LServices: IOTAIDEThemingServices;
begin
  LServices := ThemingServices;
  if (LServices <> nil) and LServices.IDEThemingEnabled and (LServices.StyleServices <> nil) then
  begin
    Result := LServices.StyleServices.GetSystemColor(ASystemColor);
  end
  else
  begin
    Result := ColorToRGB(ASystemColor);
  end;
end;

procedure ApplyThemeTo(const AComponent: TComponent);
var
  LServices: IOTAIDEThemingServices;
begin
  LServices := ThemingServices;
  if (LServices <> nil) and LServices.IDEThemingEnabled then
  begin
    LServices.ApplyTheme(AComponent);
  end;
end;

function RegisterThemeNotifier(const ANotifier: INTAIDEThemingServicesNotifier): Integer;
var
  LServices: IOTAIDEThemingServices;
begin
  Result := -1;
  LServices := ThemingServices;
  if LServices <> nil then
  begin
    Result := LServices.AddNotifier(ANotifier);
  end;
end;

procedure UnregisterThemeNotifier(const AIndex: Integer);
var
  LServices: IOTAIDEThemingServices;
begin
  if AIndex < 0 then
  begin
    Exit;
  end;

  LServices := ThemingServices;
  if LServices <> nil then
  begin
    LServices.RemoveNotifier(AIndex);
  end;
end;

{ TIDEScrollThemeNotifier }

constructor TIDEScrollThemeNotifier.Create(const AOnChanged: TThemeChangeEvent);
begin
  inherited Create;
  FOnChanged := AOnChanged;
end;

procedure TIDEScrollThemeNotifier.AfterSave;
begin
  // 사용하지 않음.
end;

procedure TIDEScrollThemeNotifier.BeforeSave;
begin
  // 사용하지 않음.
end;

procedure TIDEScrollThemeNotifier.Destroyed;
begin
  // 사용하지 않음.
end;

procedure TIDEScrollThemeNotifier.Modified;
begin
  // 사용하지 않음.
end;

procedure TIDEScrollThemeNotifier.ChangingTheme;
begin
  // 변경 직전에는 처리하지 않는다.
end;

procedure TIDEScrollThemeNotifier.ChangedTheme;
begin
  if Assigned(FOnChanged) then
  begin
    FOnChanged;
  end;
end;

end.
