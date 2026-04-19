# WryeBashTagGenerator

xEdit Pascal script that generates [Wrye Bash](https://github.com/wrye-bash/wrye-bash) bash tags for a selected plugin by diffing the plugin's records against their masters and emitting the tag names that match Wrye Bash's patcher rules. Maintained fork of fireundubh's original (multifile variant by Xideta).

## Supported games

Fallout 3, Fallout: New Vegas, Fallout 4 (incl. VR), Oblivion, Oblivion Remastered, Skyrim (LE / SE / VR), Enderal, Enderal Special Edition.

Fallout 76 is explicitly **unsupported** (CBash limitation).

## Requirements

- **xEdit 4.1.4 or newer.** The script aborts with an error on older builds. Native StringList set operations and the assumed API surface require this baseline.

## Install

Copy `WryeBashTagGenerator.pas` into your xEdit `Edit Scripts` folder.

## Run

1. Launch xEdit (`SSEEdit.exe`, `FO4Edit.exe`, etc.) and load your plugin set.
2. Right-click the plugin you want to tag → **Apply Script**.
3. Pick `WryeBashTagGenerator` and confirm.
4. Hotkey: **F12** runs the script after the first manual selection.

## Options dialog

Four checkboxes:

| Checkbox | Default | Effect |
|----------|---------|--------|
| Write suggested tags to header | on | Rewrites the plugin description's `{{BASH:...}}` block with the merged final tag set. |
| Write suggested tags to file | off | Also writes canonical tag names to `Data\BashTags\<plugin>.txt`. |
| Log test results to Messages tab | on | Per-detection technical log lines (`{Tag} (TestName) [SIG:FormID] path`). |
| Show Tag to Record Relationships | off | Plain-language `[INFO] Tag suggestion <tag> based on <reason> at [SIG:FormID] <path>` lines after the results summary. One line per detection. |
| Suggest heuristic Force* tags | off | See "Heuristic Force* tags" below. |

## Output

- `{{BASH:...}}` block in the plugin description is normalized via Wrye Bash's `_tag_aliases` map and written back to `SNAM` if the header option is on.
- If the existing description already contains deprecated tag names (e.g. `Factions`, `NpcFaces`, `Voice-F`), the script prompts before rewriting; declining keeps the original description untouched.
- `BashTags\<plugin>.txt` (when enabled) always contains canonical tag names only.

## Tag canonicalization

Tag names follow current Wrye Bash conventions. Aliases the script normalizes include (non-exhaustive):

- `Actors.Perks.{Add,Change,Remove}` → `NPC.Perks.{Add,Change,Remove}`
- `Factions` → `Actors.Factions`
- `Voice-F` / `Voice-M` → `R.Voice-F` / `R.Voice-M`
- `Body-F` / `Body-M` → `R.Body-F` / `R.Body-M`
- `Eyes` / `Eyes-D` / `Eyes-E` / `Eyes-R` → `R.Eyes`
- `Hair` → `R.Hair`
- `Invent` → `Invent.Add` + `Invent.Remove`
- `NpcFaces` → `NPC.Eyes` + `NPC.Hair` + `NPC.FaceGen`
- `Relations` / `R.Relations` → split into `.Add` / `.Change` / `.Remove` variants
- `Derel` → `Relations.Remove`; `C.GridFlags` → `C.ForceHideLand`
- `Merge`, `ScriptContents` → dropped (removed by Wrye Bash)

See `ExpandOneAliasTo` in the script for the full table; mirrors `Mopy/bash/bosh/__init__.py` `_tag_aliases` + `_removed_tags` in Wrye Bash.

## Heuristic Force* tags (opt-in)

When the **Suggest heuristic Force* tags** checkbox is on, the script also emits these Wrye Bash variants under simple diff rules:

| Tag | Detection rule | Known false-positive case |
|-----|----------------|---------------------------|
| `Actors.SpellsForceAdd` | `Actors.Spells` already suggested AND override's `Spells` (or FO4 `Actor Effects`) is a strict superset of master's (no removals, ≥ 1 add) | Mod author intentionally pruned default spells but re-added them in a different order — looks like a superset to the script. |
| `Actors.AIPackagesForceAdd` | `Actors.AIPackages` already suggested AND override's `Packages` is a strict superset of master's | Same shape: list reorder + add reads as superset. |
| `NpcFacesForceFullImport` | NPC differs from master in eyes (`ENAM`), hair (`HNAM`), AND face geometry (`FaceGen Data`) simultaneously | Pure cosmetic NPC overhauls that swap all three but don't actually need full face import. |

Detections route through the same logging plumbing as the standard tags, so they appear in `Show Tag to Record Relationships` output with explicit "heuristic" reasons. Review heuristic suggestions before committing them to the header.

## Oblivion RACE Spells split

For Oblivion-family `RACE` records, the script splits the v1.0 single-tag emission of `R.ChangeSpells` into two mutually exclusive tags based on a list-diff of the `Spells` arrays:

| Master vs Override | Tag emitted |
|--------------------|-------------|
| Override removes any SPEL the master had | `R.ChangeSpells` (full override required to drop SPELs) |
| Override adds SPELs and removes none | `R.AddSpells` (additive merge sufficient; preserves other mods' adds) |
| Identical sets | nothing |

This preserves v1.0 detection coverage and improves accuracy in the adds-only case (Wrye Bash `R.AddSpells` is the correct mode for additive merging across mods).

## Credits

- **fireundubh** — original `WryeBashTagGenerator` script.
- **Xideta** — multifile variant.
- Current maintainer: see `ScriptAuthor` constant in the script.

## License

Inherited from the upstream script. Treat as permissive unless/until clarified.
