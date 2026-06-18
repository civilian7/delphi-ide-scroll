unit IDEScroll.DesignNotifier;

// 폼 디자이너의 변경(컴포넌트 추가/삭제/이동/수정/선택/디자이너 전환)을
// 통지받는 IDesignNotification 구현. 통지가 오면 등록된 콜백을 호출한다.
// 통지 폭주를 다루는 디바운스는 콜백 쪽(프레임)에서 처리한다.
// 인라인 변수는 구형 Delphi 호환을 위해 사용하지 않는다.

interface

{$REGION 'uses'}
uses
  System.Classes,
  DesignIntf;
{$ENDREGION}

type
  // 디자이너 변경 시 호출되는 콜백 타입.
  TDesignChangeEvent = procedure of object;

  // 모든 디자이너 변경을 단일 콜백으로 모아 전달하는 통지자.
  TIDEScrollDesignNotifier = class(TInterfacedObject, IDesignNotification)
  private
    FOnChange: TDesignChangeEvent;
    procedure DoChange;
  public
    constructor Create(const AOnChange: TDesignChangeEvent);

    procedure ItemDeleted(const ADesigner: IDesigner; AItem: TPersistent);
    procedure ItemInserted(const ADesigner: IDesigner; AItem: TPersistent);
    procedure ItemsModified(const ADesigner: IDesigner);
    procedure SelectionChanged(const ADesigner: IDesigner; const ASelection: IDesignerSelections);
    procedure DesignerOpened(const ADesigner: IDesigner; AResurrecting: Boolean);
    procedure DesignerClosed(const ADesigner: IDesigner; AGoingDormant: Boolean);
  end;

implementation

constructor TIDEScrollDesignNotifier.Create(const AOnChange: TDesignChangeEvent);
begin
  inherited Create;
  FOnChange := AOnChange;
end;

procedure TIDEScrollDesignNotifier.DoChange;
begin
  if Assigned(FOnChange) then
  begin
    FOnChange;
  end;
end;

procedure TIDEScrollDesignNotifier.ItemDeleted(const ADesigner: IDesigner; AItem: TPersistent);
begin
  DoChange;
end;

procedure TIDEScrollDesignNotifier.ItemInserted(const ADesigner: IDesigner; AItem: TPersistent);
begin
  DoChange;
end;

procedure TIDEScrollDesignNotifier.ItemsModified(const ADesigner: IDesigner);
begin
  DoChange;
end;

procedure TIDEScrollDesignNotifier.SelectionChanged(const ADesigner: IDesigner; const ASelection: IDesignerSelections);
begin
  DoChange;
end;

procedure TIDEScrollDesignNotifier.DesignerOpened(const ADesigner: IDesigner; AResurrecting: Boolean);
begin
  DoChange;
end;

procedure TIDEScrollDesignNotifier.DesignerClosed(const ADesigner: IDesigner; AGoingDormant: Boolean);
begin
  DoChange;
end;

end.
