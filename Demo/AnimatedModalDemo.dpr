program AnimatedModalDemo;

uses
  Vcl.Forms,
  uMainForm in 'uMainForm.pas' {FMainForm},
  Vcl.AnimatedModal in '..\Sources\Vcl.AnimatedModal.pas',
  Vcl.AnimatedModal.StyledButton in '..\Sources\Vcl.AnimatedModal.StyledButton.pas',
  Vcl.AnimatedModal.Types in '..\Sources\Vcl.AnimatedModal.Types.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar:= True;
  ReportMemoryLeaksOnShutdown  := True;
  Application.CreateForm(TFMainForm, FMainForm);
  Application.Run;
end.
