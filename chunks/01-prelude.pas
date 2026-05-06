{ chunk: header comment, Unit, Uses, Const block (ScriptName/Version/etc.) }
{
{#IF MULTI, SINGLE}
  Generates bash tags for a selected plugin automatically.
  Tag names aligned with Wrye Bash _tag_aliases / patcher tags; FO4 parity with WB FO4 patchers.
{#ELSEIF DEBUG}
  WryeBashTagGenerator-NG-debug : READ-ONLY DEBUG FORK
  ----------------------------------------------------
  Same detection logic as WryeBashTagGenerator-NG, but:

    * NEVER writes to plugin headers. The single SetEditValue() call that
      mutates SNAM is short-circuited, g_AddTags is forced False, and the
      "Write suggested tags to header" checkbox is hidden in the prompt.
    * Emits a per-decision trace to a log file. For every tag the script
      considers on every record it touches, the log records the reason the
      tag was SUGGESTED or SKIPPED (template-flag gate, conflict state,
      no-difference, identical edit values, etc.).
    * Three verbosity levels (set g_DebugLevel below):
        DBG_PER_TAG       (1)  per-tag-per-record verdict only
        DBG_PER_COMPARE   (2)  + every Compare*/Evaluate*/DiffSubrecordList call (DEFAULT)
        DBG_LEAF_DIFFS    (3)  + actual differing edit-value snippets
    * Optional filters (g_DebugFilterFormID / g_DebugFilterTag) restrict
      output to a specific record (load-order FormID hex, e.g. '00013602')
      and / or a specific tag (e.g. 'Actors.Factions').

  Output file: <xEdit folder>\Edit Scripts\WryeBashTagGenerator-NG-debug.log
  The full path is also written to xEdit Messages at the end of the run.

  This file is a fork of WryeBashTagGenerator-NG.pas (base SHA: b15e95f).
  Sync detection-logic changes manually; do not change behavior in this
  file unless you also intend to debug an instrumentation bug.
{#ENDIF}


  Games:    FO3/FNV/FO4/TES4/TES4R/TES5/SSE/Enderal/EnderalSE
  Requires: xEdit 4.1.4 or newer (script aborts on older builds)
  Hotkey:   F12

  Lineage / citation:
    - Original WryeBashTagGenerator: fireundubh.
    - Multifile WryeBashTagGenerator variant: Xideta.
    - WryeBashTagGenerator-NG (this fork): Beermotor.

  NO SUPPORT - provided as an example. Do NOT contact fireundubh or Xideta
  about this fork; they did not write it and are not responsible for its
  behavior.

  Heuristic Force* tags (opt-in checkbox; off by default):
    - Actors.SpellsForceAdd       : override Spells is a strict superset of master Spells AND Actors.Spells already suggested.
    - Actors.AIPackagesForceAdd   : override Packages is a strict superset of master Packages AND Actors.AIPackages already suggested.
    - NpcFacesForceFullImport     : NPC differs from master in eyes (ENAM), hair (HNAM), AND face geometry simultaneously.
  These heuristics may produce false positives on plugins that intentionally only add entries; review before committing.

  Oblivion RACE Spells split (replaces v1.0 single-tag emission):
    - removes present (master has SPEL not in override)  -> R.ChangeSpells (full override required to apply removal)
    - adds-only                                          -> R.AddSpells    (additive merge sufficient; preserves other mods' adds)
    - identical sets                                     -> nothing

  Known coverage gaps (see COVERAGE_GAPS.txt for full audit, severity, and
  effort estimates):
    - FO3/FNV Graphics dispatch is missing 17+ reference signatures
      including ARMA, AVIF, BPTD, COBJ, CONT, EXPL, HDPT, IPCT, MSTT,
      PERK, TACT, TERM, TXST. Root cause: the OB-shaped sGfxNamesSigs
      base set is never overridden for FO3/FNV the way it is for Skyrim.
      Each signature also needs a handler bucket entry in the Graphics
      ProcessTag branch.
    - FO3/FNV Stats dispatch is missing EYES, HAIR, HDPT (flag-compare
      records). The Stats handler currently has no flag-comparison path
      for those signatures, so these need new handler logic in addition
      to dispatch.
}

{#IF MULTI}
Unit WryeBashTagGeneratorMultiNG;
{#ELSEIF DEBUG}
Unit WryeBashTagGeneratorNGDebug;
{#ELSEIF SINGLE}
Unit WryeBashTagGeneratorNG;
{#ENDIF}

Uses 
  Dialogs;

Const 
{#IF MULTI}
  ScriptName    = 'WryeBashTagGenerator-Multi-NG';
{#ELSEIF DEBUG}
  ScriptName    = 'WryeBashTagGenerator-NG-debug';
{#ELSEIF SINGLE}
  ScriptName    = 'WryeBashTagGenerator-NG';
{#ENDIF}
{#IF SINGLE,MULTI}
  ScriptVersion = '1.9.8';
{#ELSEIF DEBUG}
  ScriptVersion = '1.9.8-debug';
{#ENDIF}

  MinXEditVer   = $04010400; // 4.1.4 (native StringList set ops + assumed API surface)
  ScriptAuthor  = 'Beermotor and Xideta';
  ScriptEmail   = 'NO SUPPORT';
  ScaleFactor   = Screen.PixelsPerInch / 96;

  // Verbosity levels for the debug trace. Defined in every variant so the
  // shared Dbg* primitives in chunk 03 compile without {#IF DEBUG} guards.
  // SINGLE/MULTI set DebugLevel = DBG_OFF; the level check at the top of
  // DbgLog/DbgLogUnfiltered then short-circuits every trace call.
  DBG_OFF         = 0;   // no debug output (effectively production)
  DBG_PER_TAG     = 1;   // one line per (record, tag) verdict
  DBG_PER_COMPARE = 2;   // + every Compare*/Evaluate*/DiffSubrecordList call
  DBG_LEAF_DIFFS  = 3;   // + actual differing edit-value snippets

{#IF SINGLE,MULTI}
  DebugLevel       = DBG_OFF;          // production: trace disabled
{#ELSEIF DEBUG}
  // ---- Edit these to tune the trace -------------------------------------
  DebugLevel       = DBG_PER_COMPARE;  // 1=per-tag, 2=per-compare, 3=leaf-diffs
{#ENDIF}
  DebugFilterForm  = '';               // load-order FormID hex (e.g. '00013602'); '' = no filter
  DebugFilterTag   = '';               // exact tag name (e.g. 'Actors.Factions'); '' = no filter
