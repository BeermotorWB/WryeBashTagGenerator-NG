# WryeBashTagGenerator-NG

xEdit Pascal script that generates [Wrye Bash](https://github.com/wrye-bash/wrye-bash) bash tags for a selected plugin by diffing the plugin's records against their masters and emitting the tag names that match Wrye Bash's patcher rules. Fork of fireundubh's `WryeBashTagGenerator` (multifile variant by Xideta).

> **No support.** This script is provided as an example. There is no warranty, no support, no bug-tracker SLA, no upgrade promises. Use at your own risk; review suggested tags before writing them to your plugin's header. The upstream authors of `WryeBashTagGenerator` (fireundubh, Xideta) did not write this fork and should not be contacted about it; see Credits below for proper citation.

## Supported games

Fallout 3, Fallout: New Vegas, Fallout 4 (incl. VR), Oblivion, Oblivion Remastered, Skyrim (LE / SE / VR), Enderal, Enderal Special Edition.

Fallout 76 is explicitly **unsupported** (CBash limitation).

## Requirements

- **xEdit 4.1.4 or newer.** The script aborts with an error on older builds. Native StringList set operations and the assumed API surface require this baseline.

## Install

Copy `WryeBashTagGenerator-NG.pas` into your xEdit `Edit Scripts` folder.

## Run

1. Launch xEdit (`SSEEdit.exe`, `FO4Edit.exe`, etc.) and load your plugin set.
2. Right-click the plugin you want to tag → **Apply Script**.
3. Pick `WryeBashTagGenerator-NG` and confirm.
4. Hotkey: **F12** runs the script after the first manual selection.

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

## Oblivion RACE Spells split

For Oblivion-family `RACE` records, the script splits the v1.0 single-tag emission of `R.ChangeSpells` into two mutually exclusive tags based on a list-diff of the `Spells` arrays:

| Master vs Override | Tag emitted |
|--------------------|-------------|
| Override removes any SPEL the master had | `R.ChangeSpells` (full override required to drop SPELs) |
| Override adds SPELs and removes none | `R.AddSpells` (additive merge sufficient; preserves other mods' adds) |
| Identical sets | nothing |

This preserves v1.0 detection coverage and improves accuracy in the adds-only case (Wrye Bash `R.AddSpells` is the correct mode for additive merging across mods).

## Credits

Original authors (please cite when referencing this script's lineage):

- **fireundubh** — author of `WryeBashTagGenerator`, the upstream xEdit Pascal script this fork is derived from.
- **Xideta** — author of the multifile variant of `WryeBashTagGenerator` that served as the immediate base for this fork.

`-NG` fork:

- **Beermotor** — maintainer of `WryeBashTagGenerator-NG`. Provided as-is with no support.

> Beermotor, _WryeBashTagGenerator-NG_ (xEdit Pascal script), forked from fireundubh's _WryeBashTagGenerator_ (multifile variant by Xideta).

## License

Inherited from the upstream script. Treat as permissive unless/until clarified.
