# WryeBashTagGenerator-NG

xEdit Pascal script that generates [Wrye Bash](https://github.com/wrye-bash/wrye-bash) bash tags for a selected plugin by diffing the plugin's records against their masters and emitting the tag names that match Wrye Bash's patcher rules. Fork of fireundubh's `WryeBashTagGenerator` (multifile variant by Xideta).

> **No support.** This script is provided as an example. There is no warranty, no support, no bug-tracker SLA, no upgrade promises. Use at your own risk; review suggested tags before writing them to your plugin's header. The upstream authors of `WryeBashTagGenerator` (fireundubh, Xideta) did not write this fork and should not be contacted about it; see Credits below for proper citation.

## Supported games

Fallout 3, Fallout: New Vegas, Fallout 4 (incl. VR), Oblivion, Oblivion Remastered, Skyrim (LE / SE / VR), Enderal, Enderal Special Edition.

Fallout 76 is explicitly **unsupported**.

## Requirements

- **xEdit 4.1.4 or newer.** The script aborts with an error on older builds. Native StringList set operations and the assumed API surface require this baseline.

## Install

Copy `WryeBashTagGenerator-NG.pas` (and optionally `WryeBashTagGenerator-Multi-NG.pas`) into your xEdit `Edit Scripts` folder.

## Run

1. Launch xEdit (`SSEEdit.exe`, `FO4Edit.exe`, etc.) and load your plugin set.
2. Right-click the plugin you want to tag → **Apply Script**.
3. Pick `WryeBashTagGenerator-NG` and confirm.
4. Hotkey: **F12** runs the script after the first manual selection.

The main script operates on **one plugin per invocation**. If you launch it against a selection that spans multiple plugins, the run is aborted in `Finalize` with an explicit error listing every targeted file; re-run with only one plugin selected.

## Multifile convenience script (`WryeBashTagGenerator-Multi-NG.pas`)

Use this when you want to run the same tag scan across **many plugins in one go** (select multiple plugins in xEdit, then apply the script). It is **not** a full load-order reconciliation tool: each plugin is processed independently, and comparisons are anchored to **stock / base-game masters only** (other loaded mods are not treated as “context” for correctness).

Compared to the main script:

| Behavior | Main (`WryeBashTagGenerator-NG.pas`) | Multi (`WryeBashTagGenerator-Multi-NG.pas`) |
|----------|--------------------------------------|---------------------------------------------|
| Selection | **Exactly one** plugin per run | **One or many** plugins per run |
| Header vs BashTags file mismatch (when file writes are enabled) | **Stricter guardrail**: user is prompted (**Abort** stops the run; **Ignore** skips writes for that plugin only) so you do not silently pick a “winner” between two disagreeing tag sources | **Batch convenience**: mismatch **auto-skips** writes for that plugin and **continues** with the next (no silent overwrite of conflicting sources) |
| Default log verbosity | Same defaults as main | **Test logging** and **Tag↔Record relationship** output default **off** to keep batch runs readable (use `-debug` for deep traces) |

`ProcessTag` and helpers are shared in spirit, but `ProcessRecord` is duplicated. It should match the main script **except** the Multi-only walk to a **stock** master for `o` (see the comment above `ProcessRecord` in the Multi source). To verify parity, diff the two `ProcessRecord` functions directly, accounting for that stock-master walk.

## Options dialog

Four checkboxes:

| Checkbox | Default | Effect |
|----------|---------|--------|
| Write suggested tags to header | off | Rewrites the plugin description's `{{BASH:...}}` block with the merged final tag set. |
| Write suggested tags to file | off | Also writes canonical tag names to `Data\BashTags\<plugin>.txt`. |
| Log test results to Messages tab | on | Per-detection technical log lines (`{Tag} (TestName) [SIG:FormID] path`). |
| Show Tag to Record Relationships | on | Plain-language `[INFO] Tag suggestion <tag> based on <reason> at [SIG:FormID] <path>` lines after the results summary. One line per detection. |
| Suggest heuristic Force* tags | off | See "Heuristic Force* tags" below. |

## Output

- `{{BASH:...}}` block in the plugin description is normalized via Wrye Bash's `_tag_aliases` map and written back to `SNAM` if the header option is on.
- If the existing description already contains deprecated tag names (e.g. `Factions`, `NpcFaces`, `Voice-F`), the script prompts before rewriting; declining keeps the original description untouched.
- `BashTags\<plugin>.txt` (when enabled) always contains canonical tag names only.

## BashTags file handling (`Data\BashTags\<plugin>.txt`)

If a `Data\BashTags\<plugin>.txt` exists, the script reads it (Wrye-Bash format: `#` comments, comma-separated tags, `-Tag` for explicit removals) and reports its contents alongside the header:

- `existing tags found in header:` — tags inside the `{{BASH:...}}` block of the plugin description.
- `existing tags found in BashTags file:` — additive tags from the BashTags file.
- `tags explicitly removed (-) in BashTags file:` — entries the user prefixed with `-`, shown only when present.

This script does **not** reconcile the two sources — that's Wrye Bash's job. When **Write suggested tags to file** is on, before overwriting an existing `BashTags\<plugin>.txt`:

1. If the header `{{BASH:...}}` block and the BashTags file disagree:
   - **Main script**: you are prompted (**Abort** stops the run; **Ignore** skips writes for that plugin only).
   - **Multi script**: writes for that plugin are skipped and processing **continues** with the next selected plugin (no prompt).
2. Otherwise, you get a "back up + overwrite" confirmation (Yes/No). Choosing **No** discards the file write; the existing BashTags file is left untouched. The header rewrite is independently gated by **Write suggested tags to header** and is unaffected by your choice here.

Approved writes use the Wrye Bash file format and embed the previous file contents in-place as commented lines, e.g.:

```
# Generated by WryeBashTagGenerator-NG v1.9.7
# --- Backup of previous file contents (2026-04-25 14:23:01) ---
# OldTagA, OldTagB, -OldTagC
# --- End backup ---
NewTagA, NewTagB, NewTagC
```

If the BashTags file's additive tag set already matches what the script would write, no prompt fires and the file is left untouched.

## Tag canonicalization

Tag names follow current Wrye Bash conventions. The script normalizes every deprecated alias below to its modern replacement(s) before writing the `{{BASH:...}}` block. This mirrors `Mopy/bash/bosh/__init__.py` `_tag_aliases` + `_removed_tags` in Wrye Bash; see `ExpandOneAliasTo` in the script for the authoritative table.

| Deprecated tag (old) | Replacement tag(s) (new) |
|----------------------|--------------------------|
| `Actors.Perks.Add`     | `NPC.Perks.Add` |
| `Actors.Perks.Change`  | `NPC.Perks.Change` |
| `Actors.Perks.Remove`  | `NPC.Perks.Remove` |
| `Body-F`               | `R.Body-F` |
| `Body-M`               | `R.Body-M` |
| `Body-Size-F`          | `R.Body-Size-F` |
| `Body-Size-M`          | `R.Body-Size-M` |
| `C.GridFlags`          | `C.ForceHideLand` |
| `Derel`                | `Relations.Remove` |
| `Eyes`                 | `R.Eyes` |
| `Eyes-D`               | `R.Eyes` |
| `Eyes-E`               | `R.Eyes` |
| `Eyes-R`               | `R.Eyes` |
| `Factions`             | `Actors.Factions` |
| `Hair`                 | `R.Hair` |
| `Invent`               | `Invent.Add`, `Invent.Remove` |
| `InventOnly`           | `IIM`, `Invent.Add`, `Invent.Remove` |
| `Merge`                | _(removed by Wrye Bash; dropped)_ |
| `Npc.EyesOnly`         | `NPC.Eyes` |
| `Npc.HairOnly`         | `NPC.Hair` |
| `NpcFaces`             | `NPC.Eyes`, `NPC.Hair`, `NPC.FaceGen` |
| `R.Relations`          | `R.Relations.Add`, `R.Relations.Change`, `R.Relations.Remove` |
| `Relations`            | `Relations.Add`, `Relations.Change` |
| `ScriptContents`       | _(removed by Wrye Bash; dropped)_ |
| `Voice-F`              | `R.Voice-F` |
| `Voice-M`              | `R.Voice-M` |

## Heuristic Force* tags (opt-in)

When the **Suggest heuristic Force* tags** checkbox is on, the script also emits these Wrye Bash variants under simple diff rules:

| Tag | Detection rule | Known false-positive case |
|-----|----------------|---------------------------|
| `Actors.SpellsForceAdd` | `Actors.Spells` already suggested AND override's `Spells` (or FO4 `Actor Effects`) is a strict superset of master's (no removals, ≥ 1 add) | Mod author intentionally pruned default spells but re-added them in a different order — looks like a superset to the script. |
| `Actors.AIPackagesForceAdd` | `Actors.AIPackages` already suggested AND override's `Packages` is a strict superset of master's | Same shape: list reorder + add reads as superset. |
| `NpcFacesForceFullImport` | NPC differs from master in eyes (`ENAM`), hair (`HNAM`), AND face geometry (`FaceGen Data`) simultaneously | Pure cosmetic NPC overhauls that swap all three but don't actually need full face import. |

Detections route through the same logging plumbing as the standard tags, so they appear in `Show Tag to Record Relationships` output with explicit "heuristic" reasons. Review heuristic suggestions before committing them to the header.

## RACE Spells split (Oblivion + Skyrim/SSE/Enderal)

For `RACE` records, the script splits a single `R.ChangeSpells` emission into two mutually exclusive tags based on a list-diff of the SPLO array (`Spells` on TES4, `Actor Effects` on TES5/SSE/Enderal):

| Master vs Override | Tag emitted |
|--------------------|-------------|
| Override removes any SPEL the master had | `R.ChangeSpells` (full override required to drop SPELs) |
| Override adds SPELs and removes none | `R.AddSpells` (additive merge sufficient; preserves other mods' adds) |
| Identical sets | nothing |

`R.AddSpells` is the correct mode for additive merging across mods.

## v1.9.1.0 — bug fixes

- `Actors.Spells` / `Actors.SpellsForceAdd`: handler walked `Spells` on Skyrim/SSE/FO3/FNV where the SPLO array is actually named `Actor Effects`. Path is now per-game (Oblivion = `Spells`, everything else = `Actor Effects`).
- `Actors.Spells` had no call site for FO3/FNV — added (`CREA` + `NPC_`, gated by FNV/FO3 `Use Actor Effect List` template flag).
- `Outfits.Add` / `Outfits.Remove`: handler walked the OTFT record signature instead of its `Items` (INAM) child array, so it never fired on any game. Fixed for Skyrim, SSE, FO4.
- `NPC.Race` and `NPC.Class` were never emitted for Oblivion NPCs (only Eyes / FaceGen / Hair were). Added; no template-flag gating since Oblivion has no template system.
- `R.AddSpells` / `R.ChangeSpells`: previously only emitted for Oblivion RACE records. Now also emitted for Skyrim/SSE/Enderal via the same `ProcessRaceSpells` Add/Change split, with the SPLO array path made game-aware.

## 1.9.2.0 - multifile
- Added back multifile support, plus safeguards for independant plugin tagging.

## 1.9.2.1 - bug fixes and deduplication
- wbIsOblivion also tested for Oblivion Remastered, making explicitly testing for it redundant.
- wbIsOblivionR tests were previously added in a way where operator precedence could mean incorrect predicates.
- Moved making standardized sets to its own function.
- Moved repeated `ACBS\\Template Flags` tests to function.
- Removed unused variables.
- Further deduplication and misc edge case fixes.

## v1.9.7 — ProcessRecord pass + aligned `ScriptVersion`

**Versions:** **`WryeBashTagGenerator-NG.pas`** and **`WryeBashTagGenerator-Multi-NG.pas`** → **`1.9.7`**; **`WryeBashTagGenerator-NG-debug.pas`** → **`1.9.7-debug`** (same `ProcessRecord` and **`TryTagGatedByFlag`** as main; extra debug logging only in the debug script).

- **`C.Regions` on `CELL`**: Emitted for Fallout 3, New Vegas, and Oblivion (Wrye Bash `cellRecAttrs`); Skyrim/SSE still uses the Skyrim-only `CELL` block (unchanged) so `C.Regions` is not double-processed.
- **Delev / Relev** (`ProcessDelevRelevTags`): `ContainsStr` for leveled list signatures now matches **`bush.game.leveled_list_types` per game** — Oblivion: `LVLC` `LVLI` `LVSP`; Fallout 3 / NV: `LVLC` `LVLI` `LVLN`; Skyrim/SSE: `LVLI` `LVLN` `LVSP` (no longer treats every game as all four).
- **Skyrim / SSE `Destructible`**: `ProcessRecord` now suggests **`Destructible`** for the same record types as Wrye Bash Skyrim `destructible_types` (this tag was only wired for Fallout 3 / NV and Fallout 4 before).
- **Fallout 4 `COBJ` + `Invent.*`**: Comment notes Wrye Bash `inventory_types` (CONT, FURN, NPC_) vs recipe/constructible handling.
- **Debug script:** `ProcessRecord` brought in line with main/Multi for this release; **`TryTagGatedByFlag`** helper and all matching template-flag gates use the same structure as **`WryeBashTagGenerator-NG.pas`**.

## v1.9.5 — Fallout 4 spot-check (Wrye Bash–aligned branches)

Applies to **`WryeBashTagGenerator-NG.pas`** and **`WryeBashTagGenerator-Multi-NG.pas`**.

- **`NPC_` (`Actors.ACBS`)**: FO4 field order matches xEdit `ACBS\Configuration` (`XP Value Offset` before `Level`); diffs **`Template Flags`** (not only scalar stats + `Flags`).
- **`Actors.AIData` (FO4)**: Replaces `CompareNativeValues` on the whole `Aggro` struct with a full subtree **`Evaluate`** on `AIDT\Aggro` (radius behavior, warn, warn/attack, attack) so child-field changes are not missed; still evaluates **`No Slow Approach`** after.
- **`Graphics` / `ARMO` (FO4)**: FO4-first branch uses xEdit paths under **`Male` / `Female`** (`World Model`, `Icon Image`) and **`BOD2\First Person Flags`** only (FO4 `BOD2` has no Skyrim-style general flags). Avoids running TES5 **`Male world model`** paths on FO4 records.
- **`Graphics` / `MGEF` (FO4)**: Shader / art checks (`Casting Light`, `Hit Shader`, `Enchant Shader` under `Magic Effect Data\DATA\…`) now run for FO4 as well as Skyrim.
- **Debug** (`WryeBashTagGenerator-NG-debug.pas`): same **FO4** `ProcessTag` updates as above; FO4 **ObjectBounds** matches main (includes **`BNDS`**).
- **Multi** (`WryeBashTagGenerator-Multi-NG.pas`): `ProcessRecord` re-synced with main (one drift: missing RACE block comments); in-source comment notes the intended parity (aside from the stock-master `o` walk).

## v1.9.4 — Skyrim/SSE importer parity (Wrye Bash)

Applies to **`WryeBashTagGenerator-NG.pas`** and **`WryeBashTagGenerator-Multi-NG.pas`** (same behavior).

- **`NPC_` (`Actors.ACBS`)**: Skyrim branch uses TES5Edit `ACBS\Configuration` fields (offsets, `Level` union, calc levels, speed, disposition unused field, health/bleedout, template flags) instead of Oblivion/FO3-shaped paths that do not exist on Skyrim.
- **`NPC_` / `CREA` (`Actors.AIData`)**: Skyrim branch matches TES5Edit `AIDT` layout (`Morality`, nested `Aggro\…` including `Warn/Attack`) instead of Oblivion-only fields (`Teaches`, `Buys/Sells and Services`, etc.).
- **`NPC_` (`Actors.Stats`)**: Skyrim uses a full `DNAM` compare (same coverage shape as Wrye Bash’s combined skill/attribute import on `DNAM`), still gated by `Use Stats` like before.
- **`RACE` (Skyrim)**: Dispatches `R.Body-*`, `R.Eyes`, `R.Hair`, `R.Relations.*` (Wrye Bash imports these on Skyrim; ears/head/mouth/teeth stay FO3/FNV/Oblivion-only). Adds **`R.Stats`** on `DATA` (starting health/magicka/stamina, carry weight, regens, unarmed damage/reach) per Wrye Bash `import_races_attrs`.
- **`Names` (+ bundled `Graphics` / `Stats` dispatch)**: Skyrim signature list expanded to match Wrye Bash Skyrim **`names_types`** (e.g. `AVIF`, `CLFM`, `CONT`, `LCTN`, `NPC_`, `QUST`, `SPEL`, …).
- **Script header**: removed stale “known gap” bullets for the items above; **only** the **`C.MiscFlags`** / xEdit vs docs wording note remains (NG still uses xEdit’s `Can Travel From Here` label for bit 2, which is the same field Wrye Bash calls `cantFastTravel`).

## v1.9.3 — merged NG + Multifile line

- **Merge point**: this release rolls the ongoing **1.9.1.x** quality fixes together with the **1.9.2.x** Multifile work into one coherent `dev` line.
- **Two deliverables**:
  - `WryeBashTagGenerator-NG.pas` — **single-plugin**, stricter user prompts so you do not silently pick a “winner” when the plugin header and `BashTags` file disagree.
  - `WryeBashTagGenerator-Multi-NG.pas` — **batch** convenience: run across many selected plugins; mismatches between header and `BashTags` file **auto-skip** writes for that plugin and **continue** (see Multifile section above).
- **Roadmap**: **v1.9.3** is the last **1.9** cut before promoting `dev` to the next **main**; the next `main` release is planned as **v2.0** (bump all script versions accordingly when that happens).

## Credits

Original authors (please cite when referencing this script's lineage):

- **fireundubh** — author of `WryeBashTagGenerator`, the upstream xEdit Pascal script this fork is derived from.
- **Xideta** — author of the multifile variant of `WryeBashTagGenerator` that served as the immediate base for this fork.

`-NG` fork:

- **Beermotor** — maintainer of `WryeBashTagGenerator-NG`. Provided as-is with no support.
- **Xideta** — multifile, plus misc bugfixes, and improvements.

> Beermotor, _WryeBashTagGenerator-NG_ (xEdit Pascal script), forked from fireundubh's _WryeBashTagGenerator_ (multifile variant by Xideta).

## License

Inherited from the upstream script. Treat as permissive unless/until clarified.
