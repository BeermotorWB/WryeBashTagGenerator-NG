{ chunk: Var block -- TStringLists, g_* booleans, single-file lock state, debug log state }

Var 
  slBadTags        : TStringList;
  slDifferentTags  : TStringList;
  slExistingTags   : TStringList;
  slLog               : TStringList;
  slTagRelationships  : TStringList;
  slSuggestedTags     : TStringList;
  slDeprecatedTags : TStringList;
{#IF SINGLE,MULTI}
  // BashTags file (Data\BashTags\<plugin>.txt) read state
  slBashTagsFileAdds    : TStringList;
  slBashTagsFileRemoves : TStringList;
  slBashTagsFileLines   : TStringList;
  g_BashTagsFilePath    : string;
  g_BashTagsFileExists  : boolean;

  // User-requested run abort (set via the header/BashTags discrepancy dialog)
  g_AbortRun       : boolean;
{#ENDIF}

  g_FileName       : string;
  g_Tag            : string;
  g_AddTags        : boolean;
  g_AddFile        : boolean;
  g_LogTests              : boolean;
  g_ShowTagRelationships  : boolean;
  g_HeuristicForceTags    : boolean;

{#IF SINGLE,DEBUG}
  // Single-plugin enforcement: lock onto the first file we see. If multiple
  // plugins are selected in xEdit, the first is processed and the run exits
  // with an error in Finalize.
  g_TargetFile     : IwbFile;
  g_TargetFileName : string;
  g_MultiFileError : boolean;
  g_OtherFiles     : TStringList;
{#ENDIF}

  // ---- Debug-fork state ----------------------------------------------
  // Shared across variants so the Dbg* primitives in chunk 03 compile in
  // every build. In SINGLE/MULTI these stay at their default values:
  // g_DebugLogReady is never set True (so DbgWriteRaw exits early), and
  // DebugLevel = DBG_OFF (so DbgLog/DbgLogUnfiltered exit before reaching
  // any of the other Dbg* helpers). Only the DEBUG variant initializes the
  // log buffer, sets g_DebugLogReady, and consumes these globals for real.
  g_DebugLogPath          : string;             // resolved log file path
  g_DebugCurrentRecord    : IwbMainRecord;      // record currently being processed
  g_DebugCurrentTag       : string;             // tag currently being considered
  // xEdit's PascalScript (JvInterpreter) has no AssignFile/TextFile/WriteLn -
  // file IO is buffered through a TStringList and flushed via SaveToFile.
  g_DebugLog              : TStringList;        // in-memory log buffer
  g_DebugLogReady         : boolean;            // True while buffer is usable
  g_DebugIndent           : integer;            // visual nesting (0 = top)
  g_DebugSuggestedSnap    : integer;            // slSuggestedTags.Count snapshot at start of a tag
  // -----------------------------------------------------------------------
