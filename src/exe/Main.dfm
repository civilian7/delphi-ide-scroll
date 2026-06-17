object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'IDEScroll'
  ClientHeight = 360
  ClientWidth = 520
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object lblVertical: TLabel
    Left = 16
    Top = 64
    Width = 60
    Height = 15
    Caption = 'lblVertical'
  end
  object lblHorizontal: TLabel
    Left = 200
    Top = 64
    Width = 70
    Height = 15
    Caption = 'lblHorizontal'
  end
  object btnToggle: TButton
    Left = 16
    Top = 16
    Width = 488
    Height = 33
    Anchors = [akLeft, akTop, akRight]
    Default = True
    TabOrder = 0
    OnClick = btnToggleClick
  end
  object spnVertical: TSpinEdit
    Left = 96
    Top = 60
    Width = 70
    Height = 24
    MaxValue = 50
    MinValue = 1
    TabOrder = 1
    Value = 3
    OnChange = spnVerticalChange
  end
  object spnHorizontal: TSpinEdit
    Left = 288
    Top = 60
    Width = 70
    Height = 24
    MaxValue = 50
    MinValue = 1
    TabOrder = 2
    Value = 3
    OnChange = spnHorizontalChange
  end
  object memLog: TMemo
    Left = 16
    Top = 96
    Width = 488
    Height = 248
    Anchors = [akLeft, akTop, akRight, akBottom]
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 3
  end
end
