object FMainForm: TFMainForm
  Left = 0
  Top = 0
  Caption = 'Demo'
  ClientHeight = 148
  ClientWidth = 756
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object Button1: TButton
    Left = 42
    Top = 52
    Width = 153
    Height = 41
    Caption = 'Modal Success'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 210
    Top = 52
    Width = 153
    Height = 41
    Caption = 'Modal Error'
    TabOrder = 1
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 378
    Top = 52
    Width = 153
    Height = 41
    Caption = 'Modal Warning'
    TabOrder = 2
    OnClick = Button3Click
  end
  object Button4: TButton
    Left = 546
    Top = 52
    Width = 153
    Height = 41
    Caption = 'Modal Question'
    TabOrder = 3
    OnClick = Button4Click
  end
end
