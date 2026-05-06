{ chunk: specialty handlers -- ProcessRaceSpells, ProcessDelevRelevTags, ProcessForceTagHeuristics, DiffSubrecordList, CollectArrayEntryIDs, CountSetMinus, FriendlyRelationshipWhy }

// Oblivion RACE Spells split (replaces single R.ChangeSpells emission).
//   removes > 0  -> R.ChangeSpells  (full override needed to drop SPELs)
//   adds-only    -> R.AddSpells     (additive merge sufficient)
//   identical    -> nothing
// Preserves v1.0 detection coverage; improves accuracy in the adds-only case.
Procedure ProcessRaceSpells(ARecord: IwbMainRecord; AMaster: IwbMainRecord);

Var 
  kSpells, kSpellsMaster : IwbElement;
  slOver, slMast         : TStringList;
  iAdds, iRemoves        : integer;
Begin
  If TagExists('R.AddSpells') And TagExists('R.ChangeSpells') Then
    Exit;

  kSpells       := ElementByPath(ARecord, ActorSpellArrayPath);
  kSpellsMaster := ElementByPath(AMaster,  ActorSpellArrayPath);

  // Both missing: nothing to suggest. Either-side missing: defer to general path-based check below.
  If Not Assigned(kSpells) And Not Assigned(kSpellsMaster) Then
    Exit;

  slOver := MakeTagSet;
  slMast := MakeTagSet;
  Try
    CollectArrayEntryIDs(kSpells,       slOver);
    CollectArrayEntryIDs(kSpellsMaster, slMast);

    iAdds    := CountSetMinus(slOver, slMast);
    iRemoves := CountSetMinus(slMast, slOver);

    If iRemoves > 0 Then
      Begin
        g_Tag := 'R.ChangeSpells';
        If Not TagExists(g_Tag) Then
          Begin
            AddLogEntry('RaceSpells:Removes', kSpells, kSpellsMaster);
            slSuggestedTags.Add(g_Tag);
          End;
      End
    Else If iAdds > 0 Then
           Begin
             g_Tag := 'R.AddSpells';
             If Not TagExists(g_Tag) Then
               Begin
                 AddLogEntry('RaceSpells:AddOnly', kSpells, kSpellsMaster);
                 slSuggestedTags.Add(g_Tag);
               End;
           End;
  Finally
    slOver.Free;
    slMast.Free;
  End;
End;


Procedure ProcessDelevRelevTags(ARecord: IwbMainRecord; AMaster: IwbMainRecord);

Var
  kEntries          : IwbElement;
  kEntriesMaster    : IwbElement;
  kEntry            : IwbElement;
  kEntryMaster      : IwbElement;
  kCOED             : IwbElement;
  // extra data
  kCOEDMaster       : IwbElement;
  // extra data
  sSignature        : string;
  sEditValues       : string;
  sMasterEditValues : string;
  i                 : integer;
  j                 : integer;
  bDelevApplies     : boolean;
Begin
  // nothing to do if already tagged
  If TagExists('Delev') And TagExists('Relev') Then
    Exit;

  // get Leveled List Entries
  kEntries       := ElementByName(ARecord, 'Leveled List Entries');
  kEntriesMaster := ElementByName(AMaster, 'Leveled List Entries');

  If Not Assigned(kEntries) Then
    Exit;

  If Not Assigned(kEntriesMaster) Then
    Exit;

  // initalize count matched on reference entries
  j := 0;

  If Not TagExists('Relev') Then
    Begin
      g_Tag := 'Relev';

      For i := 0 To Pred(ElementCount(kEntries)) Do
        Begin
          kEntry := ElementByIndex(kEntries, i);
          kEntryMaster := SortedArrayElementByValue(kEntriesMaster, 'LVLO\Reference', GetElementEditValues(kEntry, 'LVLO\Reference'));

          If Not Assigned(kEntryMaster) Then
            Continue;

          Inc(j);

          If TagExists(g_Tag) Then
            Continue;

          If CompareNativeValues(kEntry, kEntryMaster, 'LVLO\Level') Then
            Exit;

          If CompareNativeValues(kEntry, kEntryMaster, 'LVLO\Count') Then
            Exit;

          If wbIsOblivion Then
            Continue;

          // Relev check for changed level, count, extra data
          kCOED       := ElementBySignature(kEntry, 'COED');
          kCOEDMaster := ElementBySignature(kEntryMaster, 'COED');

          sEditValues       := EditValues(kCOED);
          sMasterEditValues := EditValues(kCOEDMaster);

          If Not SameText(sEditValues, sMasterEditValues) Then
            Begin
              AddLogEntry('Assigned', kCOED, kCOEDMaster);
              slSuggestedTags.Add(g_Tag);
              Exit;
            End;
        End;
    End;

  If Not TagExists('Delev') Then
    Begin
      g_Tag := 'Delev';

      sSignature := Signature(ARecord);

      // Per-signature game applicability for the Delev tag.
      // LVLI: all supported games. LVLC: Oblivion/FO3/FNV. LVLN: non-Oblivion.
      // LVSP: Oblivion/Skyrim/FO4. Anything else: not applicable.
      If sSignature = 'LVLI' Then
        bDelevApplies := True
      Else If sSignature = 'LVLC' Then
             bDelevApplies := wbIsOblivion Or wbIsFallout3 Or wbIsFalloutNV
      Else If sSignature = 'LVLN' Then
             bDelevApplies := Not wbIsOblivion
      Else If sSignature = 'LVSP' Then
             bDelevApplies := wbIsOblivion Or wbIsSkyrim Or wbIsFallout4
      Else
        bDelevApplies := False;

      // Fires if this signature supports Delev in the current game AND the
      // override's matched-entry count is strictly less than the master's
      // (i.e., the override drops entries the master had).
      If bDelevApplies And (j < ElementCount(kEntriesMaster)) Then
        Begin
          AddLogEntry('ElementCount', kEntries, kEntriesMaster);
          slSuggestedTags.Add(g_Tag);
          Exit;
        End;
    End;
End;

// Opt-in heuristic: suggest WB Force* variants when simple diff patterns fire.
// Documented false positives; gated by g_HeuristicForceTags.
Procedure ProcessForceTagHeuristics(ARecord: IwbMainRecord; AMaster: IwbMainRecord);

Var 
  sSig                       : string;
  kArr, kArrMaster           : IwbElement;
  slOver, slMast             : TStringList;
  iAdds, iRemoves            : integer;
  bSpells, bAI               : boolean;
  bEyes, bHair, bFace        : boolean;
  kE, kEM, kH, kHM, kF, kFM  : IwbElement;
Begin
  If Not g_HeuristicForceTags Then
    Exit;

  sSig := Signature(ARecord);

  // Actors.SpellsForceAdd: superset on the SPLO array, only if Actors.Spells already suggested.
  bSpells := (sSig = 'CREA') Or (sSig = 'NPC_');
  If bSpells And TagExists('Actors.Spells') And Not TagExists('Actors.SpellsForceAdd') Then
    Begin
      kArr       := ElementByPath(ARecord, ActorSpellArrayPath);
      kArrMaster := ElementByPath(AMaster,  ActorSpellArrayPath);

      slOver := MakeTagSet;
      slMast := MakeTagSet;
      Try
        CollectArrayEntryIDs(kArr,       slOver);
        CollectArrayEntryIDs(kArrMaster, slMast);
        iAdds    := CountSetMinus(slOver, slMast);
        iRemoves := CountSetMinus(slMast, slOver);
        If (iAdds > 0) And (iRemoves = 0) Then
          Begin
            g_Tag := 'Actors.SpellsForceAdd';
            AddLogEntry('Heuristic:ForceAddSuperset', kArr, kArrMaster);
            slSuggestedTags.Add(g_Tag);
          End;
      Finally
        slOver.Free;
        slMast.Free;
      End;
    End;

  // Actors.AIPackagesForceAdd: superset on Packages, only if Actors.AIPackages already suggested.
  bAI := (sSig = 'CREA') Or (sSig = 'NPC_');
  If bAI And TagExists('Actors.AIPackages') And Not TagExists('Actors.AIPackagesForceAdd') Then
    Begin
      kArr       := ElementByPath(ARecord, 'Packages');
      kArrMaster := ElementByPath(AMaster,  'Packages');

      slOver := MakeTagSet;
      slMast := MakeTagSet;
      Try
        CollectArrayEntryIDs(kArr,       slOver);
        CollectArrayEntryIDs(kArrMaster, slMast);
        iAdds    := CountSetMinus(slOver, slMast);
        iRemoves := CountSetMinus(slMast, slOver);
        If (iAdds > 0) And (iRemoves = 0) Then
          Begin
            g_Tag := 'Actors.AIPackagesForceAdd';
            AddLogEntry('Heuristic:ForceAddSuperset', kArr, kArrMaster);
            slSuggestedTags.Add(g_Tag);
          End;
      Finally
        slOver.Free;
        slMast.Free;
      End;
    End;

  // NpcFacesForceFullImport: NPC_ on non-FO4, all of eyes (ENAM), hair (HNAM),
  // and face geometry (FaceGen Data) differ from master simultaneously.
  If (sSig = 'NPC_') And Not wbIsFallout4 And Not TagExists('NpcFacesForceFullImport') Then
    Begin
      kE  := ElementBySignature(ARecord, 'ENAM');
      kEM := ElementBySignature(AMaster, 'ENAM');
      kH  := ElementBySignature(ARecord, 'HNAM');
      kHM := ElementBySignature(AMaster, 'HNAM');
      kF  := ElementByPath(ARecord, 'FaceGen Data');
      kFM := ElementByPath(AMaster,  'FaceGen Data');

      bEyes := Assigned(kE) And Assigned(kEM) And (GetNativeValue(kE) <> GetNativeValue(kEM));
      bHair := Assigned(kH) And Assigned(kHM) And (GetNativeValue(kH) <> GetNativeValue(kHM));
      bFace := Assigned(kF) And Assigned(kFM) And Not SameText(EditValues(kF), EditValues(kFM));

      If bEyes And bHair And bFace Then
        Begin
          g_Tag := 'NpcFacesForceFullImport';
          AddLogEntry('Heuristic:FullFaceDiff', kF, kFM);
          slSuggestedTags.Add(g_Tag);
        End;
    End;
End;

// Collect the EditValue (FormID hex) of each child entry in an array element into sl (sorted, unique).
Procedure CollectArrayEntryIDs(AArray: IwbElement; sl: TStringList);

Var 
  i      : integer;
  kEntry : IwbElement;
  s      : string;
Begin
  If Not Assigned(AArray) Then
    Exit;
  For i := 0 To Pred(ElementCount(AArray)) Do
    Begin
      kEntry := ElementByIndex(AArray, i);
      s := Trim(GetEditValue(kEntry));
      If s <> '' Then
        sl.Add(s);
    End;
End;


// Set diff: items in A not in B
Function CountSetMinus(A: TStringList; B: TStringList): integer;

Var 
  i, n : integer;
Begin
  n := 0;
  For i := 0 To Pred(A.Count) Do
    If B.IndexOf(A[i]) = -1 Then
      Inc(n);
  Result := n;
End;


// Per-entry change diff for sorted/keyed sub-record lists (Items, Relations, etc.).
// Emits ATagName iff at least one entry whose key (ARefPath) is present in BOTH master
// and override has differing data on any of ADataPathsDelim (pipe-separated paths).
//
// Entries that exist only in override (Add) or only in master (Remove) are intentionally
// ignored here — those are handled by *.Add and *.Remove tags. This is the fix for the
// historical false positive where CompareKeys on the whole array would fire whenever
// items were added or removed, regardless of whether any shared entry actually changed.
Procedure DiffSubrecordList(ARec: IInterface; AMaster: IInterface;
                             Const ATagName: String; Const AArrayName: String;
                             Const ARefPath: String; Const ADataPathsDelim: String);

Var 
  kArr, kArrM         : IwbElement;
  kEntry, kMatch      : IwbElement;
  kSubA, kSubB        : IwbElement;
  slDataPaths         : TStringList;
  i, j, k             : integer;
  sRef, sRefM         : string;
  sData, sDataM       : string;
Begin
  DbgLog(DBG_PER_COMPARE, Format('DiffSubrecordList: tag=%s array=%s ref=%s data=%s', [ATagName, AArrayName, ARefPath, ADataPathsDelim]));

  If TagExists(ATagName) Then
    Begin
      DbgLog(DBG_PER_COMPARE, '  -> SKIP (tag already suggested earlier)');
      Exit;
    End;

  kArr  := ElementByName(ARec,    AArrayName);
  kArrM := ElementByName(AMaster, AArrayName);
  If Not Assigned(kArr) Or Not Assigned(kArrM) Then
    Begin
      DbgLog(DBG_PER_COMPARE, Format('  -> NO-OP (array "%s" missing on %s)', [AArrayName, IfThen(Not Assigned(kArr), 'override', 'master')]));
      Exit;
    End;
  If (ElementCount(kArr) = 0) Or (ElementCount(kArrM) = 0) Then
    Begin
      DbgLog(DBG_PER_COMPARE, Format('  -> NO-OP (one side empty: e=%s m=%s)', [IntToStr(ElementCount(kArr)), IntToStr(ElementCount(kArrM))]));
      Exit;
    End;

  slDataPaths := TStringList.Create;
  Try
    slDataPaths.Delimiter     := '|';
    slDataPaths.StrictDelimiter := True;
    slDataPaths.DelimitedText := ADataPathsDelim;

    For i := 0 To Pred(ElementCount(kArr)) Do
      Begin
        kEntry := ElementByIndex(kArr, i);
        sRef   := GetElementEditValues(kEntry, ARefPath);
        If sRef = '' Then
          Begin
            DbgLog(DBG_PER_COMPARE, Format('  entry[%s]: no ref value at "%s" -> skip', [IntToStr(i), ARefPath]));
            Continue;
          End;

        // Find the matching entry in master by ref (linear scan; lists are small).
        kMatch := Nil;
        For j := 0 To Pred(ElementCount(kArrM)) Do
          Begin
            sRefM := GetElementEditValues(ElementByIndex(kArrM, j), ARefPath);
            If SameText(sRefM, sRef) Then
              Begin
                kMatch := ElementByIndex(kArrM, j);
                Break;
              End;
          End;

        // Ref only in override = Add (handled by *.Add tag); skip.
        If Not Assigned(kMatch) Then
          Begin
            DbgLog(DBG_PER_COMPARE, Format('  entry[%s] ref="%s" -> add-only (no master match), skip', [IntToStr(i), sRef]));
            Continue;
          End;

        // Compare each requested data path. First difference wins and emits the tag.
        For k := 0 To Pred(slDataPaths.Count) Do
          Begin
            kSubA := ElementByPath(kEntry, slDataPaths[k]);
            kSubB := ElementByPath(kMatch, slDataPaths[k]);

            // Both missing on this path: nothing to compare.
            If Not Assigned(kSubA) And Not Assigned(kSubB) Then
              Continue;

            sData  := '';
            sDataM := '';
            If Assigned(kSubA) Then sData  := EditValues(kSubA);
            If Assigned(kSubB) Then sDataM := EditValues(kSubB);

            If Not SameText(sData, sDataM) Then
              Begin
                g_Tag := ATagName;
                AddLogEntry('SubrecordChange', kEntry, kMatch);
                slSuggestedTags.Add(g_Tag);
                
                DbgLog(DBG_PER_COMPARE, Format('  entry[%s] ref="%s" data-path="%s" DIFFERS -> SUGGEST %s',
                  [IntToStr(i), sRef, slDataPaths[k], ATagName]));
                DbgLog(DBG_LEAF_DIFFS, Format('       override="%s"  master="%s"',
                  [DbgShortVal(sData), DbgShortVal(sDataM)]));

                Exit;
              End;
          End;
      End;
    DbgLog(DBG_PER_COMPARE, '  -> NO-OP (all shared entries had identical data on requested paths)');
  Finally
    slDataPaths.Free;
  End;
End;

Function FriendlyRelationshipWhy(Const ATestName: String): String;
Begin
  If SameText(ATestName, 'Assigned') Then
    Result := 'a subrecord is present on one side of the conflict but missing on the other'
  Else If SameText(ATestName, 'ElementCount') Then
         Result := 'the winning override has a different number of child elements than the master'
  Else If SameText(ATestName, 'ElementCountAdd') Then
         Result := 'the winning override adds child elements relative to the master'
  Else If SameText(ATestName, 'ElementCountRemove') Then
         Result := 'the winning override removes child elements relative to the master'
  Else If SameText(ATestName, 'GetEditValue') Then
         Result := 'the displayed field value differs from the master'
  Else If SameText(ATestName, 'CompareKeys') Then
         Result := 'sorted key contents differ from the master'
  Else If SameText(ATestName, 'SubrecordChange') Then
         Result := 'a list entry the master also has was modified (same reference, different data)'
  Else If SameText(ATestName, 'CompareNativeValues') Then
         Result := 'raw binary/native field values differ from the master'
  Else If SameText(ATestName, 'CompareFlags:NOT') Then
         Result := 'a flag value differs from the master'
  Else If SameText(ATestName, 'CompareFlags:OR') Then
         Result := 'a flag is set on the override or master (OR rule)'
  Else If SameText(ATestName, 'RaceSpells:AddOnly') Then
         Result := 'override Spells adds new SPELs and removes none (additive merge)'
  Else If SameText(ATestName, 'RaceSpells:Removes') Then
         Result := 'override Spells removes SPELs the master had (full override required)'
  Else If SameText(ATestName, 'Heuristic:ForceAddSuperset') Then
         Result := 'heuristic: override list is a strict superset of master (no removals); WB ForceAdd may apply'
  Else If SameText(ATestName, 'Heuristic:FullFaceDiff') Then
         Result := 'heuristic: NPC eyes, hair, and face geometry all differ from master; WB full face import may apply'
  Else
    Result := 'detection rule fired (' + ATestName + ')';
End;
