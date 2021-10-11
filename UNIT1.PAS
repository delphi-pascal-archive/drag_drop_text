unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, OleCtnrs, StdCtrls, ActiveX, ComObj, ShellAPI, ComCtrls,
  ExtCtrls;

type
  TForm1 = class(TForm,IDropTarget)
    Memo1: TMemo;
    Label1: TLabel;
    Edit1: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Déclarations privées }
    function DragEnter(const dataObj: IDataObject;
                       grfKeyState: Longint;
                       pt: TPoint;
                       var dwEffect: Longint): HResult; stdcall;
    function DragOver(grfKeyState: Longint;
                      pt: TPoint;
                      var dwEffect: Longint): HResult; stdcall;
    function DragLeave: HResult; stdcall;
    function Drop(const dataObj: IDataObject;
                  grfKeyState: Longint; pt: TPoint;
                  var dwEffect: Longint): HResult; stdcall;

    Function GetComponentIndex(pt : TPoint) : Int64;
  public
    { Déclarations publiques }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

// Recherche du control se trouvant sous le curseur (Pt contien les coordonées écran du curseur)
//   Utilisation de la position absolue du composant
Function TForm1.GetComponentIndex(pt : TPoint) : Int64;
Var C : int64; K : boolean;
begin
 C := Pred(ComponentCount);
 K := True;
 Result := -1;
 while K  and (C >= 0) do  // on cherche en premier les composants enfant  -> comptage en décroissant
  begin
   with Tcontrol(Components[C]) do begin
     if (Pt.X >= ClientOrigin.X)and (Pt.X <= (ClientOrigin.X + Width)) and
     (Pt.Y >= ClientOrigin.Y) and (Pt.Y <= (ClientOrigin.Y + Height)) then
      begin
       result := C;
       K := False;
      end;
    end;
  dec(C);
 end;
end;

// Pour le momment, Beaucoup de choses m'échappent
// Je n'ai pas encore tout analisé (Manque d'information sur ActiveX.Pas)
procedure TForm1.FormCreate(Sender: TObject);
begin
  OleInitialize(nil);
  OleCheck(RegisterDragDrop(Handle, Self));
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  RevokeDragDrop(Handle);
  OleUninitialize;
end;

function TForm1.DragEnter(const dataObj: IDataObject; grfKeyState: Longint; pt: TPoint; var dwEffect: Longint): HResult;
begin
  dwEffect := DROPEFFECT_NONE; // Ici on peux choisir si le drop est actif dès son entrée dans la Form (ici j'ai choisi de la désactiver)
  Result  := S_OK;             // à savoir que dans un même temps Dragover va prendre la main dessus
end;


// ici je sélectionne LEs composants qui vont accepter le Drop

function TForm1.DragOver(grfKeyState: Longint; pt: TPoint; var dwEffect: Longint): HResult;
Var n : int64;
Begin
  dwEffect := DROPEFFECT_None;  // on interdi l'importation des données
  N := GetComponentIndex(Pt);
  if N > -1 then
   begin
    if (Components[N].Name = 'Edit1') or  // Autorisation d'importation des données
       (Components[N].Name = 'Memo1') or  // Pour les composant choisis
       (Components[N].Name = 'Label1') then dwEffect := DROPEFFECT_COPY
   end;
  Result := S_OK;
end;

function TForm1.DragLeave: HResult;
begin
 Result := S_OK;
end;

function TForm1.Drop(const dataObj: IDataObject; grfKeyState: Longint; pt: TPoint; var dwEffect: Longint): HResult;
var
  aFmtEtc: TFORMATETC;
  aStgMed: TSTGMEDIUM;
  pData: PChar;

  I : integer;
begin
//             Les données suivantes se trouvent dans activeX.pas

//  DROPEFFECT_NONE      => 0      rend inactif l'action
//  DROPEFFECT_COPY      => 1      Autorise la copy
//  DROPEFFECT_MOVE      => 2      Autorise le déplacement
//  DROPEFFECT_LINK      => 3                 ???
//  DROPEFFECT_SCROLL    => $80000000         ???

   I :=  MessageDlg('Voullez vous Supprimer les données de la Zone de départ ?',mtInformation,mbYesNoCancel,-1);
   if I in [mrYes,mrNo] then
   begin
     Case I of
       mrYes : dwEffect:= DROPEFFECT_MOVE; // supprime de la zone de départ
       mrNo  : dwEffect:= DROPEFFECT_COPY; // fait une simple copie
     end;

  if (dataObj = nil) then
    raise Exception.Create('IDataObject-Pointer is not valid!');
  // préparation du format de réception ( TEXTE )
  with aFmtEtc do
  begin
    cfFormat := CF_TEXT;
    ptd := nil;
    dwAspect := DVASPECT_CONTENT;
    lindex := -1;
    tymed := TYMED_HGLOBAL;
  end;
  // récupération des données
  OleCheck(dataObj.GetData(aFmtEtc, aStgMed));
  try
    pData := GlobalLock(aStgMed.hGlobal); // pdata contien le texte à importer

    // gestion en fonction des différents contols
    if components[GetComponentIndex(Pt)].Name = 'Label1' then Label1.Caption := pData else
    if components[GetComponentIndex(Pt)].Name = 'Edit1' then Edit1.Text := pData else
    if components[GetComponentIndex(Pt)].Name = 'Memo1' then
      begin
       // Calcul de la position du pointeur de la souris pour positionner le texte à une position précise dans le TMemo
       I := (pt.Y - (Top + (Height - ClientHeight) + Memo1.Top)) shl 16 +
           (pt.X - (Left + (Width - ClientWidth) div 2 + Memo1.Left));
       I := LoWord(Memo1.Perform(EM_CHARFROMPOS, 0, I));
       Memo1.SelStart := I;        // on positionne le curseur de selection sous le pointeur de la souris
       Memo1.SetSelTextBuf(pdata); // on insert le text là où est le curseur
      end;
  finally
   GlobalUnlock(aStgMed.hGlobal);
   ReleaseStgMedium(aStgMed);
  end;


  end else dwEffect := DROPEFFECT_NONE;
  Result := S_OK;

end;

end.
