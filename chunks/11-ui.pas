{ chunk: options dialog -- EscKeyHandler, chk*Click handlers, ShowPrompt }

Procedure EscKeyHandler(Sender: TObject; Var Key: Word; Shift: TShiftState);
Begin
  If Key = 27 Then
    Sender.Close;
End;



Procedure chkAddTagsClick(Sender: TObject);
Begin
{#IF SINGLE,MULTI}
  g_AddTags := Sender.Checked;
{#ELSEIF DEBUG}
  // READ-ONLY DEBUG FORK: g_AddTags is unconditionally False; ignore checkbox state.
  g_AddTags := False;
{#ENDIF}
End;

Procedure chkAddFileClick(Sender: TObject);
Begin
  g_AddFile := Sender.Checked;
End;


Procedure chkLoggingClick(Sender: TObject);
Begin
  g_LogTests := Sender.Checked;
End;


Procedure chkTagRelationshipsClick(Sender: TObject);
Begin
  g_ShowTagRelationships := Sender.Checked;
End;


Procedure chkHeuristicForceTagsClick(Sender: TObject);
Begin
  g_HeuristicForceTags := Sender.Checked;
End;


Function ShowPrompt(ACaption: String): integer;

Var 
  frm                : TForm;
  chkAddTags         : TCheckBox;
  chkAddFile         : TCheckBox;
  chkLogging         : TCheckBox;
  chkTagRelations    : TCheckBox;
  chkHeuristicForce  : TCheckBox;
  btnCancel          : TButton;
  btnOk              : TButton;
  i                  : integer;
Begin
  Result := mrCancel;

  frm := TForm.Create(TForm(frmMain));

  Try
    frm.Caption      := ACaption;
    frm.BorderStyle  := bsToolWindow;
    frm.ClientWidth  := 360 * ScaleFactor;
    frm.ClientHeight := 211 * ScaleFactor;
    frm.Position     := poScreenCenter;
    frm.KeyPreview   := True;
    frm.OnKeyDown    := EscKeyHandler;

    chkAddTags := TCheckBox.Create(frm);
    chkAddTags.Parent   := frm;
    chkAddTags.Left     := 16 * ScaleFactor;
    chkAddTags.Top      := 16 * ScaleFactor;
    chkAddTags.Width    := 185 * ScaleFactor;
    chkAddTags.Height   := 16 * ScaleFactor;
    chkAddTags.Caption  := 'Write suggested tags to header';
    chkAddTags.Checked  := False;
{#IF SINGLE,MULTI}
    g_AddTags := chkAddTags.Checked;
{#ELSEIF DEBUG}
    chkAddTags.Enabled  := False;     // READ-ONLY DEBUG FORK
    g_AddTags := False;               // never honored regardless of checkbox state
{#ENDIF}
    chkAddTags.OnClick  := chkAddTagsClick;
    chkAddTags.TabOrder := 0;

    chkAddFile := TCheckBox.Create(frm);
    chkAddFile.Parent   := frm;
    chkAddFile.Left     := 16 * ScaleFactor;
    chkAddFile.Top      := 39 * ScaleFactor;
    chkAddFile.Width    := 185 * ScaleFactor;
    chkAddFile.Height   := 16 * ScaleFactor;
    chkAddFile.Caption  := 'Write suggested tags to file';
    chkAddFile.Checked  := False;
{#IF SINGLE,MULTI}
    g_AddFile := chkAddFile.Checked;
{#ELSEIF DEBUG}
    chkAddFile.Enabled  := False;     // READ-ONLY DEBUG FORK
    g_AddFile := False;               // never honored regardless of checkbox state
{#ENDIF}
    
    chkAddFile.OnClick  := chkAddFileClick;
    chkAddFile.TabOrder := 0;

    chkLogging := TCheckBox.Create(frm);
    chkLogging.Parent   := frm;
    chkLogging.Left     := 16 * ScaleFactor;
    chkLogging.Top      := 62 * ScaleFactor;
    chkLogging.Width    := 185 * ScaleFactor;
    chkLogging.Height   := 16 * ScaleFactor;
    chkLogging.Caption  := 'Log test results to Messages tab';
    chkLogging.Checked  := True;
    g_LogTests := chkLogging.Checked;
    chkLogging.OnClick  := chkLoggingClick;
    chkLogging.TabOrder := 1;

    chkTagRelations := TCheckBox.Create(frm);
    chkTagRelations.Parent   := frm;
    chkTagRelations.Left     := 16 * ScaleFactor;
    chkTagRelations.Top      := 85 * ScaleFactor;
    chkTagRelations.Width    := 210 * ScaleFactor;
    chkTagRelations.Height   := 16 * ScaleFactor;
    chkTagRelations.Caption  := 'Show Tag to Record Relationships';
    chkTagRelations.Checked  := True;
    g_ShowTagRelationships := chkTagRelations.Checked;
    chkTagRelations.OnClick  := chkTagRelationshipsClick;
    chkTagRelations.TabOrder := 2;

    chkHeuristicForce := TCheckBox.Create(frm);
    chkHeuristicForce.Parent   := frm;
    chkHeuristicForce.Left     := 16 * ScaleFactor;
    chkHeuristicForce.Top      := 108 * ScaleFactor;
    chkHeuristicForce.Width    := 336 * ScaleFactor;
    chkHeuristicForce.Height   := 16 * ScaleFactor;
    chkHeuristicForce.Caption  := 'Suggest heuristic Force* tags (may produce false positives)';
    chkHeuristicForce.Checked  := False;
    g_HeuristicForceTags := chkHeuristicForce.Checked;
    chkHeuristicForce.OnClick  := chkHeuristicForceTagsClick;
    chkHeuristicForce.TabOrder := 3;

    btnOk := TButton.Create(frm);
    btnOk.Parent              := frm;
    btnOk.Left                := 102 * ScaleFactor;
    btnOk.Top                 := 173 * ScaleFactor;
    btnOk.Width               := 75 * ScaleFactor;
    btnOk.Height              := 25 * ScaleFactor;
    btnOk.Caption             := 'Run';
    btnOk.Default             := True;
    btnOk.ModalResult         := mrOk;
    btnOk.TabOrder            := 3;

    btnCancel := TButton.Create(frm);
    btnCancel.Parent          := frm;
    btnCancel.Left            := 183 * ScaleFactor;
    btnCancel.Top             := 173 * ScaleFactor;
    btnCancel.Width           := 75 * ScaleFactor;
    btnCancel.Height          := 25 * ScaleFactor;
    btnCancel.Caption         := 'Abort';
    btnCancel.ModalResult     := mrAbort;
    btnCancel.TabOrder        := 4;

    Result := frm.ShowModal;
  Finally
    frm.Free;
  End;
End;
