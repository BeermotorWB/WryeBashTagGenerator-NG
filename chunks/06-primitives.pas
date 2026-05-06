{ chunk: leaf primitives -- Compare* family, EditValues, SortedArrayElementByValue, StringListDifference/Intersection, IsEmptyKey, FormatTags, TagExists, AddLogEntry }

Function CompareAssignment(AElement: IwbElement; AMaster: IwbElement): boolean;
Begin
  Result := False;

  DbgLog(DBG_PER_COMPARE, Format('CompareAssignment: tag=%s e=%s m=%s',
    [g_Tag, IfThen(Assigned(AElement), 'assigned', 'nil'), IfThen(Assigned(AMaster), 'assigned', 'nil')]));

  If TagExists(g_Tag) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> SKIP (tag already suggested earlier)');
      Exit;
    End;

  If Not Assigned(AElement) And Not Assigned(AMaster) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> NO-OP (both sides nil)');
      Exit;
    End;

  If Assigned(AElement) And Assigned(AMaster) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> NO-OP (both sides assigned; needs deeper compare)');
      Exit;
    End;

  AddLogEntry('Assigned', AElement, AMaster);
  slSuggestedTags.Add(g_Tag);
  DbgLog(DBG_PER_COMPARE, Format('  -> SUGGEST %s (assignment mismatch: only %s side assigned)',
    [g_Tag, IfThen(Assigned(AElement), 'override', 'master')]));

  Result := True;
End;


Function CompareElementCount(AElement: IwbElement; AMaster: IwbElement): boolean;
Begin
  Result := False;

  DbgLog(DBG_PER_COMPARE, Format('CompareElementCount: tag=%s e=%s m=%s',
    [g_Tag, IntToStr(ElementCount(AElement)), IntToStr(ElementCount(AMaster))]));

  If TagExists(g_Tag) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> SKIP (tag already suggested earlier)');
      Exit;
    End;


  If ElementCount(AElement) = ElementCount(AMaster) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> NO-OP (counts equal)');
      Exit;
    End;

  AddLogEntry('ElementCount', AElement, AMaster);
  slSuggestedTags.Add(g_Tag);

    DbgLog(DBG_PER_COMPARE, Format('  -> SUGGEST %s (count differs: %s vs %s)',
    [g_Tag, IntToStr(ElementCount(AElement)), IntToStr(ElementCount(AMaster))]));

  Result := True;
End;


Function CompareElementCountAdd(AElement: IwbElement; AMaster: IwbElement): boolean;
Begin
  Result := False;

  DbgLog(DBG_PER_COMPARE, Format('CompareElementCountAdd: tag=%s e=%s m=%s',
    [g_Tag, IntToStr(ElementCount(AElement)), IntToStr(ElementCount(AMaster))]));
  
  If TagExists(g_Tag) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> SKIP (tag already suggested earlier)');
      Exit;
    End;


  If ElementCount(AElement) <= ElementCount(AMaster) Then
    Begin
      DbgLog(DBG_PER_COMPARE, Format('  -> NO-OP (override count %s <= master count %s, no add)',
        [IntToStr(ElementCount(AElement)), IntToStr(ElementCount(AMaster))]));
      Exit;
    End;

  AddLogEntry('ElementCountAdd', AElement, AMaster);
  slSuggestedTags.Add(g_Tag);

  DbgLog(DBG_PER_COMPARE, Format('  -> SUGGEST %s (override has %s entries vs master %s -> additions present)',
    [g_Tag, IntToStr(ElementCount(AElement)), IntToStr(ElementCount(AMaster))]));

  Result := True;
End;


Function CompareElementCountRemove(AElement: IwbElement; AMaster: IwbElement): boolean;
Begin
  Result := False;

  DbgLog(DBG_PER_COMPARE, Format('CompareElementCountRemove: tag=%s e=%s m=%s',
    [g_Tag, IntToStr(ElementCount(AElement)), IntToStr(ElementCount(AMaster))]));

  If TagExists(g_Tag) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> SKIP (tag already suggested earlier)');
      Exit;
    End;

  If ElementCount(AElement) >= ElementCount(AMaster) Then
    Begin
      DbgLog(DBG_PER_COMPARE, Format('  -> NO-OP (override count %s >= master count %s, no removal)',
        [IntToStr(ElementCount(AElement)), IntToStr(ElementCount(AMaster))]));
      Exit;
    End;


  AddLogEntry('ElementCountRemove', AElement, AMaster);
  slSuggestedTags.Add(g_Tag);

  DbgLog(DBG_PER_COMPARE, Format('  -> SUGGEST %s (override has %s entries vs master %s -> removals present)',
    [g_Tag, IntToStr(ElementCount(AElement)), IntToStr(ElementCount(AMaster))]));

  Result := True;
End;


Function CompareEditValue(AElement: IwbElement; AMaster: IwbElement): boolean;
Var
  sE, sM : string;
Begin
  Result := False;

  sE := DbgEdv(AElement);
  sM := DbgEdv(AMaster);
  DbgLog(DBG_PER_COMPARE, Format('CompareEditValue: tag=%s path=%s', [g_Tag, DbgPath(AElement)]));

  If TagExists(g_Tag) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> SKIP (tag already suggested earlier)');
      Exit;
    End;

  If SameText(GetEditValue(AElement), GetEditValue(AMaster)) Then
    Begin
      DbgLog(DBG_PER_COMPARE, Format('  -> NO-OP (edit values equal: "%s")', [sE]));
      Exit;
    End;

  AddLogEntry('GetEditValue', AElement, AMaster);
  slSuggestedTags.Add(g_Tag);
  
  DbgLog(DBG_PER_COMPARE, Format('  -> SUGGEST %s (edit values differ)', [g_Tag]));
  DbgLog(DBG_LEAF_DIFFS, Format('       override="%s"  master="%s"', [sE, sM]));

  Result := True;
End;


// Inspect a single flag by name within a flags array at APath on both records.
//
// ANotOperator selects the comparison mode:
//   False (default, "OR" mode): Result is True if the flag is set on EITHER
//     the override or master. Callers use this as a template-flag gate — if
//     the subrecord is inherited from a template on either side, the diff is
//     meaningless and the outer code should skip. This is the mode behind
//     every `If Not CompareFlags(..., False, False) Then ProcessTag(...)` site
//     (including the TryTagGatedByFlag helper).
//   True ("NOT" mode): Result is True if the flag DIFFERS between sides. Used
//     only for a handful of per-cell flags (Behave Like Exterior, Use Sky
//     Lighting, Has Water, Is Interior Cell, Can Travel From Here, etc.) where
//     a flipped flag is itself the detection signal.
//
// ASuggest routes a True result into slSuggestedTags / AddLogEntry using the
// current g_Tag. Most callers pass False and consume Result for their own gate.
Function CompareFlags(AElement: IwbElement; AMaster: IwbElement; APath: String; AFlagName: String; ASuggest: boolean; ANotOperator: boolean): boolean;

Var
  x, y      : IwbElement;
  a, b      : IwbElement;
  sa, sb    : string;
  sTestName : string;
Begin
  Result := False;

  If TagExists(g_Tag) Then
    Begin
      DbgLog(DBG_PER_COMPARE, Format('CompareFlags: tag=%s path=%s flag=%s -> SKIP (tag already suggested)',
        [g_Tag, APath, AFlagName]));
      Exit;
    End;

// flags arrays
  x := ElementByPath(AElement, APath);
  y := ElementByPath(AMaster, APath);

// individual flags
  a := ElementByName(x, AFlagName);
  b := ElementByName(y, AFlagName);

  // individual flag edit values
  sa := GetEditValue(a);
  sb := GetEditValue(b);

  If ANotOperator Then
    Result := Not SameText(sa, sb)
  Else
    Result := StrToBool(sa) Or StrToBool(sb);

  DbgLog(DBG_PER_COMPARE, Format('CompareFlags: tag=%s path=%s flag="%s" op=%s e="%s" m="%s" -> %s',
    [g_Tag, APath, AFlagName, IfThen(ANotOperator, 'NOT', 'OR'), sa, sb,
     IfThen(Result, 'TRUE (gate fired)', 'FALSE (gate did not fire)')]));

  If ASuggest And Result Then
    Begin
      If ANotOperator Then
        sTestName := 'CompareFlags:NOT'
      Else
        sTestName := 'CompareFlags:OR';
      AddLogEntry(sTestName, x, y);
      slSuggestedTags.Add(g_Tag);

      DbgLog(DBG_PER_COMPARE, Format('  -> SUGGEST %s (CompareFlags suggest=true and gate fired)', [g_Tag]));
    End;
End;


Function CompareKeys(AElement: IwbElement; AMaster: IwbElement): boolean;

Var 
  sElementEditValues : string;
  sMasterEditValues  : string;
  ConflictState      : TConflictThis;
Begin
  Result := False;

  DbgLog(DBG_PER_COMPARE, Format('CompareKeys: tag=%s path=%s', [g_Tag, DbgPath(AElement)]));

  If TagExists(g_Tag) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> SKIP (tag already suggested earlier)');
      Exit;
    End;

  ConflictState := ConflictAllForMainRecord(ContainingMainRecord(AElement));

  If (ConflictState = caUnknown)
     Or (ConflictState = caOnlyOne)
     Or (ConflictState = caNoConflict) Then
    Begin
      DbgLog(DBG_PER_COMPARE, Format('  -> SKIP (conflict state %s; CompareKeys requires real cross-plugin conflict)',
        [DbgConflictName(ConflictState)]));
      Exit;
    End;

  sElementEditValues := EditValues(AElement);
  sMasterEditValues  := EditValues(AMaster);

  If IsEmptyKey(sElementEditValues) And IsEmptyKey(sMasterEditValues) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> NO-OP (both keys empty/zeroed)');
      Exit;
    End;

  If SameText(sElementEditValues, sMasterEditValues) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> NO-OP (serialized contents identical)');
      DbgLog(DBG_LEAF_DIFFS,  Format('       both="%s"', [DbgShortVal(sElementEditValues)]));
      Exit;
    End;

  AddLogEntry('CompareKeys', AElement, AMaster);
  slSuggestedTags.Add(g_Tag);
  
  DbgLog(DBG_PER_COMPARE, Format('  -> SUGGEST %s (serialized contents differ)', [g_Tag]));
  DbgLog(DBG_LEAF_DIFFS,  Format('       override="%s"', [DbgShortVal(sElementEditValues)]));
  DbgLog(DBG_LEAF_DIFFS,  Format('       master  ="%s"', [DbgShortVal(sMasterEditValues)]));

  Result := True;
End;


Function CompareNativeValues(AElement: IwbElement; AMaster: IwbElement; APath: String): boolean;

Var 
  x : IwbElement;
  y : IwbElement;
Begin
  Result := False;

  DbgLog(DBG_PER_COMPARE, Format('CompareNativeValues: tag=%s path=%s', [g_Tag, APath]));

  If TagExists(g_Tag) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> SKIP (tag already suggested earlier)');
      Exit;
    End;

  x := ElementByPath(AElement, APath);
  y := ElementByPath(AMaster, APath);

  If GetNativeValue(x) = GetNativeValue(y) Then
    Begin
      // GetNativeValue returns a Variant; the script engine won't coerce it
      // to Integer/String, so do not embed the value itself in the log.
      DbgLog(DBG_PER_COMPARE, Format('  -> NO-OP (native values equal at path "%s")', [APath]));
      DbgLog(DBG_LEAF_DIFFS,  Format('       edit-value="%s"', [DbgEdv(x)]));
      Exit;
    End;


  AddLogEntry('CompareNativeValues', AElement, AMaster);
  slSuggestedTags.Add(g_Tag);
  
  DbgLog(DBG_PER_COMPARE, Format('  -> SUGGEST %s (native values differ at path "%s")', [g_Tag, APath]));
  DbgLog(DBG_LEAF_DIFFS,  Format('       override="%s"  master="%s"', [DbgEdv(x), DbgEdv(y)]));

  Result := True;
End;

Function EditValues(Const AElement: IwbElement): string;
Var 
  kElement : IInterface;
  sName    : string;
  i        : integer;
Begin
  Result := GetEditValue(AElement);

  For i := 0 To Pred(ElementCount(AElement)) Do
    Begin
      kElement := ElementByIndex(AElement, i);
      sName    := Name(kElement);

      If SameText(sName, 'unknown') Or SameText(sName, 'unused') Then
        Continue;

      If Result <> '' Then
        Result := Result + ' ' + EditValues(kElement)
      Else
        Result := EditValues(kElement);
    End;
End;


Function SortedArrayElementByValue(AElement: IwbElement; APath: String; AValue: String): IwbElement;

Var 
  i      : integer;
  kEntry : IwbElement;
Begin
  Result := Nil;
  For i := 0 To Pred(ElementCount(AElement)) Do
    Begin
      kEntry := ElementByIndex(AElement, i);
      If SameText(GetElementEditValues(kEntry, APath), AValue) Then
        Begin
          Result := kEntry;
          Exit;
        End;
    End;
End;


// TODO: natively implemented in 4.1.4
Procedure StringListDifference(ASet: TStringList; AOtherSet: TStringList; AOutput: TStringList);

Var 
  i : integer;
Begin
  For i := 0 To Pred(ASet.Count) Do
    If AOtherSet.IndexOf(ASet[i]) = -1 Then
      AOutput.Add(ASet[i]);
End;


// TODO: natively implemented in 4.1.4
Procedure StringListIntersection(ASet: TStringList; AOtherSet: TStringList; AOutput: TStringList);

Var 
  i : integer;
Begin
  For i := 0 To Pred(ASet.Count) Do
    If AOtherSet.IndexOf(ASet[i]) > -1 Then
      AOutput.Add(ASet[i]);
End;


// Treats a serialized edit-value string as an "empty key" ONLY when it looks
// like a flag-array bit string (exclusively '0' and '1' chars) and contains
// no set bits. This is the original optimization's actual intent: allow
// CompareKeys to bail out cheaply when both sides are all-zero flag masks.
//
// The earlier implementation returned True whenever the string had no literal
// '1' char anywhere, which false-positives on any non-flag edit value that
// happens to lack the digit '1' -- e.g. FormID hex like "00039F26", EditorIDs
// like "CRFThalmorHQFaction", or the integer "0". That silently suppressed
// real differences and caused false-negative tag suggestions (e.g. C.Owner on
// cutting room floor.esp cell 00071FFE, where both the master XOWN reference
// and the overriding one had edit values containing no '1' digit).
Function IsEmptyKey(AEditValues: String): boolean;

Var
  i : integer;
Begin
  Result := False;

  // Empty string: nothing to compare; treat as NOT an empty-key sentinel so
  // the caller falls through to its own SameText check (SameText('','')=True
  // will handle the truly-identical-empty case correctly).
  If Length(AEditValues) = 0 Then
    Exit;

  // Non-flag-array content disqualifies the fast path.
  For i := 1 To Length(AEditValues) Do
    If (AEditValues[i] <> '0') And (AEditValues[i] <> '1') Then
      Exit;

  // All-'0'/'1' now. Any '1' means at least one bit set -> not empty.
  For i := 1 To Length(AEditValues) Do
    If AEditValues[i] = '1' Then
      Exit;

  Result := True;
End;


// Render a tag list for the Messages tab. Zero tags yields ANull verbatim;
// non-empty yields "<count> <label>\r\n      {{BASH:tag1, tag2, ...}}" with
// ASingular/APlural selected by count.
Function FormatTags(ATags: TStringList; ASingular: String; APlural: String; ANull: String): string;
Var
  sLabel : string;
Begin
  If ATags.Count = 0 Then
    Begin
      Result := ANull;
      Exit;
    End;

  If ATags.Count = 1 Then
    sLabel := ASingular
  Else
    sLabel := APlural;

  Result := IntToStr(ATags.Count) + ' ' + sLabel + #13#10 + StringOfChar(' ', 6)
            + Format(' {{BASH:%s}}', [ATags.DelimitedText]);
End;


Function TagExists(ATag: String): boolean;
Begin
  Result := (slSuggestedTags.IndexOf(ATag) <> -1);
End;

Function AddLogEntry(ATestName: String; AElement: IwbElement; AMaster: IwbElement): string;

Var 
  mr    : IwbMainRecord;
  sName : string;
  sPath : string;
  sWhy  : string;
Begin
  If Not g_LogTests And Not g_ShowTagRelationships Then
    Exit;

  If Assigned(AMaster) Then
    Begin
      mr    := ContainingMainRecord(AMaster);
      sPath := Path(AMaster);
    End
  Else
    Begin
      mr    := ContainingMainRecord(AElement);
      sPath := Path(AElement);
    End;

  // Path() returns strings shaped like '[NN] <rest of path>'. The fixed 5-char
  // prefix ('[NN] ' — two-digit index, two brackets, trailing space) is strip-
  // ped so log lines show just the meaningful path suffix.
  sPath := RightStr(sPath, Length(sPath) - 5);

  sName := Format('[%s:%s]', [Signature(mr), IntToHex(GetLoadOrderFormID(mr), 8)]);

  If g_LogTests Then
    slLog.Add(Format('{%s} (%s) %s %s', [g_Tag, ATestName, sName, sPath]));

  If g_ShowTagRelationships Then
    Begin
      sWhy := FriendlyRelationshipWhy(ATestName);
      slTagRelationships.Add(Format('Tag suggestion %s based on %s at %s %s', [g_Tag, sWhy, sName, sPath]));
    End;
End;
