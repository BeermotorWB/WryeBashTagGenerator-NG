{ chunk: utilities -- wbIsX game probes, MakeTagSet, LogInfo/Warn/Error, StrToBool, RegExMatchGroup, RegExReplace, ActorSpellArrayPath }

// Oblivion (vanilla and Remastered). Detection logic treats both identically,
// so this is the predicate to use anywhere Oblivion-specific behavior applies.
// Use wbIsOblivionR only when a branch needs to distinguish Remastered from
// vanilla (currently only the game-mode log line in Initialize).

Function wbIsOblivion: boolean;
Begin
  Result := (wbGameMode = gmTES4) or (wbGameMode = gmTES4R);
End;


Function wbIsOblivionR: boolean;
Begin
  Result := wbGameMode = gmTES4R;
End;


Function wbIsSkyrim: boolean;
Begin
  Result := (wbGameMode = gmTES5) Or (wbGameMode = gmEnderal) Or (wbGameMode = gmSSE) Or (wbGameMode = gmTES5VR) Or (wbGameMode = gmEnderalSE);
End;


Function wbIsSkyrimSE: boolean;
Begin
  Result := (wbGameMode = gmSSE) Or (wbGameMode = gmTES5VR) Or (wbGameMode = gmEnderalSE);
End;


Function wbIsFallout3: boolean;
Begin
  Result := wbGameMode = gmFO3;
End;


Function wbIsFalloutNV: boolean;
Begin
  Result := wbGameMode = gmFNV;
End;


Function wbIsFallout4: boolean;
Begin
  Result := (wbGameMode = gmFO4) Or (wbGameMode = gmFO4VR);
End;


Function wbIsFallout76: boolean;
Begin
  Result := wbGameMode = gmFO76;
End;


Function wbIsEnderal: boolean;
Begin
  Result := wbGameMode = gmEnderal;
End;


Function wbIsEnderalSE: boolean;
Begin
  Result := wbGameMode = gmEnderalSE;
End;


Procedure LogInfo(AText: String);
Begin
  AddMessage('[INFO] ' + AText);
End;


Procedure LogWarn(AText: String);
Begin
  AddMessage('[WARN] ' + AText);
End;


Procedure LogError(AText: String);
Begin
  AddMessage('[ERRO] ' + AText);
End;

// Path to the SPLO array on NPC_/CREA and RACE records. Oblivion calls it
// 'Spells'; every other supported game calls it 'Actor Effects'.
Function ActorSpellArrayPath: string;
Begin
  If wbIsOblivion Then
    Result := 'Spells'
  Else
    Result := 'Actor Effects';
End;

// Create a pre-configured TStringList suitable for tag-set operations:
// sorted, case-insensitive, duplicates ignored. Used for the many short-lived
// set-style lists this script builds (normalized tag sets, diffs, FormID sets).
Function MakeTagSet: TStringList;
Begin
  Result := TStringList.Create;
  Result.Sorted        := True;
  Result.Duplicates    := dupIgnore;
  Result.CaseSensitive := False;
End;

Function StrToBool(AValue: String): boolean;
Begin
  If (AValue <> '0') And (AValue <> '1') Then
    Result := False
  Else
    Result := (AValue = '1');
End;

Function RegExMatchGroup(AExpr: String; ASubj: String; AGroup: integer): string;
Var 
  re     : TPerlRegEx;
Begin
  Result := '';
  re := TPerlRegEx.Create;
  Try
    re.RegEx := AExpr;
    re.Options := [];
    re.Subject := ASubj;
    If re.Match Then
      Result := re.Groups[AGroup];
  Finally
    re.Free;
  End;
End;


Function RegExReplace(Const AExpr: String; ARepl: String; ASubj: String): string;
Var 
  re      : TPerlRegEx;
  sResult : string;
Begin
  Result := '';
  re := TPerlRegEx.Create;
  Try
    re.RegEx := AExpr;
    re.Options := [];
    re.Subject := ASubj;
    re.Replacement := ARepl;
    re.ReplaceAll;
    sResult := re.Subject;
  Finally
    re.Free;
    Result := sResult;
  End;
End;

// ===========================================================================
// Debug-fork instrumentation
// ===========================================================================
// Shared across variants. In SINGLE/MULTI, DebugLevel = DBG_OFF (chunk 01)
// makes DbgLog/DbgLogUnfiltered exit before doing anything; g_DebugLogReady
// is never set True so DbgWriteRaw also no-ops. Callers in chunks 06-10 can
// invoke DbgLog unconditionally; the cost in production is one constant
// comparison plus the Format/DbgPath/DbgEdv argument-building done at the
// callsite (the helpers themselves don't touch the log unless DEBUG is the
// active variant).

Function DbgRecordTag: string;
Var
  sFid : string;
  sEid : string;
  sSig : string;
  sFil : string;
Begin
  If Not Assigned(g_DebugCurrentRecord) Then
    Begin
      Result := '[<no-record>]';
      Exit;
    End;
  sSig := Signature(g_DebugCurrentRecord);
  sFid := IntToHex(GetLoadOrderFormID(g_DebugCurrentRecord), 8);
  sEid := EditorID(g_DebugCurrentRecord);
  sFil := GetFileName(GetFile(g_DebugCurrentRecord));
  If sEid = '' Then
    Result := Format('[%s:%s @ %s]', [sSig, sFid, sFil])
  Else
    Result := Format('[%s:%s "%s" @ %s]', [sSig, sFid, sEid, sFil]);
End;


Function DbgFiltered: boolean;
Var
  sFid : string;
Begin
  Result := False;
  If DebugFilterTag <> '' Then
    If Not SameText(g_DebugCurrentTag, DebugFilterTag) Then
      Begin Result := True; Exit; End;
  If DebugFilterForm <> '' Then
    Begin
      If Not Assigned(g_DebugCurrentRecord) Then
        Begin Result := True; Exit; End;
      sFid := IntToHex(GetLoadOrderFormID(g_DebugCurrentRecord), 8);
      If Not SameText(sFid, DebugFilterForm) Then
        Result := True;
    End;
End;


Procedure DbgWriteRaw(Const s: string);
Var
  sIndent : string;
  i       : integer;
Begin
  If Not g_DebugLogReady Then Exit;
  sIndent := '';
  For i := 1 To g_DebugIndent Do
    sIndent := sIndent + '  ';
  Try
    g_DebugLog.Add(sIndent + s);
  Except
    // Swallow buffer errors - debug-only path, never abort the script.
  End;
End;


Procedure DbgLog(ALevel: integer; Const s: string);
Begin
  If DebugLevel < ALevel Then Exit;
  If DbgFiltered Then Exit;
  DbgWriteRaw(s);
End;


Procedure DbgLogUnfiltered(ALevel: integer; Const s: string);
// Bypasses tag/form filter; used for record + file headers so the log
// is still readable when filters are active.
Begin
  If DebugLevel < ALevel Then Exit;
  DbgWriteRaw(s);
End;


Function DbgShortVal(Const s: string): string;
// Edit values can be very long (e.g. full Items array dumps). Trim for log.
Begin
  If Length(s) > 200 Then
    Result := Copy(s, 1, 197) + '...'
  Else
    Result := s;
End;


Function DbgEdv(AElement: IInterface): string;
// Safe GetEditValue for nil-tolerant logging.
Begin
  If Not Assigned(AElement) Then
    Result := '<nil>'
  Else
    Result := DbgShortVal(GetEditValue(AElement));
End;


Function DbgPath(AElement: IInterface): string;
// Path relative to the containing record (xEdit's Path() is full).
Var
  s : string;
Begin
  If Not Assigned(AElement) Then
    Begin Result := '<nil>'; Exit; End;
  s := Path(AElement);
  // Path() typically starts with the record signature; strip it for brevity.
  If Length(s) > 5 Then
    Result := Copy(s, 6, Length(s))
  Else
    Result := s;
End;


Procedure DbgSuggestSnapshot;
Begin
  g_DebugSuggestedSnap := slSuggestedTags.Count;
End;


Function DbgWasSuggested: boolean;
Begin
  Result := slSuggestedTags.Count > g_DebugSuggestedSnap;
End;


Function DbgConflictName(AState: TConflictThis): string;
Begin
  Case AState Of
    caUnknown          : Result := 'caUnknown';
    caOnlyOne          : Result := 'caOnlyOne';
    caNoConflict       : Result := 'caNoConflict';
    caConflictBenign   : Result := 'caConflictBenign';
    caOverride         : Result := 'caOverride';
    caConflict         : Result := 'caConflict';
    caConflictCritical : Result := 'caConflictCritical';
  Else
    Result := 'caState_' + IntToStr(Ord(AState));
  End;
End;

{#IF MULTI}
// True iff AFileName is a stock “base game” master file for the current game.
// Multi mode compares each plugin against stock masters only, to avoid treating
// other selected mods as context (this is a batch convenience tool, not a load
// order reconciliation pass).
Function IsStockMasterFile(Const AFileName: string): boolean;
Begin
  Result := False;

  // TES5 / SSE / Enderal
  If wbIsSkyrim Then
    Begin
      Result :=
        SameText(AFileName, 'Skyrim.esm')
        Or SameText(AFileName, 'Update.esm')
        Or SameText(AFileName, 'Dawnguard.esm')
        Or SameText(AFileName, 'HearthFires.esm')
        Or SameText(AFileName, 'Dragonborn.esm');
      Exit;
    End;

  // TES4 / TES4R
  If wbIsOblivion Then
    Begin
      Result := SameText(AFileName, 'Oblivion.esm');
      Exit;
    End;

  // FO3 / FNV
  If wbIsFallout3 Then
    Begin
      Result := SameText(AFileName, 'Fallout3.esm');
      Exit;
    End;
  If wbIsFalloutNV Then
    Begin
      Result := SameText(AFileName, 'FalloutNV.esm');
      Exit;
    End;

  // FO4
  If wbIsFallout4 Then
    Begin
      Result :=
        SameText(AFileName, 'Fallout4.esm')
        Or SameText(AFileName, 'DLCRobot.esm')
        Or SameText(AFileName, 'DLCworkshop01.esm')
        Or SameText(AFileName, 'DLCCoast.esm')
        Or SameText(AFileName, 'DLCworkshop02.esm')
        Or SameText(AFileName, 'DLCworkshop03.esm')
        Or SameText(AFileName, 'DLCNukaWorld.esm');
      Exit;
    End;
End;
{#ENDIF}
