# Animated Modal for Delphi VCL

### A modern, animated modal dialog component for **Delphi VCL** inspired by contemporary UI Angular.
###### The component displays beautiful modal messages with a smooth **Zoom-In + Bounce** animation while dimming the owner form, providing a clean and focused user experience.

## ✨ Features
* 🎉 Modern animated modal dialogs
* 🌑 Automatically darkens the owner form
* 🚀 Smooth Zoom-In animation with Bounce effect
* ✅ Four built-in modal types
    * **Success**
    * **Error**
    * **Warning**
    * **Question**
* 🎨 Modern and clean design
* ⚡ Lightweight and easy to use
* 🔥 Simple API
* 🖥 Works with Delphi VCL applications



## Modal Types

| Type          | Description                                                       |
| ------------- |:-----------------------------------------------------------------:|
| mkSuccess     | Displays a success message                                        |
| mkError       | Displays an error message                                         |
| mkWarning     | Displays a warning message                                        |
| mkQuestion    | Displays a confirmation dialog with **Yes** and **No** callbacks  |

## Installation
Simply add the component source folder to your Delphi Library Path or include it in your project.

Then add the units below to your `uses` clause:
```
uses
  Vcl.AnimatedModal.Types,
  Vcl.AnimatedModal;
```

## Basic Usage

#### Success Message

```
procedure TFMainForm.Button1Click(Sender: TObject);
begin
  TAnimatedModal.Show(
    Self,
    mkSuccess,
    'Oh Yeah!',
    'Você se cadastrou e logou com sucesso.'
  );
end;
```

------------------------------------------------------------------------------------

#### Error Message

```
procedure TFMainForm.Button2Click(Sender: TObject);
begin
  TAnimatedModal.Show(
    Self,
    mkError,
    'E-mail inválido!',
    'Este e-mail já está cadastrado, faça login.'
  );
end;
```

------------------------------------------------------------------------------------

#### Warning Message

```
procedure TFMainForm.Button3Click(Sender: TObject);
begin
  TAnimatedModal.Show(
    Self,
    mkWarning,
    'Atenção',
    'Esta é uma mensagem de aviso.'
  );
end;
```

-------------------------------------------------------------------------------------

#### Confirmation Dialog

The **Question** modal supports callback procedures for both confirmation and cancellation.

```
procedure TFMainForm.Button4Click(Sender: TObject);
begin
  TAnimatedModal.Show(
    Self,
    'Excluir registro?',
    'Essa ação não pode ser desfeita. Deseja continuar?',

    procedure
    begin
      ShowMessage('Excluído!');
    end,

    procedure
    begin
      ShowMessage('Cancelado.');
    end
  );
end;
```

--------------------------------------------------------------------------------------

## Animation

Every modal is displayed using a modern animation sequence:

- Zoom-In
- Bounce Effect
- Smooth Fade Overlay

The owner form is automatically dimmed while the modal is displayed, keeping the user's attention focused on the dialog.


### Demo

A complete demonstration project is available in the **Demo** folder.

The demo includes examples for:

- Success dialog
- Error dialog
- Warning dialog
- Question dialog
- Callback usage


### Folder Structure

```
Source/
    Vcl.AnimatedModal.pas
    Vcl.AnimatedModal.Types.pas

Demo/
    AnimatedModalDemo.dproj
```

## Author

Itamar Monteiro. Developed with ❤️ using Delphi VCL.