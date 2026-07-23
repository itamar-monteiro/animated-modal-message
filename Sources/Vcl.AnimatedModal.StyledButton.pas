unit Vcl.AnimatedModal.StyledButton;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.NetEncoding,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.StdCtrls,
  Winapi.ActiveX,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ;

type
  TStyledButton = class(TCustomControl)
  private
    FButtonCaption: string;
    FButtonColor: TColor;
    FHover: Boolean;
    procedure SetButtonCaption(const Value: string);
    function LightenColor(C: TColor; Percent: Integer): TColor;
    function CreateRoundRectPath(X, Y, W, H, Radius: Single): TGPGraphicsPath;
    function ARGBColor(A, R, G, B: Byte): ARGB;
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure CMMouseEnter(var Msg: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Msg: TMessage); message CM_MOUSELEAVE;
  public
    constructor Create(AOwner: TComponent); override;
    property ButtonCaption: string read FButtonCaption write SetButtonCaption;
    property ButtonColor: TColor read FButtonColor write FButtonColor;
    property OnClick;
  end;

implementation

constructor TStyledButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width       := 140;
  Height      := 40;
  Cursor      := crHandPoint;
  FButtonColor:= clBtnFace;
  TabStop     := True;
end;

function TStyledButton.CreateRoundRectPath(X, Y, W, H, Radius: Single): TGPGraphicsPath;
var
  d: Single;
begin
  d:= Radius * 2;

  Result:= TGPGraphicsPath.Create;
  Result.AddArc(X, Y, d, d, 180, 90);
  Result.AddArc(X + W - d, Y, d, d, 270, 90);
  Result.AddArc(X + W - d, Y + H - d, d, d, 0, 90);
  Result.AddArc(X, Y + H - d, d, d, 90, 90);
  Result.CloseFigure;
end;

procedure TStyledButton.SetButtonCaption(const Value: string);
begin
  FButtonCaption:= Value;
  Invalidate;
end;

function TStyledButton.ARGBColor(A, R, G, B: Byte): ARGB;
begin
  Result:= (ARGB(A) shl 24) or (ARGB(R) shl 16) or (ARGB(G) shl 8) or ARGB(B);
end;

procedure TStyledButton.CMMouseEnter(var Msg: TMessage);
begin
  FHover:= True;
  Invalidate;
end;

procedure TStyledButton.CMMouseLeave(var Msg: TMessage);
begin
  FHover:= False;
  Invalidate;
end;

procedure TStyledButton.DoEnter;
begin
  inherited;
  Invalidate; // redesenha para mostrar o anel de foco
end;

procedure TStyledButton.DoExit;
begin
  inherited;
  Invalidate;
end;

procedure TStyledButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if CanFocus then
     SetFocus;
end;

procedure TStyledButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if (Key = VK_RETURN) or (Key = VK_SPACE) then
  begin
    Key:= 0;
    Click;
  end;
end;

function TStyledButton.LightenColor(C: TColor; Percent: Integer): TColor;
var
  rgbColor: TColor;
  R, G, B : Integer;
begin
  rgbColor:= ColorToRGB(C);

  R:= GetRValue(rgbColor);
  G:= GetGValue(rgbColor);
  B:= GetBValue(rgbColor);

  if Percent >= 0 then
    begin
      R:= R + Round((255 - R) * Percent / 100);
      G:= G + Round((255 - G) * Percent / 100);
      B:= B + Round((255 - B) * Percent / 100);
    end
  else
    begin
      R:= R + Round(R * Percent / 100);
      G:= G + Round(G * Percent / 100);
      B:= B + Round(B * Percent / 100);
    end;

  Result:= RGB(EnsureRange(R, 0, 255), EnsureRange(G, 0, 255), EnsureRange(B, 0, 255));
end;

procedure TStyledButton.Paint;
var
  G: TGPGraphics;
  LPath: TGPGraphicsPath;
  LBrush: TGPSolidBrush;
  LColor: TColor;
  LRect: TRect;
  LFocusPath: TGPGraphicsPath;
  LFocusPen: TGPPen;
begin
  if FHover then
    LColor:= LightenColor(FButtonColor, -12)
  else
    LColor:= FButtonColor;

  G:= TGPGraphics.Create(Canvas.Handle);
  try
    G.SetSmoothingMode(SmoothingModeAntiAlias);
    LPath:= CreateRoundRectPath(0, 0, Width, Height, 8);

    try
      LBrush:= TGPSolidBrush.Create(ARGBColor(255, GetRValue(ColorToRGB(LColor)), GetGValue(ColorToRGB(LColor)), GetBValue(ColorToRGB(LColor))));
      try
        G.FillPath(LBrush, LPath);
      finally
        LBrush.Free;
      end;
    finally
      LPath.Free;
    end;

    // Anel de foco - só aparece quando o botão está com o foco do teclado
    if Focused then
    begin
      LFocusPath:= CreateRoundRectPath(2, 2, Width - 4, Height - 4, 7);
      try
        LFocusPen:= TGPPen.Create(ARGBColor(230, 255, 255, 255), 2);
        try
          G.DrawPath(LFocusPen, LFocusPath);
        finally
          LFocusPen.Free;
        end;
      finally
        LFocusPath.Free;
      end;
    end;
  finally
    G.Free;
  end;

  Canvas.Brush.Style:= bsClear;
  Canvas.Font.Color := clWhite;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Size  := 10;
  LRect             := ClientRect;

  Winapi.Windows.DrawText(Canvas.Handle, PChar(FButtonCaption), Length(FButtonCaption), LRect, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
end;
end.
