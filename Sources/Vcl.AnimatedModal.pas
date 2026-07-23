unit Vcl.AnimatedModal;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Types,
  System.NetEncoding,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Winapi.ActiveX,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  Vcl.AnimatedModal.StyledButton,
  Vcl.AnimatedModal.Types;

type
  TDarkForm = class(TForm)
  public
    destructor Destroy; override;
    procedure Setup(AOwnerForm: TWinControl);
  end;

  TAnimatedModal = class(TForm)
  private
    FKind: TModalKind;
    FTimer: TTimer;
    FStartTick: Cardinal;
    FCustomIcon: TGPBitmap;
    FIconBox: TPaintBox;
    FTitleLbl: TLabel;
    FMsgLbl: TLabel;
    FOkBtn: TStyledButton;
    FYesBtn: TStyledButton;
    FNoBtn: TStyledButton;
    FOnYes: TProc;
    FOnNo: TProc;
    FOwnerForm: TWinControl;
    FOverlay: TDarkForm;
    FFinalRect: TRect;
    FOpenAnimDone: Boolean;
    FAnimationMode: Integer; // 0 = abertura, 1 = ícone
    procedure IconBoxPaint(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    procedure OkBtnClick(Sender: TObject);
    procedure YesBtnClick(Sender: TObject);
    procedure NoBtnClick(Sender: TObject);
    procedure BuildUI(const ATitle, AMsg, ABase64Icon: string);
    procedure ShowAnimated;
    procedure StartAnimation;
    procedure DrawVectorIcon(g: TGPGraphics; CircleProgress, LineProgress: Single);
    procedure DrawCustomIcon(g: TGPGraphics);
    procedure UpdateRoundedRegion(AWidth, AHeight: Integer);
    procedure DrawPartialPolyline(g: TGPGraphics; Pen: TGPPen; const Pts: array of TGPPointF; Progress: Single);
    function KindColor: TColor;
    function ARGBColor(A, R, G, B: Byte): ARGB;
    function MakePt(X, Y: Single): TGPPointF;
    function ZoomInBounceEaseOut(T: Single): Single;
    function EaseOutCubic(T: Single): Single;
    function LoadGPBitmapFromBase64(const Base64Str: string): TGPBitmap;
  public
    destructor Destroy; override;
    class procedure Show(AOwner: TCustomForm; Kind: TModalKind; const ATitle, AMsg: string; const ABase64Icon: string = ''); overload;
    class procedure Show(AOwner: TCustomForm; const ATitle, AMsg: string; AOnYes: TProc; AOnNo: TProc = nil; const ABase64Icon: string = ''); overload;
  end;

implementation

const
  CCircleDurationMs = 550;
  CLineDelayMs      = 150;
  CLineDurationMs   = 500;

  // Animação de abertura com zoom-in e bounce suave
  COpenDurationMs   = 800;  // Duração total do zoom-in + bounce
  COpenBounceStages = 3;
  CIconTotalMs      = CLineDelayMs + CLineDurationMs; // ~650ms no total

var
  GDIPToken: ULONG_PTR;
  GDIPStartupInput: TGDIPlusStartupInput;

function TAnimatedModal.MakePt(X, Y: Single): TGPPointF;
begin
  Result.X:= X;
  Result.Y:= Y;
end;

// Função de zoom-in com bounce no final - estilo câmera aproximando
function TAnimatedModal.ZoomInBounceEaseOut(T: Single): Single;
var
  Progress: Single;
  BounceAmount: Single;
begin
  Progress:= EnsureRange(T, 0, 1);

  // Fase 1: Zoom-in rápido (0% a 30% do progresso)
  if Progress < 0.30 then
    begin
      // Aceleração muito rápida no início
      Result:= Power(Progress / 0.30, 0.3) * 0.65;
    end
  else
    begin
      // Fase 2: Bounce pronunciado (30% a 100%)
      BounceAmount:= (Progress - 0.30) / 0.65; // 0 a 1

      // Bounce com oscilações para efeito elástico
      if BounceAmount < 0.20 then
        begin
          // Primeiro bounce: vai até 1.12 (12% de overshoot)
          Result:= 0.65 + (0.47 * BounceAmount / 0.20);
        end
      else if BounceAmount < 0.42 then
        begin
          // Segundo bounce: recua para 0.85
          Result:= 1.12 - (0.27 * (BounceAmount - 0.20) / 0.22);
        end
      else if BounceAmount < 0.63 then
        begin
          // Terceiro bounce: avança para 1.06
          Result:= 0.85 + (0.21 * (BounceAmount - 0.42) / 0.21);
        end
      else if BounceAmount < 0.82 then
        begin
          // Quarto bounce: recua para 0.95
          Result:= 1.06 - (0.11 * (BounceAmount - 0.63) / 0.19);
        end
      else
        begin
          // Estabilização final: chega suavemente em 1.0
          Result:= 0.95 + (0.05 * (BounceAmount - 0.82) / 0.18);
        end;
    end;

  // Garante que nunca ultrapasse valores absurdos
  Result:= EnsureRange(Result, 0.01, 1.20);
end;

function TAnimatedModal.EaseOutCubic(T: Single): Single;
begin
  Result:= 1 - Power(1 - T, 4);
end;

procedure TAnimatedModal.DrawPartialPolyline(g: TGPGraphics; Pen: TGPPen; const Pts: array of TGPPointF; Progress: Single);
var
  i: Integer;
  totalLen, accLen, segLen, segT: Single;
  p2: TGPPointF;
begin
  if Length(Pts) < 2 then Exit;

  totalLen:= 0;
  for i:= 0 to High(Pts) - 1 do
    totalLen:= totalLen + Sqrt(Sqr(Pts[i + 1].X - Pts[i].X) + Sqr(Pts[i + 1].Y - Pts[i].Y));

  accLen:= totalLen * EnsureRange(Progress, 0, 1);

  for i:= 0 to High(Pts) - 1 do
  begin
    if accLen <= 0 then
      Break;

    segLen:= Sqrt(Sqr(Pts[i + 1].X - Pts[i].X) + Sqr(Pts[i + 1].Y - Pts[i].Y));

    if accLen >= segLen then
      begin
        g.DrawLine(Pen, Pts[i].X, Pts[i].Y, Pts[i + 1].X, Pts[i + 1].Y);
        accLen:= accLen - segLen;
      end
    else
      begin
        segT:= accLen / segLen;
        p2  := MakePt(Pts[i].X + (Pts[i + 1].X - Pts[i].X) * segT, Pts[i].Y + (Pts[i + 1].Y - Pts[i].Y) * segT);
        g.DrawLine(Pen, Pts[i].X, Pts[i].Y, p2.X, p2.Y);
        accLen:= 0;
      end;
  end;
end;

function TAnimatedModal.LoadGPBitmapFromBase64(const Base64Str: string): TGPBitmap;
var
  Bytes : TBytes;
  ms    : TMemoryStream;
  stream: IStream;
begin
  Bytes:= TNetEncoding.Base64.DecodeStringToBytes(Base64Str);
  ms   := TMemoryStream.Create;

  ms.WriteBuffer(Bytes[0], Length(Bytes));
  ms.Position:= 0;

  stream:= TStreamAdapter.Create(ms, soOwned);
  Result:= TGPBitmap.Create(stream);
end;

{ TDarkForm }
destructor TDarkForm.Destroy;
begin
  inherited;
end;

procedure TDarkForm.Setup(AOwnerForm: TWinControl);
var
  LOwnerRect: TRect;
  LPoint    : TPoint;
begin
  if Assigned(AOwnerForm.Parent) then
    begin
      // não é um form top-level: converte para coordenadas de tela
      LPoint    := AOwnerForm.ClientToScreen(Point(0, 0));
      LOwnerRect:= Rect(LPoint.X, LPoint.Y, LPoint.X + AOwnerForm.Width, LPoint.Y + AOwnerForm.Height);
    end
  else
    LOwnerRect:= AOwnerForm.BoundsRect;

  BorderStyle:= bsNone;
  Color      := clBlack;
  SetBounds(LOwnerRect.Left, LOwnerRect.Top, LOwnerRect.Width - 15, LOwnerRect.Height - 8);

  Top            := LOwnerRect.Top;
  Left           := LOwnerRect.Left + 7;
  Position       := poDesigned;
  AlphaBlend     := True;
  AlphaBlendValue:= 125;
end;

destructor TAnimatedModal.Destroy;
begin
  FCustomIcon.Free;
  inherited;
end;

procedure TAnimatedModal.ShowAnimated;
var
  ScreenCenter: TPoint;
begin
  // Calcula a posição centralizada MANUALMENTE (Width/Height já foram
  // definidos em BuildUI antes desta chamada)
  ScreenCenter.X := (Screen.Width - Width) div 2;
  ScreenCenter.Y := (Screen.WorkAreaHeight - Height - 20) div 2;
  FFinalRect     := Rect(ScreenCenter.X, ScreenCenter.Y, ScreenCenter.X + Width, ScreenCenter.Y + Height);
  AlphaBlend     := True;
  AlphaBlendValue:= 0;

  // Posiciona no centro com tamanho mínimo (o timer vai crescer com zoom-in)
  SetBounds(ScreenCenter.X + Width div 2, ScreenCenter.Y + Height div 2, 1, 1);
  UpdateRoundedRegion(1, 1);

  // Overlay esmaecido/borrado sobre o form chamador (se houver um)
  if Assigned(FOwnerForm) and FOwnerForm.HandleAllocated then
  begin
    FOverlay:= TDarkForm.CreateNew(nil);
    FOverlay.Setup(FOwnerForm);
    FOverlay.Show;
  end;

  FOpenAnimDone := False;
  FAnimationMode:= 0;
  StartAnimation;
  try
    ShowModal;
  finally
    FreeAndNil(FOverlay);
  end;
end;

class procedure TAnimatedModal.Show(AOwner: TCustomForm; Kind: TModalKind; const ATitle, AMsg: string; const ABase64Icon: string);
var
  LForm: TAnimatedModal;
begin
  LForm:= TAnimatedModal.CreateNew(AOwner);
  try
    LForm.FKind:= Kind;

    if AOwner is TWinControl then
       LForm.FOwnerForm:= TWinControl(AOwner);

    LForm.BuildUI(ATitle, AMsg, ABase64Icon);
    LForm.ShowAnimated;
  finally
    LForm.Free;
  end;
end;

class procedure TAnimatedModal.Show(AOwner: TCustomForm; const ATitle, AMsg: string; AOnYes: TProc; AOnNo: TProc; const ABase64Icon: string);
var
  LForm: TAnimatedModal;
begin
  LForm:= TAnimatedModal.CreateNew(AOwner);
  try
    LForm.FKind := mkQuestion;
    LForm.FOnYes:= AOnYes;
    LForm.FOnNo := AOnNo;

    if AOwner is TWinControl then
      LForm.FOwnerForm:= TWinControl(AOwner);

    LForm.BuildUI(ATitle, AMsg, ABase64Icon);
    LForm.ShowAnimated;
  finally
    LForm.Free;
  end;
end;

function TAnimatedModal.KindColor: TColor;
begin
  case FKind of
    mkSuccess : Result:= RGB($19, $87, $54); // verde    #198754
    mkError   : Result:= RGB($DB, $36, $46); // vermelho #db3646
    mkWarning : Result:= RGB($FD, $7E, $14); // laranja  #FD7E14
    mkQuestion: Result:= RGB($0D, $6E, $FD); // azul     #0D6EFD
  else
    Result:= clGray;
  end;
end;

function TAnimatedModal.ARGBColor(A, R, G, B: Byte): ARGB;
begin
  Result:= (ARGB(A) shl 24) or (ARGB(R) shl 16) or (ARGB(G) shl 8) or ARGB(B);
end;

procedure TAnimatedModal.BuildUI(const ATitle, AMsg, ABase64Icon: string);
const
  FormW = 500;
  FormH = 275;
begin
  BorderStyle   := bsNone;
  Width         := FormW;
  Height        := FormH;
  Color         := RGB($F7, $FA, $FC); //RGB($F8, $FA, $FC);
  DoubleBuffered:= True;
  KeyPreview    := True;

  if ABase64Icon <> '' then
    FCustomIcon:= LoadGPBitmapFromBase64(ABase64Icon);

  FIconBox       := TPaintBox.Create(Self);
  FIconBox.Parent:= Self;
  FIconBox.SetBounds((FormW - 130) div 2, 15, 130, 130);
  FIconBox.OnPaint:= IconBoxPaint;

  // TITLE LABEL
  FTitleLbl           := TLabel.Create(Self);
  FTitleLbl.Parent    := Self;
  FTitleLbl.Alignment := taCenter;
  FTitleLbl.AutoSize  := False;
  FTitleLbl.SetBounds(10, 130, FormW - 10, 32);
  FTitleLbl.Font.Size := 16;
  FTitleLbl.Font.Style:= [fsBold];
  FTitleLbl.Font.Color:= KindColor;
  FTitleLbl.Caption   := ATitle;

  // MESSAGE LABEL
  FMsgLbl           := TLabel.Create(Self);
  FMsgLbl.Parent    := Self;
  FMsgLbl.Alignment := taCenter;
  FMsgLbl.AutoSize  := False;
  FMsgLbl.WordWrap  := True;
  FMsgLbl.Font.Size := 13;
  FMsgLbl.font.Name := 'Segoe UI';
  FMsgLbl.SetBounds(20, 160, FormW - 30, 50);
  FMsgLbl.Font.Color:= RGB($6C, $75, $7D);
  FMsgLbl.Caption   := AMsg;

  if FKind = mkQuestion then
    begin
      // Dois botões: SIM (cor do kind) e NÃO (cinza neutro)
      FYesBtn              := TStyledButton.Create(Self);
      FYesBtn.Parent       := Self;
      FYesBtn.ButtonCaption:= 'SIM';
      FYesBtn.ButtonColor  := KindColor;
      FYesBtn.SetBounds((FormW div 2) - 130, 215, 140, 40);
      FYesBtn.TabOrder:= 0;
      FYesBtn.OnClick := YesBtnClick;

      FNoBtn              := TStyledButton.Create(Self);
      FNoBtn.Parent       := Self;
      FNoBtn.ButtonCaption:= 'NÃO';
      FNoBtn.ButtonColor  := RGB($6C, $75, $7D); // cinza neutro
      FNoBtn.SetBounds((FormW div 2) + 30, 215, 140, 40);
      FNoBtn.TabOrder:= 1;
      FNoBtn.OnClick := NoBtnClick;

      ActiveControl:= FNoBtn;
    end
  else
    begin
      FOkBtn              := TStyledButton.Create(Self);
      FOkBtn.Parent       := Self;
      FOkBtn.ButtonCaption:= 'OK';
      FOkBtn.ButtonColor  := KindColor;
      FOkBtn.SetBounds((FormW - 110) div 2, 215, 140, 40);
      FOkBtn.TabOrder:= 0;
      FOkBtn.OnClick := OkBtnClick;

      ActiveControl:= FOkBtn;
    end;

  FTimer         := TTimer.Create(Self);
  FTimer.Interval:= 10;
  FTimer.Enabled := False;
  FTimer.OnTimer := TimerTick;
end;

procedure TAnimatedModal.OkBtnClick(Sender: TObject);
begin
  ModalResult:= mrOk;
end;

procedure TAnimatedModal.YesBtnClick(Sender: TObject);
begin
  if Assigned(FOnYes) then
    FOnYes();
  ModalResult:= mrYes;
end;

procedure TAnimatedModal.NoBtnClick(Sender: TObject);
begin
  if Assigned(FOnNo) then
    FOnNo();
  ModalResult:= mrNo;
end;

procedure TAnimatedModal.UpdateRoundedRegion(AWidth, AHeight: Integer);
var
  LRgn: HRGN;
begin
  LRgn:= CreateRoundRectRgn(0, 0, AWidth + 1, AHeight + 1, 20, 20);
  SetWindowRgn(Handle, LRgn, True);
end;

procedure TAnimatedModal.StartAnimation;
begin
  FStartTick    := GetTickCount;
  FTimer.Enabled:= True;
end;

procedure TAnimatedModal.TimerTick(Sender: TObject);
var
  elapsed: Int64;
  t, scale, alpha: Single;
  curW, curH, curL, curT: Integer;
begin
  elapsed := Int64(GetTickCount) - Int64(FStartTick);

  // ANIMAÇÃO DE ABERTURA COM ZOOM-IN E BOUNCE
  if not FOpenAnimDone then
  begin
    if elapsed >= COpenDurationMs then
      begin
        // Finaliza animação de abertura
        BoundsRect     := FFinalRect;
        AlphaBlendValue:= 255;
        FOpenAnimDone  := True;
        FAnimationMode := 1; // Modo ícone
        UpdateRoundedRegion(FFinalRect.Width, FFinalRect.Height);
      end
    else
      begin
        t:= elapsed / COpenDurationMs;

        // Aplica zoom-in com bounce
        scale:= ZoomInBounceEaseOut(t);

        // Calcula tamanho atual (zoom-in)
        curW:= Round(FFinalRect.Width * scale);
        curH:= Round(FFinalRect.Height * scale);

        // Centraliza mantendo o centro fixo
        curL:= FFinalRect.Left + (FFinalRect.Width - curW) div 2;
        curT:= FFinalRect.Top + (FFinalRect.Height - curH) div 2;

        SetBounds(curL, curT, curW, curH);
        UpdateRoundedRegion(curW, curH);

        // Fade acompanha o zoom-in
        alpha:= Power(t, 1.5); // Fade mais rápido que o zoom
        if alpha > 1 then alpha := 1;
        AlphaBlendValue:= Round(255 * alpha);
      end;
  end;

  // ANIMAÇÃO DO ÍCONE
  FIconBox.Invalidate;

  // Para o timer quando tudo estiver concluído
  if FOpenAnimDone and (elapsed > COpenDurationMs + CIconTotalMs + 200) then
     FTimer.Enabled:= False;
end;

procedure TAnimatedModal.IconBoxPaint(Sender: TObject);
var
  g: TGPGraphics;
  elapsed: Int64;
  circleProgress, lineProgress, zoomScale, t: Single;
const
  CUSTOM_ICON_SCALE = 0.7; // 70% do tamanho original
begin
  g:= TGPGraphics.Create(FIconBox.Canvas.Handle);

  try
    g.SetSmoothingMode(SmoothingModeAntiAlias);
    g.Clear(ARGBColor(255, GetRValue(ColorToRGB(Color)),
                           GetGValue(ColorToRGB(Color)),
                           GetBValue(ColorToRGB(Color))));

    elapsed := Int64(GetTickCount) - Int64(FStartTick);

    // Só anima o ícone depois que a abertura terminou
    if FOpenAnimDone then
    begin
      circleProgress:= EnsureRange((elapsed - COpenDurationMs) / CCircleDurationMs, 0, 1);
      lineProgress  := EnsureRange((elapsed - COpenDurationMs - CLineDelayMs) / CLineDurationMs, 0, 1);

      // Pequeno zoom-in para o ícone
      if elapsed - COpenDurationMs < 200 then
      begin
        t:= (elapsed - COpenDurationMs) / 200;
        zoomScale:= 0.8 + 0.2 * EaseOutCubic(t);
      end
      else
        zoomScale:= 1.0;

      g.TranslateTransform(FIconBox.Width / 2, FIconBox.Height / 2);
      //g.ScaleTransform(zoomScale, zoomScale);
      g.ScaleTransform(zoomScale * CUSTOM_ICON_SCALE, zoomScale * CUSTOM_ICON_SCALE);
      g.TranslateTransform(-65.1, -65.1);

      if Assigned(FCustomIcon) then
         DrawCustomIcon(g)
      else
         DrawVectorIcon(g, circleProgress, lineProgress);
    end;
  finally
    g.Free;
  end;
end;

procedure TAnimatedModal.DrawVectorIcon(g: TGPGraphics; CircleProgress, LineProgress: Single);
var
  LPen: TGPPen;
  LBrush: TGPSolidBrush;
  LColor: ARGB;
  dotProgress, dotR: Single;
  fontFamily: TGPFontFamily;
  LFont: TGPFont;
  LStrFormat: TGPStringFormat;
  txtBrush: TGPSolidBrush;
  layoutRect: TGPRectF;
  txtAlpha: Byte;
  popScale: Single;
begin
  LColor:= ARGBColor(255, GetRValue(ColorToRGB(KindColor)),
                          GetGValue(ColorToRGB(KindColor)),
                          GetBValue(ColorToRGB(KindColor)));

  LPen:= TGPPen.Create(LColor, 6);
  try
    LPen.SetLineCap(LineCapRound, LineCapRound, DashCapFlat);
    g.DrawArc(LPen, 3.0, 3.0, 124.2, 124.2, -90, 360 * CircleProgress);

    case FKind of
      mkSuccess: DrawPartialPolyline(g, LPen, [MakePt(100.2, 40.2), MakePt(51.5, 88.8), MakePt(29.8, 67.5)], LineProgress);

      mkError:
        begin
          DrawPartialPolyline(g, LPen, [MakePt(34.4, 37.9), MakePt(95.8, 92.3)], LineProgress);
          DrawPartialPolyline(g, LPen, [MakePt(95.8, 38.0), MakePt(34.4, 92.2)], LineProgress);
        end;

      mkWarning:
        begin
          DrawPartialPolyline(g, LPen, [MakePt(65.1, 32.0), MakePt(65.1, 78.0)], LineProgress);
          dotProgress:= EnsureRange((LineProgress - 0.8) / 0.2, 0, 1);

          if dotProgress > 0 then
          begin
            dotR  := 5 * dotProgress;
            LBrush:= TGPSolidBrush.Create(LColor);
            try
              g.FillEllipse(LBrush, 65.1 - dotR, 92 - dotR, dotR * 2, dotR * 2);
            finally
              LBrush.Free;
            end;
          end;
        end;

      mkQuestion:
        begin
          txtAlpha:= Round(255 * EnsureRange(LineProgress, 0, 1));

          if txtAlpha > 0 then
          begin
            popScale:= 0.6 + 0.4 * EnsureRange(LineProgress, 0, 1);

            g.TranslateTransform(65.1, 65.1);
            g.ScaleTransform(popScale, popScale);
            g.TranslateTransform(-65.1, -65.1);

            layoutRect.X     := 0;
            layoutRect.Y     := 0;
            layoutRect.Width := 130.2;
            layoutRect.Height:= 130.2;

            fontFamily:= TGPFontFamily.Create('Segoe UI');
            try
              LFont:= TGPFont.Create(fontFamily, 78, FontStyleBold, UnitPixel);
              try
                LStrFormat:= TGPStringFormat.Create;
                try
                  LStrFormat.SetAlignment(StringAlignmentCenter);
                  LStrFormat.SetLineAlignment(StringAlignmentCenter);

                  txtBrush:= TGPSolidBrush.Create(ARGBColor(txtAlpha,
                    GetRValue(ColorToRGB(KindColor)),
                    GetGValue(ColorToRGB(KindColor)),
                    GetBValue(ColorToRGB(KindColor))));
                  try
                    g.DrawString('?', 1, LFont, layoutRect, LStrFormat, txtBrush);
                  finally
                    txtBrush.Free;
                  end;
                finally
                  LStrFormat.Free;
                end;
              finally
                LFont.Free;
              end;
            finally
              fontFamily.Free;
            end;
          end;
        end;
    end;
  finally
    LPen.Free;
  end;
end;

procedure TAnimatedModal.DrawCustomIcon(g: TGPGraphics);
var
  iw, ih: Single;
begin
  if not Assigned(FCustomIcon) then
    Exit;

  iw:= 120.2 * 0.8;
  ih:= iw * (FCustomIcon.GetHeight / FCustomIcon.GetWidth);

  g.DrawImage(FCustomIcon, (120.2 - iw) / 2, (120.2 - ih) / 2, iw, ih);
end;

initialization
  GDIPStartupInput.DebugEventCallback      := nil;
  GDIPStartupInput.SuppressBackgroundThread:= False;
  GDIPStartupInput.SuppressExternalCodecs  := False;
  GDIPStartupInput.GdiplusVersion          := 1;
  GdiplusStartup(GDIPToken, @GDIPStartupInput, nil);

finalization
  GdiplusShutdown(GDIPToken);

end.
