# Rearchitecture plan: data-driven tag registry

**Status:** proposed, not started. Written 2026-04-21 as a reference for picking up later.
**Scope:** a one-time rewrite of `WryeBashTagGenerator-NG.pas` that moves per-game tag coverage out of Pascal control flow and into a JSON data file. Retires `WryeBashTagGenerator-NG-debug.pas` as a separate file.
**Do not execute without re-reading:** the open-questions section below has four items that must be answered before starting; getting them wrong mid-work costs rework.

## Why this exists

Today the script encodes a three-dimensional relationship — `(tag × game × record-signature)` — as nested two-way control flow spread across `ProcessRecord` (game-grouped dispatch blocks, ~600 lines) and `ProcessTag` (big Else-If chain with `If wbIsX / Else If wbIsY` ladders inside each branch, ~960 lines). The consequence:

- Answering "does Skyrim emit tag X?" requires reading both sides and reconciling them manually.
- Changing which games get a tag means editing ≥2 sites and getting the game-group guard, the signature list, the template-flag-gate name, and the independent-If-vs-Else-If ordering all correct.
- Every change must be mirrored into `WryeBashTagGenerator-NG-debug.pas`, which is a 95%-identical manual sibling.
- The five known coverage gaps listed at `WryeBashTagGenerator-NG.pas:29-51` (R.Stats SK, extended Names SK signatures, Actors.ACBS/AIData SK field coverage, C.MiscFlags naming) have stayed open precisely because the cost of fixing each one in the current layout is high relative to the win.
- Adding a future game (Oblivion Remastered full differentiation, TES6, etc.) has cost O(codebase-size) instead of O(actual-divergence).

The reference doc at `docs/wrye-bash-tags-reference.md` is already a table. The Wrye Bash source it was distilled from is a table. Only the script sits in between as prose.

## Target architecture

**One idea: the tag registry is data; the engine is small.**

```
┌──────────────────────────────────────────────────────────────┐
│ 1. Game probes           wbIsOblivion / wbIsSkyrim / …       │ unchanged
├──────────────────────────────────────────────────────────────┤
│ 2. Alias & removed map   one table, mirrors _tag_aliases     │ data
├──────────────────────────────────────────────────────────────┤
│ 3. TAG REGISTRY          Edit Scripts/…-rules.json           │ data ← heart
│    one row per tag, per-game overrides, loaded at startup    │
├──────────────────────────────────────────────────────────────┤
│ 4. Primitives            5 comparison functions, ~10 LOC ea. │ code
├──────────────────────────────────────────────────────────────┤
│ 5. Specialty handlers    RaceSpells, DelevRelev, ForceAdd,   │ code
│                          keyed-change diff, heuristics       │ (hooked from registry)
├──────────────────────────────────────────────────────────────┤
│ 6. Dispatcher            for each record: lookup signature → │ code ← ~50 LOC
│                          walk candidate rules → run          │
│                          primitive or specialty handler      │
├──────────────────────────────────────────────────────────────┤
│ 7. I/O + normalization   header parse, BashTags file, prompts│ unchanged
├──────────────────────────────────────────────────────────────┤
│ 8. Entry points          Initialize / Process / Finalize     │ unchanged
│                          + DebugMode const replaces -debug.pas│
└──────────────────────────────────────────────────────────────┘
```

### Registry row (JSON)

Conceptual shape — subject to revision in phase 1:

```json
{
  "tag": "C.Climate",
  "games": ["OB", "FO3", "FNV", "SK"],
  "signatures": ["CELL"],
  "kind": "standard",
  "primitive": "EvaluateByPath",
  "path": "XCCM",
  "pre_flag_gate": {
    "SK":       { "path": "DATA", "flag": "Show Sky" },
    "default":  { "path": "DATA", "flag": "Behave Like Exterior" }
  }
}
```

Per-game-divergent case:

```json
{
  "tag": "Actors.Spells",
  "games": ["OB", "FO3", "FNV", "SK", "FO4"],
  "signatures": ["CREA", "NPC_"],
  "signature_overrides": { "SK": ["NPC_"], "FO4": ["NPC_"] },
  "kind": "standard",
  "primitive": "EvaluateByPath",
  "path_per_game": { "OB": "Spells", "default": "Actor Effects" },
  "template_gate": {
    "OB":  null,
    "SK":  "Use Spell List",
    "FO3": "Use Actor Effect List",
    "FNV": "Use Actor Effect List",
    "FO4": null
  }
}
```

Specialty case:

```json
{
  "tag": "R.AddSpells",
  "co_tag": "R.ChangeSpells",
  "games": ["OB", "SK"],
  "signatures": ["RACE"],
  "kind": "specialty",
  "handler": "ProcessRaceSpells"
}
```

### Why JSON and not a delimited string constant

xEdit ships the **JsonDataObjects** library — confirmed by `docs/xEditScripts/JSON - Demo.pas`. `TJsonObject.Parse` / `LoadFromFile` plus typed accessors (`Obj.S['tag']`, `Obj.A['games']`) give us a real data format at ~10 LOC of parsing code. The alternative (multi-line delimited string constant in the .pas) works but is strictly worse for review, diffing, and contribution.

### Dispatcher

Pseudocode:

```
procedure ProcessRecord(e):
    sig := Signature(e)
    for each rule in RulesBySignature[sig]:
        if not rule.games contains CurrentGame: continue
        if rule.template_gate for CurrentGame is set
           and flag is set on either side: continue
        if rule.kind = 'specialty':
            call rule.handler(e, master, rule.tag)
            continue
        path := resolve rule.path_per_game for CurrentGame
        run rule.primitive(e, master, rule.tag, path)
```

`RulesBySignature` is built once at `Initialize` by walking the loaded registry and indexing rules by their applicable signatures. Per-tag dedup still lives at the `slSuggestedTags.Add` site — the dispatcher is order-agnostic.

### `g_Tag` goes away

Each primitive takes the tag name as an explicit parameter. `AddLogEntry` takes it as a parameter. The Skyrim NPC_ `TryTagGatedByFlag('Actors.Factions', ...)` idiom that relies on mutating `g_Tag` before calling disappears — the gate is declared on the rule.

### Primitives (5 total)

| Primitive | Replaces | Notes |
|---|---|---|
| `EvaluateByPath` | current `Evaluate` + `EvaluateByPath` | Assign + count + edit-value + key diff |
| `EvaluateByPathAdd` | current `EvaluateAdd` + `EvaluateByPathAdd` | Count strictly greater |
| `EvaluateByPathRemove` | current `EvaluateRemove` + `EvaluateByPathRemove` | Count strictly less |
| `EvaluateByPathChange` | current `EvaluateChange` + `EvaluateByPathChange` | Keyed shared-entry diff — see `DiffSubrecordList` specialty |
| `EvaluateFlag` | current `CompareFlags` in :OR and :NOT modes | Flag-on-either-side gate + flag-differs detection |

Primitives should internally use `SortKey(elem, True)` where the current code uses the hand-rolled `EditValues` walker at `WryeBashTagGenerator-NG.pas:1503-1525`. See phase 3 — this is a separate behavioural change, done only after parity is proven.

### Specialty handlers (5 total, ported ~as-is)

- `ProcessRaceSpells` — R.AddSpells / R.ChangeSpells list-shape split.
- `ProcessDelevRelevTags` — Delev/Relev LVLO matching.
- `ProcessForceTagHeuristics` — three opt-in Force tags.
- `DiffSubrecordList` — called from rules where `kind: "keyed_change"`, backing `Invent.Change`, `Relations.Change`, `R.Relations.Change`, `NPC.Perks.Change`.

Each specialty takes `(record, master, tag)` explicitly. No globals.

### Debug fork eliminated

`WryeBashTagGenerator-NG-debug.pas` collapses to three compile-time toggles in the same file:

- `DebugMode` constant at the top. When true: `SetEditValue` is short-circuited, header rewrite skipped, BashTags-file write skipped, the `Write suggested tags to header` checkbox is hidden.
- `DebugLevel` constant controls log verbosity.
- `DebugFilterForm` / `DebugFilterTag` string constants filter instrumentation output.
- Primitives route through a single `Emit(tag, test-name, elem, master, verdict)` hook that, when `DebugMode`, logs every pass/fail to `Edit Scripts/WryeBashTagGenerator-NG-debug.log`.

One file, two modes, zero manual sync.

## What stays, what moves, what dies

| File / section | Fate |
|---|---|
| `wbIsX` game probes | unchanged |
| `NormalizeBashTagsInPlace` / `ExpandOneAliasTo` / `TagIsRemoved` | cleanup to a single alias/removed table, minor |
| `ReadBashTagsFile` / `WriteBashTagsFileWithBackup` | unchanged |
| `PromptDeprecatedHeaderUpdate` / `PromptApproveBashTagsBackup` / `NotifyHeaderBashTagsDiscrepancy` | unchanged |
| `HeaderBashTagsDiffer` / `TagsCommaTextEqual` | unchanged |
| `FormatTags` / `LogInfo` / `LogWarn` / `LogError` | unchanged |
| `ShowPrompt` | unchanged except debug-mode respects `DebugMode` const |
| `Initialize` / `Process` / `Finalize` | `Initialize` grows JSON load; `Process`'s per-record loop unchanged |
| `ProcessRecord` (current ~600 lines) | **replaced** by ~50-line dispatcher |
| `ProcessTag` (current ~960 lines of Else-If) | **deleted** — rules are data |
| `TryTagGatedByFlag` | deleted — gate is declared on the rule |
| `g_Tag` module global | deleted — primitives take tag as parameter |
| `Evaluate*` family (11 procs) | collapsed to 5 primitives |
| `Compare*` family (7 funcs) | internals of the primitives |
| `EditValues` (custom walker) | **deprecated in favour of `SortKey`**, but only after parity (phase 3) |
| `ProcessRaceSpells` / `ProcessDelevRelevTags` / `ProcessForceTagHeuristics` / `DiffSubrecordList` | ported ~as-is, called from dispatcher |
| `FriendlyRelationshipWhy` | unchanged (used by the Emit hook) |
| `WryeBashTagGenerator-NG-debug.pas` (separate file) | **deleted**, replaced by `DebugMode` const |

## Known coverage gaps to fix during the rewrite

From the header at `WryeBashTagGenerator-NG.pas:29-51`. In the new layout, each is a registry edit (new row or column entry), not a ProcessTag branch:

1. **R.Stats (Skyrim)** — fully unimplemented. New rule: games=`[SK]`, signatures=`[RACE]`, primitive=`EvaluateByPath` over `DATA\Starting Health`, `DATA\Starting Magicka`, `DATA\Starting Stamina`, `DATA\Base Carry Weight`, `DATA\Health Regen`, `DATA\Magicka Regen`, `DATA\Stamina Regen`, `DATA\Unarmed Damage`, `DATA\Unarmed Reach`.
2. **Names on Skyrim-specific signatures** — the Skyrim Names signature list should include AVIF, CLFM, EXPL, HAZD, HDPT, LCTN, MESG, MSTT, PERK, SCRL, SHOU, SNCT, TACT, TREE, WATR, WOOP (per reference). Registry edit: extend the Names rule's `signatures_per_game["SK"]`.
3. **Actors.ACBS Skyrim field coverage** — the current non-FO4 branch evaluates Fatigue / Calc min / Calc max / DATA\Base Health which don't exist on Skyrim ACBS. Split into per-game field lists; Skyrim gets Magicka Offset, Stamina Offset, Disposition Base, Health Offset, Bleedout Override.
4. **Actors.AIData Skyrim field coverage** — same shape. Current non-FO4 branch checks Responsibility / Teaches / Maximum training level / Buys-Sells-Services. Skyrim AIDT needs Morality, Mood, Assistance, Aggro radius fields instead.
5. **C.MiscFlags flag name verification** — current code uses `'Can Travel From Here'`; Wrye Bash docs say `"Can't Travel From Here / Invert Fast Travel Behavior"`. Verify against the xEdit flag-array schema before committing — may be an xEdit-display-name mismatch.

Each fix is a rule edit. Budget ~1 hour of verification per gap in phase 2.

## Implementation phases

**Staged so the old script stays shipping until parity is proven.** Don't big-bang it.

### Phase 1 — First-cut codebase

**Owner:** Claude. **Your role:** review the diff.

Deliverables:

- `WryeBashTagGenerator-NG-v2.pas` — new engine, shipped alongside the existing `.pas`, not replacing it.
- `WryeBashTagGenerator-NG-rules.json` — populated registry, ~70 rules. Each rule cross-referenced against both the reference doc and the existing `ProcessTag` body.
- `scripts/audit-registry.py` (or similar) — companion script that parses the JSON registry, re-derives per-game tag sets, and diffs against Appendix A of `docs/wrye-bash-tags-reference.md`. CI-runnable.
- Updated `CLAUDE.md` describing the new architecture (keep the old detection-layering section commented out until phase 4).

Estimated compute: 3–5 hours of Claude wall-clock.

### Phase 2 — Parity verification

**Owner:** you. **Claude's role:** fix reported divergences.

Workflow per test plugin:
1. Run current `.pas`, save Messages-tab tag output.
2. Run v2 `.pas`, save Messages-tab tag output.
3. Diff. Report any tag that differs in either direction.
4. Claude fixes the rule (30 min per issue typical).

Test plugin set (lock in before starting — see open questions):
- One Oblivion plugin.
- One FO3 **and** one FNV (or one FNV that exercises WeaponMods).
- One Skyrim/SSE plugin.
- One FO4 plugin.
- One plugin per specialty handler: a RACE-heavy Oblivion plugin (for R.AddSpells/ChangeSpells split), a LVL* plugin (for Delev/Relev), an NPC-heavy plugin (for Force heuristics and template-flag gates), a FACT/CONT-heavy plugin (for Relations.Change and Invent.Change keyed diffs).

Loop until diffs go empty on all test plugins.

Estimated: 6–12 h of your time across 3–10 calendar days. 5–15 issue fix cycles on Claude's side.

### Phase 3 — Adopt `SortKey`

**Separate phase. Do not bundle with phase 2.**

Replace the hand-rolled `EditValues` walker with `SortKey(elem, True)` inside the primitives. Re-run phase-2 parity tests. Fix any divergences.

Rationale for isolating: `SortKey` and `EditValues` aren't guaranteed identical in edge cases (flag arrays, unassigned subrecords). If bundled with phase 2, parity drift gets attributed to the wrong cause.

Estimated: 1–2 h Claude, 2 h you.

### Phase 4 — Retire the old code

After phases 2 and 3 both close with zero diffs:

- Rename `WryeBashTagGenerator-NG-v2.pas` → `WryeBashTagGenerator-NG.pas`, overwriting the old.
- Delete `WryeBashTagGenerator-NG-debug.pas`.
- Remove the old detection-layering section from `CLAUDE.md`, put the new one in its place.
- Bump `ScriptVersion` to 2.0.0.0.

Estimated: 30 min Claude, final sanity check on your end.

### Phase 5 — Close the five known coverage gaps

Now that new-tag/new-field addition is cheap, close the gaps listed in the header block. Each is a registry edit; verify each against one plugin that exercises it.

Estimated: 1–2 h Claude, 1–2 h you.

### Cumulative cost estimate

| | Claude compute | Your time | Calendar |
|---|---|---|---|
| Phase 1 | 3–5 h | review | 1 session |
| Phase 2 | ~0.5 h per issue × 5–15 | 6–12 h | 3–10 days |
| Phase 3 | 1–2 h | 2 h | 1–3 days |
| Phase 4 | 30 min | final check | 1 session |
| Phase 5 | 1–2 h | 1–2 h | 1–2 days |
| **Total** | **~8–14 h** | **~10–17 h** | **1–3 weeks async** |

## Open questions — answer before starting

1. **JSON file location.** Sibling to the `.pas` in `Edit Scripts/`? A convention like `Edit Scripts/<scriptname>.json`? Embedded path (loaded relative to the script)? Defensive behaviour when missing?
2. **Test plugin set.** Which specific plugins do you want to use for parity verification? Ideally ones where you already know the current script's output. Minimum four (one per major game family); ideally seven to exercise all specialty handlers.
3. **Which of the five known coverage gaps to fix.** All five in phase 5, or cherry-pick? Each one adds a verification target (one extra plugin-run round) but is otherwise cheap.
4. **Staging preference.** Single PR at the end, or per-phase commits for review?

Secondary, non-blocking:

- Do you want to adopt `SortKey` at all, or leave the hand-rolled `EditValues`? (Phase 3 is skippable if you don't want the behavioural change.)
- Should the companion registry audit script live in `scripts/`, `docs/`, or a new top-level `tools/`? Language (Python vs shell)?
- Should the debug log path (`Edit Scripts/WryeBashTagGenerator-NG-debug.log`) become configurable via a const, or stay hardcoded?

## Risks and mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Claude gets a semantic-drift rule wrong and it's not caught until users run it | high | phase 2 staged parity verification against real plugins; v2 ships alongside old until proven |
| Pascal-in-xEdit quirk Claude isn't aware of breaks the build | medium | phase 1 deliverable includes confirming the script loads and runs (even if rules are wrong) before phase 2 starts |
| JSON schema turns out not expressive enough mid-phase-2, forcing re-shape | low-medium | keep schema permissive; reserve schema freeze until end of phase 2 |
| `SortKey` ≠ `EditValues` behavioural drift on specific tags | medium | phase 3 is explicitly isolated; Actors.Factions / Keywords / R.Relations.Change flagged as likely-divergent sites to check first |
| Independent-If ordering gotcha from current code's Skyrim NPC_ block gets silently lost in the dispatcher | medium | dispatcher walks all candidate rules, per-tag dedup at emit — this specific class of bug should structurally disappear, but verify with an NPC-heavy Skyrim plugin in phase 2 |
| `g_Tag` mutation at the Actors.Factions site (`WryeBashTagGenerator-NG.pas:1091-1093`) encodes a subtle semantic Claude misses | medium | read that site + commit message carefully before rule encoding; test specifically with a Skyrim NPC_ plugin that has both Factions and AI-package overrides |
| Registry and reference doc drift over time | low (if audit script lands) | the phase-1 audit script diffing JSON-vs-Appendix-A is CI-runnable; wire it up before phase 4 closes |

## Related docs

- `CLAUDE.md` — current project overview; the "Detection layering" and "Per-plugin processing" sections are the ones that need rewriting in phase 4.
- `docs/wrye-bash-tags-reference.md` — authoritative per-game tag table; the registry JSON is this doc's machine-readable twin.
- `docs/xedit-scripting-api.md` — local xEdit Pascal API cheat sheet.
- `docs/xEditScripts/` — 168 reference scripts shipped with xEdit. Relevant samples: `_newscript_.pas` (template), `BASH tags autodetection.pas` (minimal upstream ancestor), `JSON - Demo.pas` (JsonDataObjects API), `Skyrim - Add keywords.pas` (TStringList + LoadFromFile idiom).

## Non-goals

Explicitly out of scope for this rewrite:

- Changing the Messages-tab output format (format stays; tag set composition stays byte-identical after phase 2).
- Changing the BashTags file format or header-SNAM format (both remain Wrye-Bash-readable exactly as today).
- Changing the user-facing options dialog (checkboxes stay the same unless `DebugMode` is on, which hides the write checkboxes — same as current `-debug.pas`).
- Replacing `xEdit Pascal` as the scripting environment. This runs in xEdit; it must stay that way.
- Supporting Fallout 76 (still unsupported, same as today).
- Extending support to Morrowind / Starfield (neither has a Wrye Bash patcher set).

## Pick-up checklist

When returning to this document later:

1. Re-read the "Open questions" section. Lock in answers for all four primary questions.
2. Confirm the five known coverage gaps at `WryeBashTagGenerator-NG.pas:29-51` are still open (no-one's fixed them in-place in the meantime).
3. Confirm `docs/wrye-bash-tags-reference.md` is still current and hasn't been re-derived against a newer Wrye Bash release — if it has, the registry source-of-truth changes and phase 1 must consume the new version.
4. Sanity-check that `docs/xEditScripts/JSON - Demo.pas` still uses `TJsonObject` as described. The JSON library is an xEdit dependency, not ours; if xEdit drops or replaces it, the registry encoding plan changes.
5. Ask Claude to begin phase 1.
