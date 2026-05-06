# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

An xEdit Pascal script (Delphi-flavored scripting, not standalone Pascal) that runs **inside xEdit** to generate Wrye Bash tags for a plugin by diffing overrides against their masters. There is no build system, no package manager, no test framework — the deliverable is a single `.pas` file copied into xEdit's `Edit Scripts` folder.

The three `.pas` files in the repo are siblings, not a toolchain:

- `WryeBashTagGenerator-NG.pas` — the release script. **Single plugin per invocation**: if a selection spans multiple files, `Process` locks onto the first via `g_TargetFile` and `Finalize` aborts with `g_MultiFileError`. Can write to plugin headers and `Data\BashTags\<plugin>.txt`.
- `WryeBashTagGenerator-Multi-NG.pas` — batch convenience. Same detection logic, but accepts many selected plugins and processes each independently (no `g_TargetFile` lock). On a header↔BashTags-file discrepancy it **auto-skips** writes for that plugin and continues — no Abort/Ignore dialog. Test logging and tag-relationship output default **off** to keep batch runs readable.
- `WryeBashTagGenerator-NG-debug.pas` — instrumentation fork of the single-plugin script. **Never writes to plugin headers** (`SetEditValue` on SNAM is short-circuited, `g_AddTags` forced False, header checkbox hidden). Emits a per-(record,tag) verdict trace to `Edit Scripts\WryeBashTagGenerator-NG-debug.log`. Verbosity set by `DebugLevel` const; optional filters `DebugFilterForm` / `DebugFilterTag`.

When you change detection behavior in `-NG.pas`, mirror the relevant change into both `-NG-debug.pas` and `-Multi-NG.pas`. The debug file's header comment pins a base SHA for the last sync; update it when you re-sync.

## "Build", run, test

There is no build step. The script runs inside xEdit:

1. Copy the `.pas` file into your xEdit install's `Edit Scripts` folder (e.g. `SSEEdit\Edit Scripts\`).
2. Launch xEdit, load plugins, right-click a plugin → Apply Script → pick the script.
3. F12 re-runs the most recently selected script.

**Testing is manual.** Validate changes by running against real plugins in xEdit and inspecting the Messages tab. The debug variant is the primary investigation tool — use it when you need to know why a tag did or didn't fire on a specific record; it emits a line for every skip and every suggestion, with the gating reason. Running the release script with both "Log test results" and "Show Tag to Record Relationships" checkboxes on also gives useful per-detection output in the Messages tab (technical `{Tag} (TestName) [SIG:FormID]` lines + plain-language `[INFO] Tag suggestion ...` lines).

Minimum xEdit version is **4.1.4** (`MinXEditVer = $04010400`); the script aborts on older builds because it relies on native StringList set operations. Fallout 76 is explicitly unsupported (CBash limitation).

## Script lifecycle (xEdit Pascal contract)

xEdit calls four entry points in order. Understanding the lifecycle is the key to navigating this file:

- `Initialize` — creates all global TStringLists, shows the options dialog via `ShowPrompt`, aborts on unsupported games / old xEdit. Sets `ScriptProcessElements := [etFile]` so `Process` receives each selected file once.
- `Process(input)` — runs once per selected file. Iterates every record via `RecordByIndex`/`ProcessRecord`, then produces the RESULTS summary, resolves header/BashTags-file write prompts, and performs writes. Also enforces the single-plugin invariant (see below).
- `ProcessRecord(e)` — per-record dispatch. A long series of `If game/signature Then ProcessTag('X', e, o)` calls. `o` is `HighestOverrideOrSelf(Master(e), OverrideCount)`. Early-exits on non-conflicting, deleted, or identical records.
- `Finalize` — frees the global TStringLists, and reports the multi-file error if it fired.

The options dialog lives in `ShowPrompt`. Its checkboxes set the module-global `g_AddTags`, `g_AddFile`, `g_LogTests`, `g_ShowTagRelationships`, `g_HeuristicForceTags` booleans that the rest of the code reads directly.

## Detection layering

The detection code is layered; new tags almost always slot into an existing layer rather than adding a new one:

1. **`ProcessTag(tagName, e, m)`** (~950 lines, `Else If` chain on `g_Tag`). This is the big switch. Each branch knows which subrecord path / element name to diff for its tag and calls into the Evaluate/Compare helpers. Per-tag dedup is handled at the top via `TagExists`, so it is safe to call `ProcessTag` for the same tag from multiple sites in `ProcessRecord`.
2. **`Evaluate*` / `EvaluateByPath*`** — orchestration: resolves the path, checks assignment, element count, edit value, compare-keys in sequence. Separate `Add` / `Change` / `Remove` variants exist for `*.Add` / `*.Change` / `*.Remove` tag triples.
3. **`Compare*`** — leaf predicates: `CompareAssignment`, `CompareElementCount` (+Add/Remove), `CompareEditValue`, `CompareKeys`, `CompareFlags`, `CompareNativeValues`. Each one calls `AddLogEntry` with a test name when it decides to suggest the tag — that test name is what later becomes the `FriendlyRelationshipWhy` reason string in the Messages output.
4. **Specialty procedures** — when the standard pipeline doesn't fit:
   - `ProcessRaceSpells` — RACE SPLO add/remove split (emits `R.AddSpells` xor `R.ChangeSpells`). SPLO array path is per-game: `'Spells'` on Oblivion, `'Actor Effects'` on Skyrim/SSE/Enderal.
   - `DiffSubrecordList` — per-entry change diff for sorted/keyed lists (`NPC.Perks.Change`, `Relations.Change`, etc.). Ignores adds and removes by design — those belong to the `.Add` / `.Remove` siblings.
   - `ProcessDelevRelevTags` — Delev/Relev detection.
   - `ProcessForceTagHeuristics` — opt-in heuristics (`Actors.SpellsForceAdd`, `Actors.AIPackagesForceAdd`, `NpcFacesForceFullImport`). Gated on `g_HeuristicForceTags`.

### Global TStringLists

These are the bus between layers — they persist across `ProcessRecord` calls within a single `Process` invocation and are cleared at the end:

- `slSuggestedTags` — the set of tags `Process` decided to emit (sorted, dupIgnore). This is the source of truth for "which tags are we recommending". `TagExists(t)` checks membership here.
- `slLog` — technical `{Tag} (TestName) [SIG:FormID] path` lines (one per Compare* that fired). Gated on `g_LogTests` in output.
- `slTagRelationships` — plain-language `Tag suggestion X based on <why> at [SIG:FormID] path` lines (one per detection). Gated on `g_ShowTagRelationships`.
- `slExistingTags` — what's currently in the plugin's header `{{BASH:...}}` block (raw, pre-normalization).
- `slBashTagsFileAdds` / `slBashTagsFileRemoves` / `slBashTagsFileLines` — parsed `Data\BashTags\<plugin>.txt` contents (adds, `-Tag` removes, and raw lines for in-place backup).
- `slDeprecatedTags` — the known-deprecated alias names, used to detect migrations.

`g_Tag` is a mutable "current tag under consideration" variable that `ProcessTag` sets and the Evaluate/Compare helpers read. This is how `AddLogEntry` knows what tag fired without being passed one. Changing `g_Tag` mid-flow is a real pattern (see gated `Actors.Factions` / `NPC.AIPackageOverrides` / `Actors.Spells` sites in `ProcessRecord`); don't assume it's stable across nested calls.

## Tag canonicalization rule

**Every tag that reaches user-visible output or gets written to the plugin must go through `NormalizeBashTagsInPlace`.** This function expands Wrye Bash's deprecated aliases (`Factions` → `Actors.Factions`, `NpcFaces` → `{NPC.Eyes, NPC.Hair, NPC.FaceGen}`, etc.) and drops removed tags (`Merge`, `ScriptContents`). The alias table lives in `ExpandOneAliasTo` (one big `SameText` chain) and the "removed" set lives in `TagIsRemoved`. Both mirror Wrye Bash's `Mopy/bash/bosh/__init__.py` `_tag_aliases` + `_removed_tags` — if you update one, check the other. `slDeprecatedTags.CommaText` in `Initialize` must list every deprecated key from both tables; it's what drives deprecation detection in the header scan.

The README's "Tag canonicalization" table is the user-facing version of this mapping. Keep the table in sync when you edit `ExpandOneAliasTo`.

## Per-plugin processing (Multi-NG only)

`WryeBashTagGenerator-NG.pas` processes a single plugin per invocation and aborts in `Finalize` if the selection spans more than one file (`g_TargetFile` / `g_MultiFileError` / `g_OtherFiles` at lines ~99–101, ~620–630, ~1474–1477). The hard rules below apply to `WryeBashTagGenerator-Multi-NG.pas`, which removes that lock and runs detection per file independently. The start-of-Process state reset (rule 2) is also present in `-NG.pas` as defense-in-depth, even though only one plugin is processed.

Hard rules for per-plugin independence:

1. **No cross-file detection.** Tags on plugin A must not depend on or be influenced by plugin B's records in the same run. If you add new detection logic, only read from the current plugin and its masters.
2. **State resets at start of `Process`, not end.** `Process` clears `slSuggestedTags`, `slLog`, `slTagRelationships`, `slExistingTags`, `slDifferentTags`, `slBadTags`, `slBashTagsFileAdds`, `slBashTagsFileRemoves`, `slBashTagsFileLines`, and resets `g_BashTagsFilePath` / `g_BashTagsFileExists` before any detection runs. End-of-Process clears are still there as belt-and-braces. The start-of-Process reset is the correctness guarantee: if plugin A exits `Process` early (exception, discrepancy skip), plugin B still begins with a clean slate. This is the fix for the "sometimes doesn't clear tags" bug in the earlier partial-multifile attempt.
3. **The options dialog (`ShowPrompt`) fires once in `Initialize`.** `g_AddTags` / `g_AddFile` / `g_LogTests` / `g_ShowTagRelationships` / `g_HeuristicForceTags` apply to every plugin in the run.
4. **Write prompts fire per-plugin.** `PromptDeprecatedHeaderUpdate`, `PromptApproveBashTagsBackup`, and `NotifyHeaderBashTagsDiscrepancy` are called from inside `Process`, so each plugin gets its own decisions. Declining affects only the current plugin.
5. **`g_AbortRun` halts the rest of the run.** The discrepancy dialog now has two buttons (see "Write paths and prompts" below). Abort sets this flag; the top of `Process` checks it and returns immediately for every remaining plugin. Completed writes on earlier plugins are not rolled back.

Messages-tab output per plugin is separated by a `=== PluginName.esp ===` banner emitted at the top of `Process`.

## Write paths and prompts

Two independent write gates, both resolved in `Process` before any mutation:

- **Header write** (`g_AddTags`): rewrites the `{{BASH:...}}` block in the plugin description's SNAM. If the existing description contains deprecated aliases, `PromptDeprecatedHeaderUpdate` runs first; declining leaves *this* plugin's description untouched and processing continues to the next plugin.
- **BashTags file write** (`g_AddFile`): writes `Data\BashTags\<plugin>.txt` via `WriteBashTagsFileWithBackup` (overwrites the file; previous contents are preserved as `#`-commented lines at the top of the new file — destructive to the raw format, non-destructive to the content). Before overwriting an existing file, `HeaderBashTagsDiffer` runs. If header and file disagree, `NotifyHeaderBashTagsDiscrepancy` fires a two-button dialog:
  - **Ignore** → skip *this* plugin's header + BashTags-file writes, continue with the next plugin.
  - **Abort** → sets `g_AbortRun`, same skip as Ignore for the current plugin, and every subsequent `Process` call returns immediately. Completed writes on earlier plugins stay as-is.

  If the user does not hit Abort/Ignore and the files agree, `PromptApproveBashTagsBackup` prompts Yes/No as usual.

The diff/discrepancy check must happen before the header write so that Ignore/Abort can also suppress the header rewrite. Don't reorder these.

Known behavior quirk worth knowing before touching `WriteBashTagsFileWithBackup`: successive runs nest the backup. Run 2 reads Run 1's `#`-commented backup block as part of `AOriginalLines` and wraps it in a new backup block — after N runs the file has N nested backup blocks. Verbose but not lossy. Fixing this would mean stripping prior `# --- Backup ... ---` blocks out of `slBashTagsFileLines` before writing.

In `-Multi-NG.pas` the discrepancy dialog is replaced by an automatic skip: header + BashTags-file writes for that plugin are silently dropped and the run continues with the next plugin. There is no Abort path; the user must cancel xEdit to stop a Multi-NG run early.

## Messages-tab output contract

All user-visible output goes through `LogInfo` / `LogWarn` / `LogError`, which prepend `[INFO] ` / `[WARN] ` / `[ERRO] ` to `AddMessage`. Tag lists are formatted by `FormatTags(list, singular, plural, null)` which produces either a count + `{{BASH:Tag1, Tag2, ...}}` block or the null-case string. When adding a new RESULTS line, use `FormatTags` so xEdit Messages renders it identically to the existing lines.

## Versioning

Bump the `ScriptVersion` constant (near the top of the constants block) on any behavioral change. The convention is `MAJOR.MINOR.PATCH.REV` — see git log for recent examples. The version is embedded into the generated BashTags file header comment, so it shows up in user-visible output. The debug script has its own `-debug`-suffixed version string.

## External references

Local distilled references (prefer these first — they're scoped to what this script uses):

- `docs/xedit-scripting-api.md` — xEdit Pascal API cheat sheet (entry points, IwbFile/IwbMainRecord/IwbContainer surfaces).
- `docs/wrye-bash-tags-reference.md` — every Wrye Bash tag with per-game applicability, plus the full deprecation/alias map. Distilled directly from the Wrye Bash Python source, cross-referenced per-file. Supersedes the older readme-derived `wrye-bash-tags-readme.md.outdated`, which is kept only as a historical snapshot of the upstream readme and should not be trusted for per-game applicability.

Upstream sources (authoritative, consult when the local reference is ambiguous or out of date):

- **xEdit scripting functions**: https://tes5edit.github.io/docs/13-Scripting-Functions.html
- **Wrye Bash tag list**: https://wrye-bash.github.io/docs/Wrye%20Bash%20Advanced%20Readme.html#patch-list-of-tags
- **Wrye Bash source**: https://github.com/wrye-bash/wrye-bash — `Mopy/bash/bosh/__init__.py` holds `_tag_aliases` / `_removed_tags`, the upstream source for `ExpandOneAliasTo` / `TagIsRemoved`.
- **xEdit source**: https://github.com/TES5Edit/TES5Edit
