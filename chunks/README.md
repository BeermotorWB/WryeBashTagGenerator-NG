# Chunk layout

This directory holds the source chunks for `WryeBashTagGenerator-NG.pas` and
its two near-identical siblings. The chunks are concatenated in lexical
filename order by `../build.py` to produce one of three variants:

| Variant  | Output file                              | Role                                                    |
|----------|------------------------------------------|---------------------------------------------------------|
| `SINGLE` | `WryeBashTagGenerator-NG.pas`            | Release script. One plugin per invocation; can write.   |
| `MULTI`  | `WryeBashTagGenerator-Multi-NG.pas`      | Batch convenience. Many plugins; auto-skips on conflict.|
| `DEBUG`  | `WryeBashTagGenerator-NG-debug.pas`      | Instrumentation. Never writes; emits per-record trace.  |

Pre-split, these were three ~96%-identical Pascal files maintained by manual
mirroring. The chunk layout exists so that the shared 96% is written once and
the divergent slivers are localized inside `{#IF}` blocks.

This is **pre-rewrite cleanup**. The data-driven rewrite in
`../docs/rearchitecture-plan.md` collapses many of these chunks
(notably 09 and 10) once the registry lands. Until then, the chunk layout is
what keeps the three variants in sync without manual diffing.

## Build

```bash
python3 build.py SINGLE        # one variant
python3 build.py all           # all three
```

`build.py` refuses to overwrite an output file that does not already carry
its `GENERATED FROM chunks/` banner, so hand-edited copies are safe until
moved aside.

## Directive syntax

Markers are line-oriented — each must sit on its own line, optionally
indented. The marker line itself is stripped from output.

```
{#IF SINGLE}              -- single variant
{#IF SINGLE,DEBUG}        -- list (any of)
{#IF NOT MULTI}           -- negation; equivalent to SINGLE,DEBUG today
{#ELSEIF DEBUG}
{#ELSE}
{#ENDIF}
```

Nesting is supported. Convention: prefer explicit positive lists
(`{#IF SINGLE,DEBUG}`) over `{#ELSE}` when there are three variants — it
greps cleanly and tells the reader exactly which variants the block targets.

## Composition rules

1. **Lexical order is link order.** Pascal needs forward declarations, so a
   chunk that calls procedures from another chunk must come after it.
   The `NN-` prefix encodes this; do not renumber casually.
2. **Globals are the bus between chunks.** `slSuggestedTags`, `g_Tag`,
   `g_AddTags`, etc. are declared in `02-globals.pas` and read/written across
   most later chunks. Do not move declarations into the chunk that "owns" the
   feature — keep the global block coherent.
3. **One chunk per concern.** If a feature spans chunks (e.g. logging plumbed
   from primitives through specialty handlers), the cross-cutting nature is a
   property of the feature, not a sign the chunk needs splitting.
4. **`{#IF}` blocks should be small.** If a procedure has more lines inside
   `{#IF}` blocks than outside, consider splitting the procedure — the block
   has stopped being a "small surgical diff" and become a forked
   implementation, which is what we are trying to escape.

## Chunks at a glance

| #  | File                       | Purpose                                          | Variant divergence  |
|----|----------------------------|--------------------------------------------------|---------------------|
| 01 | `01-prelude.pas`           | Header banner, `Unit`, `Uses`, `Const` block     | **High** (version)  |
| 02 | `02-globals.pas`           | `Var` block — TStringLists + `g_*` flags         | **High**            |
| 03 | `03-utilities.pas`         | `wbIsX` probes, logging, regex, small helpers    | None                |
| 04 | `04-normalization.pas`     | Tag alias / removed-tag tables                   | None                |
| 05 | `05-io.pas`                | BashTags file IO + write prompts                 | **Medium**          |
| 06 | `06-primitives.pas`        | `Compare*` leaves + helpers + `AddLogEntry`      | Low (logging hook)  |
| 07 | `07-evaluate.pas`          | `Evaluate*` orchestration + `TryTagGatedByFlag`  | None                |
| 08 | `08-specialty.pas`         | RaceSpells, DelevRelev, ForceTags, list diffs    | None                |
| 09 | `09-processtag.pas`        | The ~1,080-line `ProcessTag` switch              | None                |
| 10 | `10-processrecord.pas`     | Per-record dispatch (game-grouped blocks)        | None                |
| 11 | `11-ui.pas`                | Options dialog + checkbox handlers + `ShowPrompt`| **Medium**          |
| 12 | `12-entry.pas`             | `Initialize`, `Process`, `Finalize`              | **High**            |

The five "None" chunks (03, 04, 07, 08, 09, 10) are the bulk of the file by
line count and are the entire reason for the split — they should be written
exactly once and never carry an `{#IF}` marker.

## Per-chunk contracts

### 01 — `01-prelude.pas`

**Contains:** the leading `{ ... }` doc comment, `Unit
WryeBashTagGeneratorNG;`, `Uses Dialogs;`, and the `Const` block
(`ScriptName`, `ScriptVersion`, `MinXEditVer`, `ScriptAuthor`, `ScriptEmail`,
`ScaleFactor`).

**Variant divergence:** high.

- `ScriptName` differs across all three variants.
- `ScriptVersion` is suffixed with `-debug` in DEBUG.
- The doc-comment header differs: DEBUG's notes the never-writes contract;
  MULTI's notes the auto-skip behaviour and the off-by-default checkbox
  defaults.
- The "Known coverage gaps" sub-block is identical across variants — keep it
  outside any `{#IF}`.

**Does not contain:** any actual `Var` declarations, any function bodies.

### 02 — `02-globals.pas`

**Contains:** the entire `Var` block.

**Variant divergence:** high.

- `g_TargetFile` / `g_TargetFileName` / `g_MultiFileError` / `g_OtherFiles`
  are SINGLE-only — the single-plugin lock that MULTI removes by design.
  Wrap in `{#IF SINGLE}`.
- DEBUG-only globals (debug-log file handle, `DebugLevel` const, filter
  strings) belong in `{#IF DEBUG}`. The CLAUDE.md description suggests
  `DebugFilterForm`, `DebugFilterTag`, and the log file path are DEBUG-only.

**Does not contain:** const-style declarations that belong in `01-prelude`,
or DEBUG's compile-time toggles like `DebugMode` (those go in `01-prelude`'s
`Const` block).

### 03 — `03-utilities.pas`

**Contains:**

- Game probes: `wbIsOblivion`, `wbIsOblivionR`, `wbIsSkyrim`, `wbIsSkyrimSE`,
  `wbIsFallout3`, `wbIsFalloutNV`, `wbIsFallout4`, `wbIsFallout76`,
  `wbIsEnderal`, `wbIsEnderalSE`.
- `ActorSpellArrayPath` — per-game SPLO path resolver.
- `MakeTagSet` — `TStringList` factory with sorted+dupIgnore.
- `LogInfo`, `LogWarn`, `LogError` — `AddMessage` wrappers.
- `StrToBool`, `RegExMatchGroup`, `RegExReplace` — small string utilities.

**Variant divergence:** none. Identical across all three.

**Does not contain:** anything that touches `slSuggestedTags`, `g_Tag`, or any
record-level evaluation. This chunk is leaf-utility-only.

### 04 — `04-normalization.pas`

**Contains:** the alias / removed-tag tables and their consumers —
`TagIsRemoved`, `ExpandOneAliasTo`, `NormalizeBashTagsInPlace`,
`TagsCommaTextEqual`.

**Variant divergence:** none.

**Does not contain:** any IO. The file-write site reads
`NormalizeBashTagsInPlace` from this chunk but lives in `05-io.pas`.

**Cross-references:** if you edit `ExpandOneAliasTo` or `TagIsRemoved`, also
update the table in `../README.md` (the user-facing tag-canonicalization
section) and verify against
`../docs/wrye-bash-tags-reference.md`.

### 05 — `05-io.pas`

**Contains:**

- `ReadBashTagsFile`, `WriteBashTagsFileWithBackup` — the
  `Data\BashTags\<plugin>.txt` reader/writer.
- `HeaderBashTagsDiffer` — header-vs-file diff.
- `PromptDeprecatedHeaderUpdate`, `PromptApproveBashTagsBackup`,
  `NotifyHeaderBashTagsDiscrepancy` — the three modal prompts.

**Variant divergence:** medium.

- `NotifyHeaderBashTagsDiscrepancy` is the big divergence. SINGLE shows a
  two-button Abort/Ignore dialog. MULTI replaces it with an automatic skip
  (no dialog, returns "skip" unconditionally). DEBUG never reaches it
  because writes are short-circuited upstream — but keep DEBUG on the SINGLE
  branch for shape consistency.
- `WriteBashTagsFileWithBackup` itself is identical across variants; the
  short-circuit happens at the call site in `12-entry.pas`, not here.

**Does not contain:** the call sites that *invoke* these prompts. Those
live in `12-entry.pas`'s `Process`.

### 06 — `06-primitives.pas`

**Contains:**

- `Compare*` family: `CompareAssignment`, `CompareElementCount`,
  `CompareElementCountAdd`, `CompareElementCountRemove`, `CompareEditValue`,
  `CompareFlags`, `CompareKeys`, `CompareNativeValues`.
- `EditValues` — the hand-rolled element-walker (deprecated in favour of
  `SortKey` per the rearchitecture plan, but unchanged for now).
- `SortedArrayElementByValue`, `StringListDifference`,
  `StringListIntersection`, `IsEmptyKey`, `FormatTags`, `TagExists`.
- `AddLogEntry` — the bridge from a `Compare*` verdict to `slLog` /
  `slTagRelationships`.

**Variant divergence:** low — only `AddLogEntry`. DEBUG additionally writes a
trace line to the debug log file. Wrap the trace `WriteLn` in `{#IF DEBUG}`
and leave the rest shared.

**Does not contain:** anything that knows about specific tags (no `If g_Tag
= 'X'` decisions). Primitives operate on elements + paths and report
verdicts; tag-specific dispatch lives downstream.

### 07 — `07-evaluate.pas`

**Contains:**

- `Evaluate`, `EvaluateAdd`, `EvaluateChange`, `EvaluateRemove` — orchestrate
  Compare-primitives over a pair of elements.
- `EvaluateByPath`, `EvaluateByPathAdd`, `EvaluateByPathChange`,
  `EvaluateByPathRemove`, `EvaluateBySignature` — the same, with path
  resolution.
- `EvaluateListAdd`, `EvaluateListRemove`, `ResolveListArray`, `ListEntryKey`,
  `ListContainsKey` — keyed-list helpers used by tag-family branches.
- `TryTagGatedByFlag` — the "skip if either side has the flag" gate that
  Skyrim NPC_ overrides use.

**Variant divergence:** none.

**Cross-references:** uses `Compare*` from `06`. Every `ProcessTag` branch
in `09` calls into something declared here.

### 08 — `08-specialty.pas`

**Contains:**

- `ProcessRaceSpells` — Oblivion R.AddSpells / R.ChangeSpells split.
- `ProcessDelevRelevTags` — Delev/Relev LVLO matching.
- `ProcessForceTagHeuristics` — opt-in `*ForceAdd` / `*ForceFullImport` tags.
- `DiffSubrecordList` — keyed-list per-entry diff (Invent.Change,
  Relations.Change, NPC.Perks.Change, R.Relations.Change).
- `CollectArrayEntryIDs`, `CountSetMinus` — set helpers used by the above.
- `FriendlyRelationshipWhy` — translates technical test names to
  user-readable reasons; consumed by `slTagRelationships` formatting.

**Variant divergence:** none.

**Does not contain:** the `ProcessTag` branches that *call* these. Those live
in `09`. A specialty handler is invoked from a tag-family branch, not from
`ProcessRecord` directly.

### 09 — `09-processtag.pas`

**Contains:** the single `ProcessTag(ATag, e, m)` procedure — the ~1,080-line
`Else If g_Tag = 'X'` chain that owns per-tag detection logic. Top of the
procedure handles dedup via `TagExists`.

**Variant divergence:** none.

**Notes:**

- This is the largest chunk by far. If it grows further, it's the natural
  candidate for sub-splitting by tag family (Graphics / Names / Stats /
  Actors.* / NPC.* / Cell / Inventory / Sound / etc.). Don't pre-split it
  yet — the rearchitecture rewrite deletes it entirely in phase 1.
- `g_Tag` is set once at the top (`g_Tag := ATag`); the helpers in `06` and
  `07` read it through `AddLogEntry`. Mutation of `g_Tag` mid-flow happens
  in `10` (the Skyrim NPC_ block) and the specialty handlers in `08`, not
  here.

### 10 — `10-processrecord.pas`

**Contains:** the single `ProcessRecord(e: IwbMainRecord)` function — the
~600-line dispatcher that, per record, walks the applicable tag list for the
current game and signature.

**Variant divergence:** none.

**Notes:**

- This is where the `g_Tag := 'Actors.Factions'` reassignment lives, inside
  the Skyrim NPC_ branch — the subtle semantic the rearchitecture plan flags
  as "high-risk for misencoding into the registry".
- Game-grouping the dispatch (`If wbIsOblivion Then ... Else If wbIsSkyrim
  Then ...`) reads top-down. If you sub-split this chunk later, split by
  game (`10a-oblivion`, `10b-fo3fnv`, ...) — that's the natural seam.

### 11 — `11-ui.pas`

**Contains:** the options dialog and its event handlers — `EscKeyHandler`,
`chkAddTagsClick`, `chkAddFileClick`, `chkLoggingClick`,
`chkTagRelationshipsClick`, `chkHeuristicForceTagsClick`, and `ShowPrompt`.

**Variant divergence:** medium.

- DEBUG hides the "Write suggested tags to header" checkbox (`chkAddTags`)
  entirely and forces `g_AddTags := False`. Wrap the `chkAddTags` creation
  block in `{#IF SINGLE,MULTI}` (or `{#IF NOT DEBUG}`).
- MULTI flips two checkbox defaults: `g_LogTests` and `g_ShowTagRelationships`
  default to `False` (so batch runs are quieter). The control creation is
  shared; only the initial `Checked := ...` line differs.
- Caption / window title may differ slightly per variant — keep the
  divergence inside `{#IF}` rather than duplicating the entire form-builder.

### 12 — `12-entry.pas`

**Contains:** `Initialize`, `Process`, `Finalize` — the three xEdit lifecycle
entry points.

**Variant divergence:** high.

- `Initialize`: DEBUG opens the debug log file. MULTI omits the
  single-plugin lock setup. SINGLE keeps the lock.
- `Process`: the start-of-Process state reset is shared. The single-plugin
  lock check is SINGLE-only. MULTI emits the `=== PluginName.esp ===` banner
  per file. The discrepancy resolution branches differ — see chunk `05`.
- `Finalize`: SINGLE reports the multi-file error if it fired. MULTI does
  not. DEBUG closes the debug log file in addition to whatever the active
  variant does.

**This is the chunk where most `{#IF}` markers will cluster.** Expect each
of the three lifecycle functions to have several variant-specific
sub-blocks. If any one becomes "more `{#IF}` than not", that's the signal to
extract a per-variant helper into a chunk earlier in the file.

## Where the `{#IF}` markers will cluster

Predictable hot zones, ranked by expected marker density:

1. **`12-entry.pas`** — three lifecycle functions, all with variant-specific
   guarding. Highest density.
2. **`01-prelude.pas`** — `ScriptName` / `ScriptVersion` / doc comment all
   differ. Small chunk, but every line is touched.
3. **`02-globals.pas`** — variant-specific `Var` declarations.
4. **`11-ui.pas`** — DEBUG hides a checkbox; MULTI flips defaults.
5. **`05-io.pas`** — the discrepancy notifier shape differs.
6. **`06-primitives.pas`** — single `{#IF DEBUG}` line in `AddLogEntry`.

Chunks 03, 04, 07, 08, 09, 10 should never need an `{#IF}` marker. If one
appears there, treat it as a sign that variant divergence has leaked into
shared logic — push it back up the call graph into one of the chunks above.

## Adding a new chunk

If a chunk grows past the point of comfortable single-pass reading
(roughly: doesn't fit on one screen at a normal zoom, or the table of
contents at the top would exceed ~10 entries):

1. Pick a seam that's already implicit — a tag family within `09`, a game
   within `10`, a logical group within `06`.
2. Number the new chunk to fit the link-order constraint. Use a letter
   suffix (`09a-`, `09b-`) rather than renumbering siblings, so existing
   references in commit history and docs stay valid.
3. Update this README's chunk table.
4. Re-run `python3 build.py all` against a scratch directory and diff the
   output against the previous one to confirm the split is byte-identical.

Do **not** sub-split a chunk just because it's the largest one available
to split — split because the chunk has multiple distinct concerns that
would benefit from being read separately. `09-processtag.pas` is huge but
single-concern; leave it alone until the rearchitecture deletes it.

## Relationship to the rearchitecture plan

This chunked layout is **pre-rewrite cleanup**, not a substitute for the
data-driven rewrite proposed in
`../docs/rearchitecture-plan.md`. The rewrite collapses
chunks 09 and 10 into a ~50-line dispatcher driven by a JSON tag registry,
and folds DEBUG back into the SINGLE codebase as a `DebugMode` const —
which retires the entire `{#IF DEBUG}` axis.

What this layout buys in the meantime:

- The 96% shared body lives in one place. Detection-logic edits no longer
  require triple-mirroring.
- The points where the variants actually diverge are localized and
  searchable (`grep '{#IF MULTI}'`).
- When phase 1 of the rewrite begins, the new engine drops in alongside
  these chunks rather than alongside three forked monoliths — the diff
  surface is smaller, and parity testing has a cleaner before-state.
