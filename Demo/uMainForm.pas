unit uMainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.AnimatedModal.Types,
  Vcl.AnimatedModal;

type
  TFMainForm = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FMainForm: TFMainForm;

implementation

{$R *.dfm}

procedure TFMainForm.Button1Click(Sender: TObject);
begin
  TAnimatedModal.Show(Self, mkSuccess, 'Oh Yeah!', 'Você se cadastrou e logou com sucesso.');
end;

procedure TFMainForm.Button2Click(Sender: TObject);
begin
  TAnimatedModal.Show(Self, mkError, 'E-mail inválido!', 'Este e-mail já está cadastrado, faça login.');
end;

procedure TFMainForm.Button3Click(Sender: TObject);
begin
  TAnimatedModal.Show(Self, mkWarning, 'Atenção', 'Esta é uma mensagem de aviso.');
end;

procedure TFMainForm.Button4Click(Sender: TObject);
begin
  TAnimatedModal.Show(Self, 'Excluir registro?', 'Essa ação não pode ser desfeita. Deseja continuar?',
    procedure
    begin
      ShowMessage('Excluído!');
    end,
    procedure
    begin
      ShowMessage('Cancelado.');
    end);
end;

end.
