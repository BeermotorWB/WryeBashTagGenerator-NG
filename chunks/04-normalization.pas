{ chunk: tag normalization -- TagIsRemoved, ExpandOneAliasTo, NormalizeBashTagsInPlace, TagsCommaTextEqual }

Function TagIsRemoved(Const t: String): boolean;
Begin
  Result := SameText(t, 'Merge') Or SameText(t, 'ScriptContents');
End;


Procedure ExpandOneAliasTo(Const t: String; dest: TStringList);

Var 
  s : string;
Begin
  s := Trim(t);
  If s = '' Then
    Exit;
  If TagIsRemoved(s) Then
    Exit;

  If SameText(s, 'Actors.Perks.Add') Then
    dest.Add('NPC.Perks.Add')
  Else If SameText(s, 'Actors.Perks.Change') Then
         dest.Add('NPC.Perks.Change')
  Else If SameText(s, 'Actors.Perks.Remove') Then
         dest.Add('NPC.Perks.Remove')
  Else If SameText(s, 'Body-F') Then
         dest.Add('R.Body-F')
  Else If SameText(s, 'Body-M') Then
         dest.Add('R.Body-M')
  Else If SameText(s, 'Body-Size-F') Then
         dest.Add('R.Body-Size-F')
  Else If SameText(s, 'Body-Size-M') Then
         dest.Add('R.Body-Size-M')
  Else If SameText(s, 'C.GridFlags') Then
         dest.Add('C.ForceHideLand')
  Else If SameText(s, 'Derel') Then
         dest.Add('Relations.Remove')
  Else If SameText(s, 'Eyes') Or SameText(s, 'Eyes-D') Or SameText(s, 'Eyes-E') Or SameText(s, 'Eyes-R') Then
         dest.Add('R.Eyes')
  Else If SameText(s, 'Factions') Then
         dest.Add('Actors.Factions')
  Else If SameText(s, 'Hair') Then
         dest.Add('R.Hair')
  Else If SameText(s, 'Invent') Then
         Begin
           dest.Add('Invent.Add');
           dest.Add('Invent.Remove');
         End
  Else If SameText(s, 'InventOnly') Then
         Begin
           dest.Add('IIM');
           dest.Add('Invent.Add');
           dest.Add('Invent.Remove');
         End
  Else If SameText(s, 'Npc.EyesOnly') Then
         dest.Add('NPC.Eyes')
  Else If SameText(s, 'Npc.HairOnly') Then
         dest.Add('NPC.Hair')
  Else If SameText(s, 'NpcFaces') Then
         Begin
           dest.Add('NPC.Eyes');
           dest.Add('NPC.Hair');
           dest.Add('NPC.FaceGen');
         End
  Else If SameText(s, 'R.Relations') Then
         Begin
           dest.Add('R.Relations.Add');
           dest.Add('R.Relations.Change');
           dest.Add('R.Relations.Remove');
         End
  Else If SameText(s, 'Relations') Then
         Begin
           dest.Add('Relations.Add');
           dest.Add('Relations.Change');
         End
  Else If SameText(s, 'Voice-F') Then
         dest.Add('R.Voice-F')
  Else If SameText(s, 'Voice-M') Then
         dest.Add('R.Voice-M')
  Else
    dest.Add(s);
End;


Procedure NormalizeBashTagsInPlace(sl: TStringList);

Var 
  tmp : TStringList;
  i   : integer;
Begin
  tmp := MakeTagSet;
  Try
    For i := 0 To Pred(sl.Count) Do
      ExpandOneAliasTo(sl[i], tmp);
    sl.Clear;
    sl.AddStrings(tmp);
  Finally
    tmp.Free;
  End;
End;


Function TagsCommaTextEqual(slA: TStringList; slB: TStringList): boolean;

Var 
  tA : TStringList;
  tB : TStringList;
Begin
  tA := MakeTagSet;
  tB := MakeTagSet;
  Try
    tA.AddStrings(slA);
    tB.AddStrings(slB);
    Result := SameText(tA.CommaText, tB.CommaText);
  Finally
    tA.Free;
    tB.Free;
  End;
End;
