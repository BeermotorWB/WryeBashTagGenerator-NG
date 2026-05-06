{ chunk: evaluate orchestration -- Evaluate/EvaluateAdd/Change/Remove, EvaluateByPath*, EvaluateBySignature, ResolveListArray, ListEntryKey, ListContainsKey, EvaluateListAdd/Remove, TryTagGatedByFlag }

Procedure Evaluate(AElement: IwbElement; AMaster: IwbElement);
Begin
  DbgLog(DBG_PER_COMPARE, Format('Evaluate: tag=%s path=%s (-> Assignment, ElementCount, EditValue, Keys)',
    [g_Tag, DbgPath(AElement)]));

  // exit if the tag already exists
  If TagExists(g_Tag) Then
    Exit;

  // Suggest tag if one element exists while the other does not
  If CompareAssignment(AElement, AMaster) Then
    Exit;

  // exit if the first element does not exist
  If Not Assigned(AElement) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  Evaluate: override side nil; further checks skipped');
      Exit;
    End;

  // suggest tag if the two elements are different
  If CompareElementCount(AElement, AMaster) Then
    Exit;

  // suggest tag if the edit values of the two elements are different
  If CompareEditValue(AElement, AMaster) Then
    Exit;

  // compare any number of elements with CompareKeys
  If CompareKeys(AElement, AMaster) Then
    Exit;
End;


Procedure EvaluateAdd(AElement: IwbElement; AMaster: IwbElement);
Begin
  DbgLog(DBG_PER_COMPARE, Format('EvaluateAdd: tag=%s path=%s', [g_Tag, DbgPath(AElement)]));
  If TagExists(g_Tag) Then
    Exit;

  If Not Assigned(AElement) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  EvaluateAdd: override side nil; nothing to add-check');
      Exit;
    End;

  // suggest tag if the overriding element has more children than its master
  If CompareElementCountAdd(AElement, AMaster) Then
    Exit;
End;


Procedure EvaluateChange(AElement: IwbElement; AMaster: IwbElement);
Begin
  DbgLog(DBG_PER_COMPARE, Format('EvaluateChange: tag=%s path=%s', [g_Tag, DbgPath(AElement)]));
  If TagExists(g_Tag) Then
    Exit;

  If Not Assigned(AElement) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  EvaluateChange: override side nil; nothing to change-check');
      Exit;
    End;

  // suggest tag if the two elements and their descendants have different contents
  If CompareKeys(AElement, AMaster) Then
    Exit;
End;


Procedure EvaluateRemove(AElement: IwbElement; AMaster: IwbElement);
Begin
  DbgLog(DBG_PER_COMPARE, Format('EvaluateRemove: tag=%s path=%s', [g_Tag, DbgPath(AElement)]));
  If TagExists(g_Tag) Then
    Exit;

  If Not Assigned(AElement) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  EvaluateRemove: override side nil; nothing to remove-check');
      Exit;
    End;

  // suggest tag if the master element has more children than its override
  If CompareElementCountRemove(AElement, AMaster) Then
    Exit;
End;


Procedure EvaluateByPath(AElement: IwbElement; AMaster: IwbElement; APath: String);

Var 
  x : IInterface;
  y : IInterface;
Begin
  DbgLog(DBG_PER_COMPARE, Format('EvaluateByPath: tag=%s path="%s"', [g_Tag, APath]));
  x := ElementByPath(AElement, APath);
  y := ElementByPath(AMaster, APath);

  Evaluate(x, y);
End;


Procedure EvaluateByPathAdd(AElement: IwbElement; AMaster: IwbElement; APath: String);

Var 
  x : IInterface;
  y : IInterface;
Begin
  DbgLog(DBG_PER_COMPARE, Format('EvaluateByPathAdd: tag=%s path="%s"', [g_Tag, APath]));
  x := ElementByPath(AElement, APath);
  y := ElementByPath(AMaster, APath);

  EvaluateAdd(x, y);
End;


Procedure EvaluateByPathChange(AElement: IwbElement; AMaster: IwbElement; APath: String);

Var 
  x : IInterface;
  y : IInterface;
Begin
  DbgLog(DBG_PER_COMPARE, Format('EvaluateByPathChange: tag=%s path="%s"', [g_Tag, APath]));
  x := ElementByPath(AElement, APath);
  y := ElementByPath(AMaster, APath);

  EvaluateChange(x, y);
End;


Procedure EvaluateByPathRemove(AElement: IwbElement; AMaster: IwbElement; APath: String);

Var 
  x : IInterface;
  y : IInterface;
Begin
  DbgLog(DBG_PER_COMPARE, Format('EvaluateByPathRemove: tag=%s path="%s"', [g_Tag, APath]));
  x := ElementByPath(AElement, APath);
  y := ElementByPath(AMaster, APath);

  EvaluateRemove(x, y);
End;


// Resolves by subrecord signature (XOWN, XRNK, XGLB, ...) instead of a named
// struct path. Needed for tests where relying on an xEdit-defined parent
// struct is fragile (e.g. the 'Ownership' RStruct whose collapsed-summary
// GetEditValue varies across xEdit versions). Semantics otherwise match
// EvaluateByPath: suggest the tag if one side is present and the other isn't,
// if child counts differ, if the subrecord's own edit value differs, or if
// the recursive serialized contents differ.
Procedure EvaluateBySignature(AElement: IwbElement; AMaster: IwbElement; ASignature: String);

Var 
  x : IInterface;
  y : IInterface;
Begin
  DbgLog(DBG_PER_COMPARE, Format('EvaluateBySignature: tag=%s sig=%s', [g_Tag, ASignature]));
  x := ElementBySignature(AElement, ASignature);
  y := ElementBySignature(AMaster, ASignature);

  DbgLog(DBG_LEAF_DIFFS, Format('       override-present=%s  master-present=%s',
    [IfThen(Assigned(x), 'true', 'false'), IfThen(Assigned(y), 'true', 'false')]));
  If Assigned(x) Or Assigned(y) Then
    Begin
      DbgLog(DBG_LEAF_DIFFS, Format('       override-edv="%s"', [DbgEdv(x)]));
      DbgLog(DBG_LEAF_DIFFS, Format('       master-edv  ="%s"', [DbgEdv(y)]));
    End;

  Evaluate(x, y);
End;


// Resolves a named top-level list on a main record. ElementByPath is the
// standard accessor but it does not reliably resolve wbArrayS-with-signature
// arrays that live directly on the record (e.g. OTFT INAM 'Items'): on those
// the path lookup can return nil while ElementBySignature succeeds. Callers
// can therefore pass either the xEdit name ('Items', 'Perks', 'Relations',
// 'FormIDs') or the 4-char signature ('INAM') — whichever is most reliable
// for the record type.
Function ResolveListArray(ARec: IInterface; Const ANameOrSig: String): IInterface;
Begin
  Result := ElementByPath(ARec, ANameOrSig);
  If Not Assigned(Result) Then
    Result := ElementBySignature(ARec, ANameOrSig);
End;


// Returns the "identity key" used for set-diff on a list entry. If ARefPath is
// empty the key is the entry's own edit value (flat FormID lists like OTFT
// 'Items' or FLST 'FormIDs'). Otherwise the key is taken from the named
// sub-path inside the entry (struct lists like NPC_ 'Perks'->'Perk',
// CONT 'Items'->'CNTO\Item', FACT 'Relations'->'Faction').
Function ListEntryKey(AEntry: IInterface; Const ARefPath: String): string;
Begin
  If ARefPath = '' Then
    Result := GetEditValue(AEntry)
  Else
    Result := GetElementEditValues(AEntry, ARefPath);
End;


// True iff an entry with the given key exists in the master array. Linear
// scan; lists are small (perks, items, factions, relations rarely exceed
// low double-digit counts).
Function ListContainsKey(AArr: IInterface; Const AKey: String; Const ARefPath: String): boolean;
Var 
  j : integer;
Begin
  Result := False;
  If Not Assigned(AArr) Then
    Exit;
  For j := 0 To Pred(ElementCount(AArr)) Do
    If SameText(ListEntryKey(ElementByIndex(AArr, j), ARefPath), AKey) Then
      Begin
        Result := True;
        Exit;
      End;
End;


// Set-diff .Add detector for keyed sub-record lists (OTFT Items, CONT Items,
// NPC_ Perks, FLST FormIDs, FACT Relations, RACE Relations).
// Suggests ATagName iff at least one override entry's identity key is NOT
// present in the master array. Unlike the prior element-count heuristic this
// correctly fires when a mod substitutes items (same total count, different
// entries), e.g. CRF's MQ101StormcloakPrisonerOutfit swapping a static ARMO
// for a CRFArmorStormcloakCuirass LVLI.
Procedure EvaluateListAdd(ARec: IInterface; AMaster: IInterface;
                           Const AArrayName: String; Const ARefPath: String);

Var 
  kArr, kArrM : IInterface;
  kEntry      : IInterface;
  i, nA, nM   : integer;
  sRef        : string;
Begin
  DbgLog(DBG_PER_COMPARE, Format('EvaluateListAdd: tag=%s arr=%s refPath=%s',
    [g_Tag, AArrayName, ARefPath]));
  If TagExists(g_Tag) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> SKIP (tag already suggested earlier)');
      Exit;
    End;

  kArr  := ResolveListArray(ARec,    AArrayName);
  kArrM := ResolveListArray(AMaster, AArrayName);

  If Assigned(kArr)  Then nA := ElementCount(kArr)  Else nA := 0;
  If Assigned(kArrM) Then nM := ElementCount(kArrM) Else nM := 0;
  DbgLog(DBG_LEAF_DIFFS, Format('       override-count=%d  master-count=%d', [nA, nM]));
  
  If Not Assigned(kArr) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> NO-OP (override array missing)');
      Exit;
    End;
  If ElementCount(kArr) = 0 Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> NO-OP (override array empty)');
      Exit;
    End;


  For i := 0 To Pred(ElementCount(kArr)) Do
    Begin
      kEntry := ElementByIndex(kArr, i);
      sRef   := ListEntryKey(kEntry, ARefPath);
      If sRef = '' Then
        Begin
          DbgLog(DBG_LEAF_DIFFS, Format('       entry[%d] key="" (skip)', [i]));
          Continue;
        End;

      If Not ListContainsKey(kArrM, sRef, ARefPath) Then
        Begin
          DbgLog(DBG_PER_COMPARE, Format('  -> SUGGEST %s (override entry[%d] key="%s" absent on master)',[g_Tag, i, sRef]));
          AddLogEntry('ListAdd', kEntry, kArrM);
          slSuggestedTags.Add(g_Tag);
          Exit;
        End
      Else
          DbgLog(DBG_LEAF_DIFFS, Format('       entry[%d] key="%s" present on master', [i, sRef]));
        End;
    End;
  DbgLog(DBG_PER_COMPARE, '  -> NO-OP (all override entries match by key)');
End;


// Symmetric of EvaluateListAdd. Suggests ATagName iff at least one master
// entry's identity key is NOT present in the override array.
Procedure EvaluateListRemove(ARec: IInterface; AMaster: IInterface;
                              Const AArrayName: String; Const ARefPath: String);

Var 
  kArr, kArrM : IInterface;
  kEntry      : IInterface;
  i, nA, nM   : integer;
  sRef        : string;
Begin
  DbgLog(DBG_PER_COMPARE, Format('EvaluateListRemove: tag=%s arr=%s refPath=%s', [g_Tag, AArrayName, ARefPath]));
  If TagExists(g_Tag) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> SKIP (tag already suggested earlier)');
      Exit;
    End;

  kArr  := ResolveListArray(ARec,    AArrayName);
  kArrM := ResolveListArray(AMaster, AArrayName);

  If Assigned(kArr)  Then nA := ElementCount(kArr)  Else nA := 0;
  If Assigned(kArrM) Then nM := ElementCount(kArrM) Else nM := 0;
  DbgLog(DBG_LEAF_DIFFS, Format('       override-count=%d  master-count=%d', [nA, nM]));

  If Not Assigned(kArrM) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> NO-OP (master array missing)');
      Exit;
    End;
  If ElementCount(kArrM) = 0 Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> NO-OP (master array empty)');
      Exit;
    End;

  For i := 0 To Pred(ElementCount(kArrM)) Do
    Begin
      kEntry := ElementByIndex(kArrM, i);
      sRef   := ListEntryKey(kEntry, ARefPath);
      If sRef = '' Then
        Begin
          DbgLog(DBG_LEAF_DIFFS, Format('       entry[%d] key="" (skip)', [i]));
          Continue;
        End;

      If Not ListContainsKey(kArr, sRef, ARefPath) Then
        Begin
          DbgLog(DBG_PER_COMPARE, Format('  -> SUGGEST %s (master entry[%d] key="%s" absent on override)', [g_Tag, i, sRef]));
          AddLogEntry('ListRemove', kEntry, kArr);
          slSuggestedTags.Add(g_Tag);
          Exit;
        End
      Else
          DbgLog(DBG_LEAF_DIFFS, Format('       entry[%d] key="%s" present on override', [i, sRef]));
        End;
    End;

  DbgLog(DBG_PER_COMPARE, '  -> NO-OP (all master entries match by key)');
End;

// Gate ProcessTag on the template flag named AFlagName under 'ACBS\Template Flags'.
// If the flag is set on either side (master or override), the NPC/CREA inherits
// that subrecord from its template and overriding it would be a no-op, so we
// skip. Otherwise emit the tag. Mirrors the g_Tag := ATag; If Not CompareFlags(...)
// Then ProcessTag(ATag, ...) idiom used throughout ProcessRecord.
Procedure TryTagGatedByFlag(Const ATag, AFlagName: String; e, o: IInterface);
Begin
  g_Tag := ATag;
  If Not CompareFlags(e, o, 'ACBS\Template Flags', AFlagName, False, False) Then
    ProcessTag(ATag, e, o);
End;
