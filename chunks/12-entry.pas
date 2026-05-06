{ chunk: xEdit entry points -- Initialize, Process, Finalize }

Function Initialize: integer;
Begin
  ClearMessages();

  LogInfo('--------------------------------------------------------------------------------');
  LogInfo(ScriptName + ' v' + ScriptVersion + ' by ' + ScriptAuthor + ' <' + ScriptEmail + '>');
{#IF DEBUG}
  LogInfo('READ-ONLY DEBUG FORK - this script never writes to plugin headers.');
{#ENDIF}
  LogInfo('--------------------------------------------------------------------------------');
  LogInfo(DataPath);

{#IF DEBUG}
// ---- Open the debug trace buffer ------------------------------------
  // xEdit's PascalScript (JvInterpreter) does not register TextFile,
  // AssignFile, Rewrite, WriteLn, Flush or CloseFile. The only practical
  // way to write text to disk from a script is TStringList.SaveToFile.
  // We therefore buffer all trace lines in g_DebugLog and flush via
  // SaveToFile (once per file in Process(), and again in Finalize).
  g_DebugLogPath   := ProgramPath + 'Edit Scripts\WryeBashTagGenerator-NG-debug.log';
  g_DebugLogReady  := False;
  g_DebugIndent    := 0;

  // Tell the user up-front exactly where we will (try to) write, so they
  // can find it even if Finalize never runs (script abort, exception, etc).
  AddMessage('');
  AddMessage('================================================================================');
  AddMessage('Debug trace target:');
  AddMessage('  ' + g_DebugLogPath);
  AddMessage('================================================================================');

  Try
    // Plain TStringList (not MakeTagSet) — trace lines must keep insertion
    // order, and identical SKIP messages from different records must NOT
    // dedupe.
    g_DebugLog := TStringList.Create;
    g_DebugLog.Add('# ' + ScriptName + ' v' + ScriptVersion);
    g_DebugLog.Add('# Generated: ' + DateTimeToStr(Now));
    g_DebugLog.Add('# DebugLevel=' + IntToStr(DebugLevel) +
                   '  FilterForm="' + DebugFilterForm + '"' +
                   '  FilterTag="'  + DebugFilterTag  + '"');
    g_DebugLog.Add('');
    // Probe write to surface permission errors NOW, not at the end of a
    // 30-minute run. SaveToFile will raise if the path is unwritable.
    g_DebugLog.SaveToFile(g_DebugLogPath);
    g_DebugLogReady := True;
    LogInfo('Debug trace OPEN: ' + g_DebugLogPath);
  Except
    on E: Exception Do
      Begin
        LogWarn('Could not initialize debug log buffer: ' +
                g_DebugLogPath + ' [' + E.ClassName + ': ' + E.Message +
                '] (continuing without trace)');
        g_DebugLogReady := False;
      End;
  End;

  // Read-only enforcement: g_AddTags AND g_AddFile are forced False here,
  // both prompt checkboxes are disabled in ShowPrompt, the only SetEditValue()
  // call in Process() is gated behind 'If False And bWriteHeader Then', and
  // the BashTags-file write block is replaced by a defensive LogWarn.
{#ENDIF}

  g_AddTags  := False;
  g_AddFile  := False;
{#IF MULTI}
  // Multi defaults: keep log size down; deep logging belongs in -debug.
  g_LogTests             := False;
  g_ShowTagRelationships := False;
{#ELSEIF SINGLE,DEBUG}
  g_LogTests             := True;
  g_ShowTagRelationships := True;
{#ENDIF}
  g_HeuristicForceTags   := False;

  slLog := TStringList.Create;
  slLog.Sorted     := False;
  slLog.Duplicates := dupAccept;

  slTagRelationships := TStringList.Create;
  slTagRelationships.Sorted     := False;
  slTagRelationships.Duplicates := dupAccept;

  slSuggestedTags := MakeTagSet;
  slSuggestedTags.Delimiter := ',';

  slExistingTags := TStringList.Create;
  slExistingTags.CaseSensitive := False;

  slDifferentTags := MakeTagSet;

  slBadTags := TStringList.Create;

  slDeprecatedTags := MakeTagSet;
  { Mirror Mopy/bash/bosh/__init__.py _removed_tags keys + _tag_aliases keys }
  slDeprecatedTags.CommaText :=
    'Actors.Perks.Add,Actors.Perks.Change,Actors.Perks.Remove,Body-F,Body-M,Body-Size-F,Body-Size-M,C.GridFlags,Derel,Eyes,Eyes-D,Eyes-E,Eyes-R,Factions,Hair,Invent,InventOnly,Merge,Npc.EyesOnly,Npc.HairOnly,NpcFaces,R.Relations,Relations,ScriptContents,Voice-F,Voice-M';

  // BashTags file read state
  slBashTagsFileAdds    := MakeTagSet;
  slBashTagsFileRemoves := MakeTagSet;

  slBashTagsFileLines := TStringList.Create;
  slBashTagsFileLines.Sorted     := False;
  slBashTagsFileLines.Duplicates := dupAccept;

  g_BashTagsFilePath   := '';
  g_BashTagsFileExists := False;

  g_AbortRun := False;

{#IF SINGLE,DEBUG}
  // Single-plugin lock
  g_TargetFile     := Nil;
  g_TargetFileName := '';
  g_MultiFileError := False;
  g_OtherFiles     := MakeTagSet;
{#ELSEIF MULTI}
  // No single-plugin lock in Multi mode.
{#ENDIF}

  If wbVersionNumber < MinXEditVer Then
    Begin
      LogWarn(Format('This script requires xEdit 4.1.4 or newer. Detected wbVersionNumber = $%s.',
                     [IntToHex(wbVersionNumber, 8)]));
      LogError('Cannot proceed because xEdit version is older than 4.1.4.');
      Result := 4;
      Exit;
    End;

  If ShowPrompt(ScriptName + ' v' + ScriptVersion) = mrAbort Then
    Begin
      LogError('Cannot proceed because user aborted execution');
      Result := 1;
      Exit;
    End;

  If wbIsFallout76 Then
    Begin
      LogError('Cannot proceed because CBash does not support Fallout 76');
      Result := 2;
      Exit;
    End;

  If wbIsFallout3 Then
    LogInfo('Using game mode: Fallout 3')
  Else If wbIsFalloutNV Then
         LogInfo('Using game mode: Fallout: New Vegas')
  Else If wbIsFallout4 Then
         LogInfo('Using game mode: Fallout 4')
  // wbIsOblivionR is more specific than wbIsOblivion (which also returns True
  // for TES4R), so it must be tested first or the Remastered branch is dead.
  Else If wbIsOblivionR Then
         LogInfo('Using game mode: Oblivion Remastered')
  Else If wbIsOblivion Then
         LogInfo('Using game mode: Oblivion')
  Else If wbIsEnderal Then
         LogInfo('Using game mode: Enderal')
  Else If wbIsEnderalSE Then
         LogInfo('Using game mode: Enderal Special Edition')
  Else If wbIsSkyrimSE Then
         LogInfo('Using game mode: Skyrim Special Edition')
  Else If wbIsSkyrim Then
         LogInfo('Using game mode: Skyrim')
  Else
    Begin
      LogError('Cannot proceed because script does not support game mode');
      Result := 3;
      Exit;
    End;

  ScriptProcessElements := [etFile];
End;


Function Process(input: IInterface): integer;
Var 
  kDescription : IwbElement;
  kHeader      : IwbElement;
  sDescription : string;
  sTags        : string;
  i            : integer;
  f            : IwbFile;
  slFinalTags   : TStringList;
  slNormExist   : TStringList;
  slWriteDelta  : TStringList;
  slDepFound    : TStringList;
  bWriteHeader : boolean;
  bHasWork     : boolean;
{#IF SINGLE,DEBUG}
  bDoFileWrite : boolean;
{#ENDIF}
Begin

  If (ElementType(input) = etMainRecord) Then
    exit;

{#IF MULTI}
f := GetFile(input);
{#ELSEIF SINGLE,DEBUG}
  f := GetFile(input);

  // Single-plugin enforcement: lock onto the first file we see.
  // Any additional distinct file flips an error flag; Finalize then aborts the run.
  If Not Assigned(g_TargetFile) Then
    Begin
      g_TargetFile     := f;
      g_TargetFileName := GetFileName(f);
    End
  Else If Not SameText(GetFileName(f), g_TargetFileName) Then
    Begin
      g_MultiFileError := True;
      If g_OtherFiles.IndexOf(GetFileName(f)) = -1 Then
        g_OtherFiles.Add(GetFileName(f));
      Exit;
    End;
{#ENDIF}
{#IF MULTI}
  // Honour prior user-requested abort: once the discrepancy dialog sets
  // g_AbortRun, every remaining per-file Process invocation returns immediately.
  If g_AbortRun Then
    Exit;
{#ENDIF}
  g_FileName := GetFileName(f);

{#IF MULTI}
  // Start-of-Process state reset. Each selected plugin is tagged independently;
  // pre-clearing here guarantees no leakage from a prior plugin even if that
  // plugin's Process exited early (exception, discrepancy skip, etc.) before the
  // end-of-Process clears ran.
  slLog.Clear;
  slTagRelationships.Clear;
  slSuggestedTags.Clear;
  slExistingTags.Clear;
  slDifferentTags.Clear;
  slBadTags.Clear;
  slBashTagsFileAdds.Clear;
  slBashTagsFileRemoves.Clear;
  slBashTagsFileLines.Clear;
  g_BashTagsFilePath   := '';
  g_BashTagsFileExists := False;
{#ENDIF}
{#IF SINGLE,MULTI}
LogInfo('=== ' + g_FileName + ' ===');
{#ELSEIF DEBUG}
  // Per-file banner in the debug trace.
  DbgLogUnfiltered(DBG_PER_TAG, '');
  DbgLogUnfiltered(DBG_PER_TAG, '================================================================================');
  DbgLogUnfiltered(DBG_PER_TAG, '== FILE: ' + g_FileName);
  DbgLogUnfiltered(DBG_PER_TAG, '================================================================================');
{#ENDIF}

  AddMessage(#10);

  LogInfo('Processing... ' + IntToStr(RecordCount(f)) + ' records. Please wait. This could take a while.');

  For i := 0 To Pred(RecordCount(f)) Do
    ProcessRecord(RecordByIndex(f, i));

  LogInfo('--------------------------------------------------------------------------------');
  LogInfo(g_FileName);
  LogInfo('-------------------------------------------------------------------------- TESTS');

  If g_LogTests Then
    For i := 0 To Pred(slLog.Count) Do
      LogInfo(slLog[i]);

  LogInfo('------------------------------------------------------------------------ RESULTS');

  slFinalTags  := MakeTagSet;
  slNormExist  := MakeTagSet;
  slWriteDelta := MakeTagSet;
  slDepFound   := TStringList.Create;
  Try
    kHeader := ElementBySignature(f, 'TES4');
    kDescription := ElementBySignature(kHeader, 'SNAM');
    If Assigned(kDescription) Then
      sDescription := GetEditValue(kDescription)
    Else
      sDescription := '';

    slExistingTags.Clear;
    slExistingTags.CommaText := RegExMatchGroup('{{BASH:(.*?)}}', sDescription, 1);
{#IF SINGLE,MULTI}
    g_BashTagsFilePath := DataPath + 'BashTags\' + ChangeFileExt(g_FileName, '.txt');
    ReadBashTagsFile(g_BashTagsFilePath);
{#ENDIF}
    slDepFound.Clear;
    StringListIntersection(slExistingTags, slDeprecatedTags, slDepFound);
    LogInfo(FormatTags(slDepFound, 'deprecated tag found:', 'deprecated tags found:', 'No deprecated tags found.'));

    slFinalTags.Clear;
    slFinalTags.AddStrings(slExistingTags);
    slFinalTags.AddStrings(slSuggestedTags);
    NormalizeBashTagsInPlace(slFinalTags);

    slNormExist.Clear;
    slNormExist.AddStrings(slExistingTags);
    NormalizeBashTagsInPlace(slNormExist);

    bHasWork := (slSuggestedTags.Count > 0) Or (slDepFound.Count > 0) Or g_AddFile;

    If Not bHasWork Then
      LogInfo('No tags are suggested for this plugin.')
    Else
      Begin
{#IF SINGLE,MULTI}
        bWriteHeader := g_AddTags;
{#ELSEIF DEBUG}
        bWriteHeader := False;  // READ-ONLY DEBUG FORK: header writes hard-disabled
{#ENDIF}
        If bWriteHeader And (slDepFound.Count > 0) Then
          If Not PromptDeprecatedHeaderUpdate Then
            Begin
              bWriteHeader := False;
              LogWarn('Deprecated Bash Tags present; user declined header update — description not modified.');
            End;

        slDifferentTags.Clear;
        StringListDifference(slSuggestedTags, slExistingTags, slDifferentTags);
        slBadTags.Clear;
        StringListDifference(slExistingTags, slSuggestedTags, slBadTags);

        // Deprecated tags are reported separately under "deprecated tags found:";
        // they are not "bad" (the user just hasn't migrated yet), so strip them out.
        If slDepFound.Count > 0 Then
          For i := Pred(slBadTags.Count) DownTo 0 Do
            If slDepFound.IndexOf(slBadTags[i]) <> -1 Then
              slBadTags.Delete(i);

        If (slSuggestedTags.Count = 0) And (slDepFound.Count = 0) And TagsCommaTextEqual(slFinalTags, slNormExist) And Not g_AddFile Then
          Begin
            LogInfo(FormatTags(slExistingTags,
              'existing tag found in header:',
              'existing tags found in header:',
              'No existing tags found in header.'));
            If g_BashTagsFileExists Then
              Begin
                LogInfo(FormatTags(slBashTagsFileAdds,
                  'existing tag found in BashTags file:',
                  'existing tags found in BashTags file:',
                  'No existing tags found in BashTags file.'));
                If slBashTagsFileRemoves.Count > 0 Then
                  LogInfo(FormatTags(slBashTagsFileRemoves,
                    'tag explicitly removed (-) in BashTags file:',
                    'tags explicitly removed (-) in BashTags file:',
                    ''));
              End
            Else
              LogInfo('No BashTags file found at: ' + g_BashTagsFilePath);
            LogInfo(FormatTags(slSuggestedTags, 'suggested tag:', 'suggested tags:', 'No suggested tags.'));
            LogWarn('No tags to add.' + #13#10);
          End
        Else
          Begin
{#IF SINGLE,MULTI}
            // Resolve BashTags-file prompts BEFORE the header write so the
            // discrepancy "No" path can also suppress the header rewrite.
            bDoFileWrite := False;
            If g_AddFile Then
              Begin
                bDoFileWrite := True;
                If g_BashTagsFileExists Then
                  Begin
                    If TagsCommaTextEqual(slFinalTags, slBashTagsFileAdds) Then
                      Begin
                        LogInfo('BashTags file already up to date; no changes to write.');
                        bDoFileWrite := False;
                      End
                    Else If HeaderBashTagsDiffer Then
                      Begin
{#IF MULTI}
                        // Multi mode: always ignore discrepancy and continue.
                        NotifyHeaderBashTagsDiscrepancy;
{#ELSEIF SINGLE}
                        If NotifyHeaderBashTagsDiscrepancy Then
                          Begin
                            g_AbortRun := True;
                            LogWarn('Header/BashTags discrepancy detected; user aborted run. No further plugins will be processed.');
                          End
                        Else
                          LogWarn('Header/BashTags discrepancy detected; skipping writes for this plugin. Continuing with remaining plugins.');
{#ENDIF}
                        bDoFileWrite := False;
                        bWriteHeader := False;
                      End
                    Else If Not PromptApproveBashTagsBackup Then
                      Begin
                        LogInfo('User discarded BashTags update; existing file left intact.');
                        bDoFileWrite := False;
                      End;
                  End;
              End;
{#ENDIF}
            If bWriteHeader Then
              Begin
                kDescription := ElementBySignature(kHeader, 'SNAM');
                If Not Assigned(kDescription) Then
                  kDescription := Add(kHeader, 'SNAM', True);

                sDescription := GetEditValue(kDescription);
                sTags        := Format('{{BASH:%s}}', [slFinalTags.DelimitedText]);

                If (Length(sDescription) = 0) And (slFinalTags.Count > 0) Then
                  sDescription := sTags
                Else If (Not TagsCommaTextEqual(slFinalTags, slNormExist)) Or (slDepFound.Count > 0) Then
                       Begin
                         If slExistingTags.Count = 0 Then
                           sDescription := sDescription + #10#10 + sTags
                         Else
                           sDescription := RegExReplace('{{BASH:.*?}}', sTags, sDescription);
                       End;
{#IF SINGLE,MULTI}
                SetEditValue(kDescription, sDescription);
{#ELSEIF DEBUG}
                // READ-ONLY DEBUG FORK: header write deliberately suppressed.
                LogWarn('READ-ONLY DEBUG FORK: header write suppressed (would have written: ' + sDescription + ')');
{#ENDIF}

                LogInfo(FormatTags(slBadTags,       'bad tag removed:',          'bad tags removed:',          'No bad tags found.'));
                LogInfo(FormatTags(slDifferentTags, 'tag added to file header:', 'tags added to file header:', 'No tags added.'));
              End
            Else
              Begin
                LogInfo(FormatTags(slBadTags,       'bad tag found:',         'bad tags found:',         'No bad tags found.'));
                LogInfo(FormatTags(slDifferentTags, 'suggested tag to add:',  'suggested tags to add:',  'No suggested tags to add.'));
              End;

            LogInfo(FormatTags(slExistingTags,
              'existing tag found in header:',
              'existing tags found in header:',
              'No existing tags found in header.'));
            If g_BashTagsFileExists Then
              Begin
                LogInfo(FormatTags(slBashTagsFileAdds,
                  'existing tag found in BashTags file:',
                  'existing tags found in BashTags file:',
                  'No existing tags found in BashTags file.'));
                If slBashTagsFileRemoves.Count > 0 Then
                  LogInfo(FormatTags(slBashTagsFileRemoves,
                    'tag explicitly removed (-) in BashTags file:',
                    'tags explicitly removed (-) in BashTags file:',
                    ''));
              End
            Else
              LogInfo('No BashTags file found at: ' + g_BashTagsFilePath);
            LogInfo(FormatTags(slFinalTags, 'suggested tag overall:', 'suggested tags overall:', 'No suggested tags overall.'));

            // Net-new and removed vs header / vs BashTags file. Use FormatTags so xEdit
            // Messages renders the {{BASH:...}} block the same way as other RESULTS lines.

            // Header adds: skip when delta == full final set (redundant — header was
            // empty, or only contained tokens that normalize away). Still log the
            // "No new tags..." message when delta is empty but final set is non-empty.
            slWriteDelta.Clear;
            StringListDifference(slFinalTags, slNormExist, slWriteDelta);
            If slWriteDelta.Count <> slFinalTags.Count Then
              LogInfo(FormatTags(slWriteDelta,
                'new tag to be added to header:',
                'new tags to be added to header:',
                'No new tags to add to header.'));

            // Header removals: literal tokens currently in {{BASH:...}} that will
            // not be present after rewrite (alias rename, TagIsRemoved drop, etc.).
            slWriteDelta.Clear;
            StringListDifference(slExistingTags, slFinalTags, slWriteDelta);
            LogInfo(FormatTags(slWriteDelta,
              'tag to be removed from header:',
              'tags to be removed from header:',
              'No tags to be removed from header.'));

            If g_BashTagsFileExists Then
              Begin
                // BashTags file adds.
                slWriteDelta.Clear;
                StringListDifference(slFinalTags, slBashTagsFileAdds, slWriteDelta);
                LogInfo(FormatTags(slWriteDelta,
                  'new tag to be added to BashTags file:',
                  'new tags to be added to BashTags file:',
                  'No new tags to add to BashTags file.'));

                // BashTags file removals: existing additive tags that vanish on overwrite.
                slWriteDelta.Clear;
                StringListDifference(slBashTagsFileAdds, slFinalTags, slWriteDelta);
                LogInfo(FormatTags(slWriteDelta,
                  'tag to be removed from BashTags file:',
                  'tags to be removed from BashTags file:',
                  'No tags to be removed from BashTags file.'));
              End;

            If g_ShowTagRelationships Then
              For i := 0 To Pred(slTagRelationships.Count) Do
                LogInfo(slTagRelationships[i]);
{#IF SINGLE,MULTI}
            If bDoFileWrite Then
              Begin
                WriteBashTagsFileWithBackup(g_BashTagsFilePath,
                                            slFinalTags.DelimitedText,
                                            slBashTagsFileLines,
                                            g_BashTagsFileExists);
                LogInfo('Finished writing bash tags to BashTags file (canonical names).');
              End;
{#ELSEIF DEBUG}
            // Read-only debug fork: never write a BashTags file.
            // The 'Write suggested tags to file' checkbox is disabled in
            // ShowPrompt and g_AddFile is forced False in Initialize, so
            // this branch is unreachable; the LogWarn is a defense-in-depth
            // canary in case someone wires it back up.
            If g_AddFile Then
              LogWarn('READ-ONLY DEBUG FORK: refused to write to BashTags file (use the production script).');
{#ENDIF}
          End;
      End;

  Finally
    slFinalTags.Free;
    slNormExist.Free;
    slWriteDelta.Free;
    slDepFound.Free;
  End;

  slLog.Clear;
  slTagRelationships.Clear;
  slSuggestedTags.Clear;
  slExistingTags.Clear;
  slDifferentTags.Clear;
  slBadTags.Clear;
{#IF DEBUG}

  // Crash-safety flush: write the buffer to disk after every plugin so a
  // mid-run abort still leaves a usable partial trace on disk.
  If g_DebugLogReady Then
    Try
      g_DebugLog.SaveToFile(g_DebugLogPath);
    Except
      // ignore - Finalize will report the error
    End;
{#ENDIF}

  AddMessage(#10);
End;


Function Finalize: integer;
{#IF DEBUG}
Var
  bSavedOK   : boolean;
  sSaveError : string;
{#ENDIF}
Begin
  Result := 0;

{#IF SINGLE,DEBUG}
  If g_MultiFileError Then
    Begin
      LogError('This script must be run on a single plugin per invocation.');
      LogError('Targeted: ' + g_TargetFileName + '; also seen: ' + g_OtherFiles.CommaText);
      LogError('Re-run with only one plugin selected.');
      Result := 99;
    End;
{#ENDIF}
{#IF DEBUG}

  // Flush the debug trace BEFORE freeing other lists, so even if a Free
  // raises (or anything else goes wrong below) we still write the trace
  // and announce the path to the Messages tab.
  bSavedOK   := False;
  sSaveError := '';
  If g_DebugLogReady Then
    Begin
      Try
        g_DebugLog.Add('');
        g_DebugLog.Add('# end of trace ' + DateTimeToStr(Now));
        g_DebugLog.SaveToFile(g_DebugLogPath);
        bSavedOK := True;
      Except
        on E: Exception Do
          sSaveError := '[' + E.ClassName + ': ' + E.Message + ']';
      End;
      Try g_DebugLog.Free; Except End;
      g_DebugLogReady := False;
    End
  Else
    sSaveError := '(buffer was never initialized - see warning above)';

  // Always announce the path, even if save failed - that way the user
  // knows where to look (or where it was supposed to land), and *why*.
  AddMessage('');
  AddMessage('================================================================================');
  If bSavedOK And FileExists(g_DebugLogPath) Then
    Begin
      AddMessage('Debug trace written to:');
      AddMessage('  ' + g_DebugLogPath);
    End
  Else
    Begin
      AddMessage('Debug trace was NOT written. Intended path was:');
      AddMessage('  ' + g_DebugLogPath);
      If sSaveError <> '' Then
        AddMessage('Reason: ' + sSaveError);
    End;
  AddMessage('================================================================================');

{#ENDIF}
{#IF SINGLE,MULTI}
  slLog.Free;
  slTagRelationships.Free;
  slSuggestedTags.Free;
  slExistingTags.Free;
  slDifferentTags.Free;
  slBadTags.Free;
  slDeprecatedTags.Free;
  slBashTagsFileAdds.Free;
  slBashTagsFileRemoves.Free;
  slBashTagsFileLines.Free;
{#ELSEIF DEBUG}
  Try slLog.Free;              Except End;
  Try slTagRelationships.Free; Except End;
  Try slSuggestedTags.Free;    Except End;
  Try slExistingTags.Free;     Except End;
  Try slDifferentTags.Free;    Except End;
  Try slBadTags.Free;          Except End;
  Try slDeprecatedTags.Free;   Except End;
{#ENDIF}
{#IF SINGLE}
  g_OtherFiles.Free;
{#ELSEIF DEBUG}
  Try g_OtherFiles.Free;       Except End;
{#ENDIF}
End;

End.
